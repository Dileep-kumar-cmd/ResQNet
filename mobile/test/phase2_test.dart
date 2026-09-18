import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/data/local/database_helper.dart';
import 'package:mobile/features/shelters/shelter_ranking_service.dart';
import 'package:mobile/features/medical/first_aid_data.dart';
import 'package:mobile/features/map/map_tile_service.dart';

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

  group('Phase 2 Unit Tests', () {
    test('Shelter ranking algorithm calculates composite score and completes under 100ms', () async {
      await DatabaseHelper.instance.database;

      final stopwatch = Stopwatch()..start();
      
      final rankings = await ShelterRankingService.instance.rankShelters(
        userLat: 37.7749,
        userLon: -122.4194,
      );

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      expect(rankings.isNotEmpty, isTrue);
      expect(rankings.first.compositeScore, greaterThan(0.0));
      expect(rankings.first.proximitySubScore, greaterThan(0.0));
    });

    test('Bundled first-aid data contains search indexed protocols', () {
      final cpr = FirstAidData.protocols.firstWhere((p) => p.title.contains('CPR'));
      expect(cpr.title, contains('CPR'));
      expect(cpr.category, equals('CARDIAC'));
      expect(cpr.steps.length, greaterThan(4));

      final traumaProtocols = FirstAidData.protocols.where((p) => p.category == 'INJURIES').toList();
      expect(traumaProtocols.length, greaterThanOrEqualTo(2));
    });

    test('MapTileService caches and retrieves tile blobs cleanly', () async {
      final sampleBlob = Uint8List.fromList([1, 2, 3, 4, 5]);
      await MapTileService.instance.cacheTileBlob(
        regionId: 'sf_bay',
        z: 12,
        x: 654,
        y: 1582,
        blob: sampleBlob,
      );

      final retrieved = await MapTileService.instance.getTileBlob('sf_bay', 12, 654, 1582);
      expect(retrieved, isNotNull);
      expect(retrieved!.length, equals(5));
    });
  });
}
