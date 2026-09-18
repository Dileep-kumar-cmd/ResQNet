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
    FlutterSecureStorage.setMockInitialValues({'mesh_node_id': 'node_test_local_99'});

    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async => '.',
    );

    const MethodChannel meshChannel = MethodChannel('com.resqnet.mobile/mesh');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      meshChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermissions') return true;
        if (methodCall.method == 'startMesh') return true;
        if (methodCall.method == 'broadcastPacket') return 1;
        return null;
      },
    );
  });

  group('Real BLE Decentralized Mesh Protocol Unit Tests', () {
    test('MeshPacket supports priority, destinationId, and compact serialization', () {
      final packet = MeshPacket(
        version: 1,
        packetId: 'pkt_sos_888',
        senderId: 'node_alpha',
        destinationId: '*',
        timestamp: '2026-09-18T03:00:00.000Z',
        type: MeshPacketType.sosAlert,
        priority: MeshPacketPriority.critical,
        payload: {
          'sos_id': 'sos_888',
          'lat': 37.7812,
          'lon': -122.4160,
          'medical_note': 'Disaster test',
        },
        ttlHops: 5,
        hopCount: 0,
        relayPath: ['node_alpha'],
      );

      final rawBytes = packet.toRawBytes();
      expect(rawBytes.isNotEmpty, isTrue);

      final restored = MeshPacket.fromRawBytes(rawBytes);
      expect(restored.version, equals(1));
      expect(restored.packetId, equals('pkt_sos_888'));
      expect(restored.senderId, equals('node_alpha'));
      expect(restored.destinationId, equals('*'));
      expect(restored.type, equals(MeshPacketType.sosAlert));
      expect(restored.priority, equals(MeshPacketPriority.critical));
      expect(restored.payload['lat'], equals(37.7812));
    });

    test('MeshRouter multi-hop relay forwards packets and decrements TTL', () async {
      await DatabaseHelper.instance.database;
      final router = MeshRouter.instance;
      MeshDeduplicator.instance.clear();

      final incomingPkt = MeshPacket(
        packetId: 'pkt_multihop_001',
        senderId: 'node_phone_A',
        destinationId: '*',
        timestamp: DateTime.now().toIso8601String(),
        type: MeshPacketType.sosAlert,
        priority: MeshPacketPriority.critical,
        payload: {'sos_id': 'sos_test_relay'},
        ttlHops: 5,
        hopCount: 0,
        relayPath: ['node_phone_A'],
      );

      final bool relayed = await router.receiveIncomingPacket(incomingPkt);
      expect(relayed, isTrue);

      // Verify the relayed packet has decremented TTL and appended router node ID
      final lastRelayed = router.relayedPackets.firstWhere((p) => p.packetId == 'pkt_multihop_001');
      expect(lastRelayed.ttlHops, equals(4));
      expect(lastRelayed.hopCount, equals(1));
      expect(lastRelayed.relayPath, contains('node_phone_A'));
      expect(lastRelayed.relayPath, contains(router.nodeId));
    });

    test('MeshRouter processes ACK packet and confirms message delivery', () async {
      final router = MeshRouter.instance;
      MeshDeduplicator.instance.clear();

      final ackPacket = MeshPacket(
        packetId: 'pkt_ack_sos_888_node_B',
        senderId: 'node_phone_B',
        destinationId: router.nodeId,
        timestamp: DateTime.now().toIso8601String(),
        type: MeshPacketType.ack,
        priority: MeshPacketPriority.high,
        payload: {
          'ack_for': 'pkt_sos_888',
          'acked_by': 'node_phone_B',
        },
        ttlHops: 5,
        hopCount: 1,
        relayPath: ['node_phone_B'],
      );

      await router.receiveIncomingPacket(ackPacket);
      expect(router.acknowledgedPacketIds.contains('pkt_sos_888'), isTrue);
    });

    test('MeshRouter duplicate suppression halts broadcast loops', () async {
      final router = MeshRouter.instance;

      final dupPacket = MeshPacket(
        packetId: 'pkt_loop_prevention_123',
        senderId: 'node_phone_X',
        timestamp: DateTime.now().toIso8601String(),
        type: MeshPacketType.sosAlert,
        payload: {'test': true},
        ttlHops: 3,
        hopCount: 2,
        relayPath: ['node_phone_X', 'node_phone_Y'],
      );

      // First delivery: Accepted & forwarded
      final firstResult = await router.receiveIncomingPacket(dupPacket);
      expect(firstResult, isTrue);

      // Second delivery: Suppressed by deduplicator
      final initialSuppressed = router.duplicatedSuppressedCount;
      final secondResult = await router.receiveIncomingPacket(dupPacket);
      expect(secondResult, isFalse);
      expect(router.duplicatedSuppressedCount, equals(initialSuppressed + 1));
    });
  });
}
