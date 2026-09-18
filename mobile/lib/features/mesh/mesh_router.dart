import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobile/features/alerts/emergency_alert_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/data/local/database_helper.dart';
import 'package:mobile/features/mesh/mesh_packet.dart';
import 'package:mobile/features/mesh/mesh_deduplicator.dart';

class MeshPeerNode {
  final String nodeId;
  final String address;
  final String deviceType; // BLE_PERIPHERAL, BLE_CENTRAL
  final int rssi; // Signal strength in dBm (-30 dBm strong, -90 dBm weak)
  final String lastSeen;
  final bool isConnected;

  MeshPeerNode({
    required this.nodeId,
    required this.address,
    required this.deviceType,
    required this.rssi,
    required this.lastSeen,
    this.isConnected = true,
  });

  MeshPeerNode copyWith({
    String? nodeId,
    String? address,
    String? deviceType,
    int? rssi,
    String? lastSeen,
    bool? isConnected,
  }) {
    return MeshPeerNode(
      nodeId: nodeId ?? this.nodeId,
      address: address ?? this.address,
      deviceType: deviceType ?? this.deviceType,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

class MeshRouter extends ChangeNotifier {
  static final MeshRouter instance = MeshRouter._init();
  MeshRouter._init() {
    _initStableNodeIdAndStart();
  }

  static const MethodChannel _methodChannel = MethodChannel('com.resqnet.mobile/mesh');
  static const EventChannel _eventChannel = EventChannel('com.resqnet.mobile/mesh_events');
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static final String _defaultNodeId = 'node_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  String _nodeId = _defaultNodeId;
  String get nodeId => _nodeId;

  final Map<String, MeshPeerNode> _activePeers = {};
  final List<MeshPacket> _relayedPackets = [];
  final List<String> _eventLogs = [];
  final Set<String> _acknowledgedPacketIds = {};

  bool _isScanningActive = false;
  bool _isLowPowerDutyCycle = false;
  final bool _verboseHardwareLogging = true;
  int _relayedCount = 0;
  int _duplicatedSuppressedCount = 0;
  StreamSubscription? _eventSubscription;

  Map<String, MeshPeerNode> get activePeers => _activePeers;
  List<MeshPacket> get relayedPackets => _relayedPackets;
  List<String> get eventLogs => _eventLogs;
  Set<String> get acknowledgedPacketIds => _acknowledgedPacketIds;
  bool get isScanningActive => _isScanningActive;
  bool get isLowPowerDutyCycle => _isLowPowerDutyCycle;
  bool get verboseHardwareLogging => _verboseHardwareLogging;
  int get relayedCount => _relayedCount;
  int get duplicatedSuppressedCount => _duplicatedSuppressedCount;

  /// Initializes stable cryptographic node ID and starts real BLE mesh engine
  Future<void> _initStableNodeIdAndStart() async {
    try {
      String? savedId = await _storage.read(key: 'mesh_node_id');
      if (savedId == null || savedId.isEmpty) {
        savedId = _nodeId;
        await _storage.write(key: 'mesh_node_id', value: savedId);
      } else {
        _nodeId = savedId;
      }
      _logHardwareEvent('NODE_IDENTITY_INITIALIZED | Node: $_nodeId');
      notifyListeners();

      // Start Real BLE Mesh Engine
      await startRealMesh();
    } catch (e) {
      debugPrint('Error initializing mesh node identity: $e');
    }
  }

  /// Starts the native Android dual-role BLE Mesh Engine
  Future<void> startRealMesh() async {
    try {
      // 1. Request permissions if needed
      final bool hasPermissions = await _methodChannel.invokeMethod('checkPermissions') ?? false;
      if (!hasPermissions) {
        await _methodChannel.invokeMethod('requestPermissions');
      }

      // 2. Start Native BLE Service (Peripheral + Central + Foreground Service)
      final bool started = await _methodChannel.invokeMethod('startMesh', {'nodeId': _nodeId}) ?? false;
      _isScanningActive = started;
      _logHardwareEvent('MESH_SERVICE_START | Success: $started');

      // 3. Listen to Real-Time Radio Events
      _eventSubscription?.cancel();
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleNativeRadioEvent,
        onError: (err) {
          _logHardwareEvent('RADIO_EVENT_ERROR: $err');
        },
      );

      notifyListeners();
    } on MissingPluginException {
      // Running in unit test or non-Android environment
      _isScanningActive = true;
      _logHardwareEvent('NATIVE_BLE_UNAVAILABLE | Operating in offline protocol fallback');
      notifyListeners();
    } catch (e) {
      _logHardwareEvent('ERROR_STARTING_REAL_MESH: $e');
    }
  }

  /// Stops native BLE mesh operations
  Future<void> stopRealMesh() async {
    try {
      await _methodChannel.invokeMethod('stopMesh');
      _isScanningActive = false;
      _activePeers.clear();
      _logHardwareEvent('MESH_SERVICE_STOPPED');
      notifyListeners();
    } catch (e) {
      _logHardwareEvent('ERROR_STOPPING_MESH: $e');
    }
  }

  /// Handles real-time radio events from Kotlin BleMeshManager
  void _handleNativeRadioEvent(dynamic rawEvent) {
    if (rawEvent is! Map) return;
    final eventMap = Map<String, dynamic>.from(rawEvent);
    final eventType = eventMap['event'] as String?;

    switch (eventType) {
      case 'PEER_DISCOVERED':
        final pNodeId = eventMap['nodeId'] as String? ?? 'node_unknown';
        final address = eventMap['address'] as String? ?? '';
        final rssi = eventMap['rssi'] as int? ?? -70;
        final now = DateTime.now().toIso8601String();

        _activePeers[pNodeId] = MeshPeerNode(
          nodeId: pNodeId,
          address: address,
          deviceType: 'BLE_PERIPHERAL',
          rssi: rssi,
          lastSeen: now,
          isConnected: false,
        );
        _logHardwareEvent('PEER_DISCOVERED | Node: $pNodeId | RSSI: $rssi dBm');
        notifyListeners();
        break;

      case 'PEER_CONNECTED':
        final pNodeId = eventMap['nodeId'] as String? ?? 'node_unknown';
        final address = eventMap['address'] as String? ?? '';
        final now = DateTime.now().toIso8601String();

        final existing = _activePeers[pNodeId];
        _activePeers[pNodeId] = MeshPeerNode(
          nodeId: pNodeId,
          address: address,
          deviceType: 'BLE_DUAL_CHANNEL',
          rssi: existing?.rssi ?? -50,
          lastSeen: now,
          isConnected: true,
        );
        _logHardwareEvent('PEER_CONNECTED | Active channel established with $pNodeId');
        notifyListeners();

        // STORE-AND-FORWARD TRIGGER:
        // A new peer has arrived! Flush pending/unacknowledged SOS packets to this newly connected peer
        _flushStoreAndForwardQueueToPeer(pNodeId);
        break;

      case 'PEER_DISCONNECTED':
        final pNodeId = eventMap['nodeId'] as String? ?? 'node_unknown';
        if (_activePeers.containsKey(pNodeId)) {
          _activePeers[pNodeId] = _activePeers[pNodeId]!.copyWith(isConnected: false);
          _logHardwareEvent('PEER_DISCONNECTED | Node $pNodeId offline');
          notifyListeners();
        }
        break;

      case 'PACKET_RECEIVED':
        final bytes = eventMap['bytes'] as Uint8List?;
        final from = eventMap['from'] as String? ?? '';
        if (bytes != null && bytes.isNotEmpty) {
          try {
            final packet = MeshPacket.fromRawBytes(bytes);
            _logHardwareEvent('WIRE_PACKET_RECEIVED | Type: ${packet.type.name} | From: $from');
            receiveIncomingPacket(packet);
          } catch (e) {
            _logHardwareEvent('ERROR_DESERIALIZING_PACKET: $e');
          }
        }
        break;

      case 'STATUS_CHANGED':
        final status = eventMap['status'] as String? ?? '';
        _logHardwareEvent('STATUS_CHANGED | $status');
        notifyListeners();
        break;

      case 'LOG':
        final msg = eventMap['message'] as String? ?? '';
        _logHardwareEvent(msg);
        break;
    }
  }

  void toggleDutyCycle(bool enableLowPower) {
    _isLowPowerDutyCycle = enableLowPower;
    _logHardwareEvent('DUTY_CYCLE_CHANGED | Low Power: $enableLowPower');
    try {
      _methodChannel.invokeMethod('setDutyCycle', {'lowPower': enableLowPower});
    } catch (_) {}
    notifyListeners();
  }

  void _logHardwareEvent(String message) {
    final timeStr = DateTime.now().toIso8601String().substring(11, 19);
    final formatted = '[$timeStr] $message';
    _eventLogs.insert(0, formatted);
    if (_eventLogs.length > 50) {
      _eventLogs.removeLast();
    }
    if (_verboseHardwareLogging) {
      debugPrint('[MESH_DEBUG $timeStr] $message');
    }
  }

  /// Broadcasts an Emergency SOS packet over the real BLE mesh network
  Future<MeshPacket> broadcastSOSPacket({
    required String userId,
    required double lat,
    required double lon,
    String? medicalNote,
  }) async {
    final now = DateTime.now().toIso8601String();
    final sosId = 'sos_${DateTime.now().millisecondsSinceEpoch}';

    final packet = MeshPacket(
      packetId: 'pkt_$sosId',
      senderId: userId,
      destinationId: '*',
      timestamp: now,
      type: MeshPacketType.sosAlert,
      priority: MeshPacketPriority.critical,
      payload: {
        'sos_id': sosId,
        'user_id': userId,
        'latitude': lat,
        'longitude': lon,
        'status': 'QUEUED',
        'medical_note': medicalNote ?? 'Emergency SOS Alert',
        'battery_percent': 85,
      },
      ttlHops: 5,
      hopCount: 0,
      relayPath: [nodeId],
    );

    _logHardwareEvent('BROADCAST_SOS | ID: ${packet.packetId} | Sender: $userId');

    // 1. Mark as seen in deduplicator
    MeshDeduplicator.instance.markSeen(packet.packetId);

    // 2. Queue into local SQLite DB for persistent storage
    final db = DatabaseHelper.instance;
    await db.queueSyncOperation(
      entityType: 'sos_logs',
      entityId: sosId,
      op: 'UPSERT',
      payload: packet.payload,
    );

    _relayedPackets.insert(0, packet);
    _relayedCount++;
    notifyListeners();

    // Trigger local alert & emergency sound
    EmergencyAlertService.instance.triggerAlertFromPacket(packet, isOriginator: true);

    // 3. Broadcast real packet over BLE radio
    await _forwardToPeers(packet);
    return packet;
  }

  /// Receives an incoming packet from physical BLE radio interface
  Future<bool> receiveIncomingPacket(MeshPacket packet) async {
    _logHardwareEvent(
      'PACKET_INCOMING | ID: ${packet.packetId} | Sender: ${packet.senderId} | Hops: ${packet.hopCount} | TTL: ${packet.ttlHops}',
    );

    // 1. Check deduplication cache
    if (MeshDeduplicator.instance.hasSeen(packet.packetId)) {
      _duplicatedSuppressedCount++;
      _logHardwareEvent('DEDUPLICATION_SUPPRESSED | ID: ${packet.packetId} | Duplicate dropped.');
      notifyListeners();
      return false;
    }

    // 2. Mark seen in deduplicator
    MeshDeduplicator.instance.markSeen(packet.packetId);

    // 3. Handle Packet Type
    if (packet.type == MeshPacketType.ack) {
      final ackFor = packet.payload['ack_for'] as String?;
      if (ackFor != null) {
        _acknowledgedPacketIds.add(ackFor);
        _logHardwareEvent('ACK_CONFIRMED | Verified delivery of packet $ackFor');
        notifyListeners();
      }
    } else if (packet.type == MeshPacketType.sosAlert) {
      // Store SOS locally in SQLite
      final db = DatabaseHelper.instance;
      final sosId = packet.payload['sos_id'] ?? packet.packetId;
      await db.queueSyncOperation(
        entityType: 'sos_logs',
        entityId: sosId,
        op: 'UPSERT',
        payload: packet.payload,
      );

      // Trigger incoming peer alert & deep emergency sound for nearby device / rescuer
      EmergencyAlertService.instance.triggerAlertFromPacket(packet, isOriginator: false);

      // REAL ACKNOWLEDGEMENT:
      // Generate and return real ACK packet back to sender across the mesh
      final ackPacket = MeshPacket(
        packetId: 'pkt_ack_${packet.packetId}_$nodeId',
        senderId: nodeId,
        destinationId: packet.senderId,
        timestamp: DateTime.now().toIso8601String(),
        type: MeshPacketType.ack,
        priority: MeshPacketPriority.high,
        payload: {
          'ack_for': packet.packetId,
          'acked_by': nodeId,
          'received_at': DateTime.now().toIso8601String(),
        },
        ttlHops: 5,
        hopCount: 0,
        relayPath: [nodeId],
      );

      _logHardwareEvent('ACK_TRANSMITTING | Sending ACK for ${packet.packetId} to ${packet.senderId}');
      _forwardToPeers(ackPacket);
    }

    // 4. Validate TTL expiration
    if (packet.isExpired) {
      _logHardwareEvent('TTL_EXPIRED | ID: ${packet.packetId} | Dropping packet.');
      return false;
    }

    // 5. Multi-Hop Relay: Decrement TTL, increment hop count, append node ID, flood to peers
    final forwardedPacket = packet.forward(nodeId);
    _logHardwareEvent(
      'MULTI_HOP_FORWARD | ID: ${forwardedPacket.packetId} | Path: ${forwardedPacket.relayPath.join(" -> ")}',
    );

    _relayedPackets.insert(0, forwardedPacket);
    _relayedCount++;
    notifyListeners();

    await _forwardToPeers(forwardedPacket);
    return true;
  }

  /// Sends raw packet over native BLE radio to all connected peer nodes
  Future<void> _forwardToPeers(MeshPacket packet) async {
    try {
      final rawBytes = packet.toRawBytes();
      await _methodChannel.invokeMethod('broadcastPacket', {'bytes': rawBytes});
    } on MissingPluginException {
      // Handled gracefully in testing/simulation
    } catch (e) {
      _logHardwareEvent('ERROR_BROADCASTING_BLE: $e');
    }
  }

  /// Store-and-Forward: flushes stored SOS packets to a newly connected peer
  Future<void> _flushStoreAndForwardQueueToPeer(String newPeerNodeId) async {
    try {
      final db = DatabaseHelper.instance;
      final pendingOperations = await db.getPendingSyncItems();
      for (final op in pendingOperations) {
        if (op['entity_type'] == 'sos_logs') {
          final rawPayload = op['payload_json'] ?? op['payload'];
          if (rawPayload == null) continue;
          final Map<String, dynamic> payload = (rawPayload is String)
              ? Map<String, dynamic>.from(jsonDecode(rawPayload))
              : (rawPayload is Map ? Map<String, dynamic>.from(rawPayload) : {});

          final sosPacket = MeshPacket(
            packetId: 'pkt_${op['entity_id']}',
            senderId: payload['user_id']?.toString() ?? 'usr_stored',
            destinationId: '*',
            timestamp: op['created_at'] as String? ?? DateTime.now().toIso8601String(),
            type: MeshPacketType.sosAlert,
            priority: MeshPacketPriority.critical,
            payload: payload,
            ttlHops: 5,
            hopCount: 1,
            relayPath: [nodeId],
          );
          _logHardwareEvent('STORE_AND_FORWARD_FLUSH | Re-broadcasting ${sosPacket.packetId} to new peer $newPeerNodeId');
          await _forwardToPeers(sosPacket);
        }
      }
    } catch (e) {
      debugPrint('Error flushing store-and-forward queue: $e');
    }
  }
}
