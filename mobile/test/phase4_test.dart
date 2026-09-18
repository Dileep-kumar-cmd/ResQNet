import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/data/local/database_helper.dart';
import 'package:mobile/features/mesh/mesh_packet.dart';
import 'package:mobile/features/mesh/mesh_deduplicator.dart';
import 'package:mobile/features/mesh/mesh_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterSecureStorage.setMockInitialValues({});

    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async => '.',
    );
  });

  group('Phase 4 Mesh Comms Unit Tests', () {
    test('MeshPacket serializes and deserializes bytes cleanly', () {
      final origPacket = MeshPacket(
        packetId: 'pkt_test_101',
        senderId: 'usr_orig_01',
        timestamp: DateTime.now().toIso8601String(),
        type: MeshPacketType.sosAlert,
        payload: {'lat': 37.7749, 'lon': -122.4194},
        ttlHops: 5,
        hopCount: 0,
        relayPath: ['usr_orig_01'],
      );

      final Uint8List rawBytes = origPacket.toRawBytes();
      final MeshPacket restored = MeshPacket.fromRawBytes(rawBytes);

      expect(restored.packetId, equals('pkt_test_101'));
      expect(restored.senderId, equals('usr_orig_01'));
      expect(restored.ttlHops, equals(5));
      expect(restored.payload['lat'], equals(37.7749));
    });

    test('MeshPacket forwarding decrements TTL and appends relay node ID', () {
      final origPacket = MeshPacket(
        packetId: 'pkt_test_102',
        senderId: 'usr_node1',
        timestamp: DateTime.now().toIso8601String(),
        type: MeshPacketType.sosAlert,
        payload: {},
        ttlHops: 4,
        hopCount: 1,
        relayPath: ['usr_node1'],
      );

      final forwarded = origPacket.forward('usr_node2');

      expect(forwarded.ttlHops, equals(3));
      expect(forwarded.hopCount, equals(2));
      expect(forwarded.relayPath, equals(['usr_node1', 'usr_node2']));
    });

    test('MeshDeduplicator suppresses duplicate packets', () {
      final deduplicator = MeshDeduplicator.instance;
      deduplicator.clear();

      expect(deduplicator.hasSeen('pkt_dup_01'), isFalse);
      deduplicator.markSeen('pkt_dup_01');
      expect(deduplicator.hasSeen('pkt_dup_01'), isTrue);
    });

    test('MeshRouter broadcasts SOS packet and queues in SQLite local database', () async {
      await DatabaseHelper.instance.database;

      final router = MeshRouter.instance;
      final pkt = await router.broadcastSOSPacket(
        userId: 'usr_test_broadcaster',
        lat: 37.7749,
        lon: -122.4194,
        medicalNote: 'P2P Test SOS',
      );

      expect(pkt.senderId, equals('usr_test_broadcaster'));
      expect(pkt.relayPath.contains(router.nodeId), isTrue);

      // Verify second receive of same packet is suppressed by deduplicator
      final bool result = await router.receiveIncomingPacket(pkt);
      expect(result, isFalse);
    });
  });
}
