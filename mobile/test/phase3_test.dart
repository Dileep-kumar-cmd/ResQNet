import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/data/local/database_helper.dart';
import 'package:mobile/features/ai/tflite_engine.dart';
import 'package:mobile/features/ai/shelter_ml_recommender.dart';
import 'package:mobile/features/ai/resource_shortage_predictor.dart';

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

  group('Phase 3 AI & ML Unit Tests', () {
    test('TFLiteEngine executes matrix inference on-device in < 50ms', () {
      final List<double> features = [
        2.5,   // distance_km
        500.0, // capacity
        120.0, // occupancy
        1.0,   // hazard_rating
        3.0,   // generators
        8000.0,// water_liters
        50.0,  // medical_kits
      ];
      final List<String> names = [
        "Distance (km)", "Total Capacity", "Current Occupancy",
        "Hazard Level", "Generators", "Clean Water (L)", "First Aid Kits"
      ];

      final result = TFLiteEngine.instance.runInference(features, names);

      expect(result.executionLatencyMs, lessThan(50));
      expect(result.predictionScore, greaterThan(0.0));
      expect(result.predictionScore, lessThanOrEqualTo(1.0));
      expect(result.featureContributions.length, equals(7));
    });

    test('ShelterMLRecommender ranks shelters by ML match confidence', () async {
      await DatabaseHelper.instance.database;

      final recs = await ShelterMLRecommender.instance.getMLRecommendations(
        userLat: 37.7749,
        userLon: -122.4194,
      );

      expect(recs.isNotEmpty, isTrue);
      expect(recs.first.mlMatchConfidence, greaterThan(0.0));
      expect(recs.first.mlMatchConfidence, lessThanOrEqualTo(100.0));
      expect(recs.first.inferenceLatencyMs, lessThan(50));
    });

    test('ResourceShortagePredictor calculates depletion hours for water, food, and medical supplies', () async {
      await DatabaseHelper.instance.database;

      final forecasts = await ResourceShortagePredictor.instance.predictShortages();

      expect(forecasts.isNotEmpty, isTrue);
      final first = forecasts.first;
      expect(first.waterHoursRemaining, greaterThan(0.0));
      expect(first.foodHoursRemaining, greaterThan(0.0));
      expect(first.medicalHoursRemaining, greaterThan(0.0));
    });
  });
}
