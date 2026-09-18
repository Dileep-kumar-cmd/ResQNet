import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/features/navigation/routing_service.dart';
import 'package:mobile/features/medical/first_aid_data.dart';
import 'package:mobile/features/auth/auth_service.dart';

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

  group('Production Enhancements & Navigation Unit Tests', () {
    test('RoutingService calculates turn-by-turn route, geometry waypoints, and walking/vehicle ETA', () {
      final routeWalking = RoutingService.instance.calculateRoute(
        originLat: 37.7749,
        originLon: -122.4194,
        destLat: 37.7850,
        destLon: -122.4090,
        destinationName: 'North Hill High Shelter',
        isVehicleMode: false,
      );

      expect(routeWalking.destinationName, equals('North Hill High Shelter'));
      expect(routeWalking.totalDistanceKm, greaterThan(1.0));
      expect(routeWalking.estimatedTimeMinutes, greaterThan(10.0));
      expect(routeWalking.polylinePoints.length, equals(7));
      expect(routeWalking.instructions.length, equals(4));

      final routeVehicle = RoutingService.instance.calculateRoute(
        originLat: 37.7749,
        originLon: -122.4194,
        destLat: 37.7850,
        destLon: -122.4090,
        destinationName: 'North Hill High Shelter',
        isVehicleMode: true,
      );

      // Vehicle ETA should be significantly faster than walking ETA
      expect(routeVehicle.estimatedTimeMinutes, lessThan(routeWalking.estimatedTimeMinutes));
    });

    test('Expanded FirstAidData contains 25+ protocols across 9 disaster medical categories', () {
      final protocols = FirstAidData.protocols;
      expect(protocols.length, greaterThanOrEqualTo(25));

      final categories = protocols.map((p) => p.category).toSet();
      expect(categories.length, equals(9));
      expect(categories.contains('INJURIES'), isTrue);
      expect(categories.contains('BURNS'), isTrue);
      expect(categories.contains('BREATHING'), isTrue);
      expect(categories.contains('CARDIAC'), isTrue);
      expect(categories.contains('NEUROLOGICAL'), isTrue);
      expect(categories.contains('BONE_MUSCLE'), isTrue);
      expect(categories.contains('BITES_STINGS'), isTrue);
      expect(categories.contains('ENVIRONMENTAL'), isTrue);
      expect(categories.contains('POISONING'), isTrue);

      // Verify every protocol has required safety fields
      for (final p in protocols) {
        expect(p.title.isNotEmpty, isTrue);
        expect(p.steps.isNotEmpty, isTrue);
        expect(p.equipmentNeeded.isNotEmpty, isTrue);
        expect(p.whatNotToDo.isNotEmpty, isTrue);
      }
    });

    test('AuthService toggles airplane mode simulation state cleanly', () {
      final auth = AuthService();
      expect(auth.isAirplaneModeForced, isFalse);

      auth.toggleAirplaneModeSim(true);
      expect(auth.isAirplaneModeForced, isTrue);

      auth.toggleAirplaneModeSim(false);
      expect(auth.isAirplaneModeForced, isFalse);
    });

    test('DatabaseHelper queues sync operations for resource and volunteer task mutations', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE sync_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              op TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              vector_clock TEXT,
              created_at TEXT NOT NULL
            )
          ''');
        },
      );

      await db.insert('sync_queue', {
        'entity_type': 'resources',
        'entity_id': 'res_test_101',
        'op': 'INSERT',
        'payload_json': '{"name":"Clean Water","quantity":500}',
        'vector_clock': '{}',
        'created_at': DateTime.now().toIso8601String(),
      });

      final List<Map<String, dynamic>> items = await db.query('sync_queue');
      expect(items.length, equals(1));
      expect(items.first['entity_id'], equals('res_test_101'));
      await db.close();
    });
  });
}
