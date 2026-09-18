import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/alerts/emergency_alert_service.dart';
import 'package:mobile/features/mesh/mesh_packet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Emergency Alert & Sound Service Unit Tests', () {
    test('EmergencyAlertEvent creates properly from MeshPacket', () {
      final packet = MeshPacket(
        packetId: 'pkt_sos_test_456',
        senderId: 'usr_responder_alpha',
        destinationId: '*',
        timestamp: '2026-09-18T10:00:00Z',
        type: MeshPacketType.sosAlert,
        priority: MeshPacketPriority.critical,
        payload: {
          'sos_id': 'sos_test_456',
          'user_id': 'usr_responder_alpha',
          'latitude': 37.7812,
          'longitude': -122.4160,
          'medical_note': 'Severe bleeding and structural collapse',
        },
        ttlHops: 5,
        hopCount: 0,
        relayPath: ['node_source'],
      );

      final alert = EmergencyAlertEvent.fromMeshPacket(packet, isOriginator: false);
      expect(alert.id, equals('pkt_sos_test_456'));
      expect(alert.senderId, equals('usr_responder_alpha'));
      expect(alert.latitude, closeTo(37.7812, 0.0001));
      expect(alert.longitude, closeTo(-122.4160, 0.0001));
      expect(alert.medicalNote, contains('Severe bleeding'));
      expect(alert.priority, equals('CRITICAL'));
      expect(alert.isOriginator, isFalse);
      expect(alert.source, equals('BLE_MESH'));
    });

    test('EmergencyAlertService broadcasts alert to stream and adds to recentAlerts', () async {
      final service = EmergencyAlertService.instance;
      final testAlert = EmergencyAlertEvent(
        id: 'sos_custom_99',
        senderId: 'usr_volunteer_01',
        latitude: 37.7749,
        longitude: -122.4194,
        medicalNote: 'Hypothermia reported',
        timestamp: DateTime.now().toIso8601String(),
        isOriginator: true,
      );

      EmergencyAlertEvent? receivedEvent;
      final sub = service.alertStream.listen((event) {
        receivedEvent = event;
      });

      await service.triggerAlert(testAlert);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.id, equals('sos_custom_99'));
      expect(service.activeAlert?.id, equals('sos_custom_99'));
      expect(service.recentAlerts.any((a) => a.id == 'sos_custom_99'), isTrue);

      service.dismissActiveAlert();
      expect(service.activeAlert, isNull);

      await sub.cancel();
    });
  });
}
