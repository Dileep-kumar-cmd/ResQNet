import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobile/features/mesh/mesh_packet.dart';

class EmergencyAlertEvent {
  final String id;
  final String senderId;
  final double latitude;
  final double longitude;
  final String medicalNote;
  final String timestamp;
  final bool isOriginator;
  final String priority;
  final String source; // 'BLE_MESH' | 'CLOUD_SYNC' | 'LOCAL'

  EmergencyAlertEvent({
    required this.id,
    required this.senderId,
    required this.latitude,
    required this.longitude,
    required this.medicalNote,
    required this.timestamp,
    this.isOriginator = false,
    this.priority = 'CRITICAL',
    this.source = 'BLE_MESH',
  });

  factory EmergencyAlertEvent.fromMeshPacket(MeshPacket packet, {bool isOriginator = false}) {
    final payload = packet.payload;
    final lat = (payload['latitude'] is num) ? (payload['latitude'] as num).toDouble() : 37.7749;
    final lon = (payload['longitude'] is num) ? (payload['longitude'] as num).toDouble() : -122.4194;
    final note = payload['medical_note'] as String? ?? 'Emergency assistance requested via P2P Mesh';

    return EmergencyAlertEvent(
      id: packet.packetId,
      senderId: packet.senderId,
      latitude: lat,
      longitude: lon,
      medicalNote: note,
      timestamp: packet.timestamp,
      isOriginator: isOriginator,
      priority: packet.priority.name.toUpperCase(),
      source: 'BLE_MESH',
    );
  }

  factory EmergencyAlertEvent.fromMap(Map<String, dynamic> map, {String source = 'CLOUD_SYNC'}) {
    final lat = (map['latitude'] is num) ? (map['latitude'] as num).toDouble() : 37.7749;
    final lon = (map['longitude'] is num) ? (map['longitude'] as num).toDouble() : -122.4194;
    final note = map['medical_note'] as String? ?? 'Emergency assistance required';

    return EmergencyAlertEvent(
      id: map['id']?.toString() ?? 'sos_${DateTime.now().millisecondsSinceEpoch}',
      senderId: map['user_id']?.toString() ?? 'usr_unknown',
      latitude: lat,
      longitude: lon,
      medicalNote: note,
      timestamp: map['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      isOriginator: false,
      priority: 'CRITICAL',
      source: source,
    );
  }
}

class EmergencyAlertService extends ChangeNotifier {
  static final EmergencyAlertService instance = EmergencyAlertService._init();
  EmergencyAlertService._init();

  static const MethodChannel _methodChannel = MethodChannel('com.resqnet.mobile/mesh');
  final StreamController<EmergencyAlertEvent> _alertStreamController =
      StreamController<EmergencyAlertEvent>.broadcast();

  final List<EmergencyAlertEvent> _recentAlerts = [];
  EmergencyAlertEvent? _activeAlert;

  Stream<EmergencyAlertEvent> get alertStream => _alertStreamController.stream;
  List<EmergencyAlertEvent> get recentAlerts => List.unmodifiable(_recentAlerts);
  EmergencyAlertEvent? get activeAlert => _activeAlert;

  /// Trigger emergency alert event and sound
  Future<void> triggerAlertFromPacket(MeshPacket packet, {bool isOriginator = false}) async {
    final event = EmergencyAlertEvent.fromMeshPacket(packet, isOriginator: isOriginator);
    await triggerAlert(event);
  }

  /// Trigger emergency alert with sound and broadcast to listeners
  Future<void> triggerAlert(EmergencyAlertEvent event) async {
    _activeAlert = event;
    _recentAlerts.insert(0, event);
    if (_recentAlerts.length > 30) {
      _recentAlerts.removeLast();
    }

    notifyListeners();
    _alertStreamController.add(event);

    // Play native short deep emergency sound
    await playEmergencySound();
  }

  /// Plays short deep emergency sound (180 Hz, 2 bursts) via native Android AudioTrack
  Future<void> playEmergencySound({double frequency = 180.0, int bursts = 2}) async {
    try {
      await _methodChannel.invokeMethod('playEmergencyAlertSound', {
        'frequency': frequency,
        'bursts': bursts,
      });
      debugPrint('[ALERT_SOUND] Short deep emergency tone triggered ($frequency Hz, $bursts bursts)');
    } on MissingPluginException {
      // Graceful fallback in unit tests / simulated environments
      debugPrint('[ALERT_SOUND] Platform channel unavailable (Test/Mock environment)');
    } catch (e) {
      debugPrint('[ALERT_SOUND_ERROR] $e');
    }
  }

  void dismissActiveAlert() {
    _activeAlert = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _alertStreamController.close();
    super.dispose();
  }
}
