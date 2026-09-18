import 'dart:convert';
import 'dart:typed_data';

enum MeshPacketType {
  sosAlert,
  shelterUpdate,
  heartbeat,
  ack,
  peerDiscovery,
  chatMessage,
}

enum MeshPacketPriority {
  critical,
  high,
  normal,
  low,
}

class MeshPacket {
  final int version;
  final String packetId;
  final String senderId;
  final String destinationId;
  final String timestamp;
  final MeshPacketType type;
  final MeshPacketPriority priority;
  final Map<String, dynamic> payload;
  final int ttlHops;
  final int hopCount;
  final List<String> relayPath;

  MeshPacket({
    this.version = 1,
    required this.packetId,
    required this.senderId,
    this.destinationId = '*',
    required this.timestamp,
    required this.type,
    this.priority = MeshPacketPriority.normal,
    required this.payload,
    this.ttlHops = 5,
    this.hopCount = 0,
    required this.relayPath,
  });

  /// Decrements TTL and appends current relaying node ID to relay path
  MeshPacket forward(String currentRelayNodeId) {
    List<String> newPath = List<String>.from(relayPath);
    if (!newPath.contains(currentRelayNodeId)) {
      newPath.add(currentRelayNodeId);
    }
    return MeshPacket(
      version: version,
      packetId: packetId,
      senderId: senderId,
      destinationId: destinationId,
      timestamp: timestamp,
      type: type,
      priority: priority,
      payload: payload,
      ttlHops: ttlHops - 1,
      hopCount: hopCount + 1,
      relayPath: newPath,
    );
  }

  bool get isExpired => ttlHops <= 0;

  Map<String, dynamic> toJson() => {
        'version': version,
        'packet_id': packetId,
        'sender_id': senderId,
        'destination_id': destinationId,
        'timestamp': timestamp,
        'type': type.name,
        'priority': priority.name,
        'payload': payload,
        'ttl_hops': ttlHops,
        'hop_count': hopCount,
        'relay_path': relayPath,
      };

  factory MeshPacket.fromJson(Map<String, dynamic> json) => MeshPacket(
        version: json['version'] ?? 1,
        packetId: json['packet_id'] ?? json['packetId'] ?? 'pkt_${DateTime.now().millisecondsSinceEpoch}',
        senderId: json['sender_id'] ?? json['senderId'] ?? 'unknown_sender',
        destinationId: json['destination_id'] ?? json['destinationId'] ?? '*',
        timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
        type: MeshPacketType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => MeshPacketType.sosAlert,
        ),
        priority: MeshPacketPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => (json['type'] == 'sosAlert' ? MeshPacketPriority.critical : MeshPacketPriority.normal),
        ),
        payload: Map<String, dynamic>.from(json['payload'] ?? {}),
        ttlHops: json['ttl_hops'] ?? json['ttlHops'] ?? 5,
        hopCount: json['hop_count'] ?? json['hopCount'] ?? 0,
        relayPath: List<String>.from(json['relay_path'] ?? json['relayPath'] ?? []),
      );

  Uint8List toRawBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory MeshPacket.fromRawBytes(Uint8List bytes) {
    final String str = utf8.decode(bytes);
    return MeshPacket.fromJson(jsonDecode(str));
  }
}
