import 'dart:convert';
import 'package:mobile/data/local/database_helper.dart';
import 'package:mobile/features/ai/tflite_engine.dart';

class MLShelterRecommendation {
  final Map<String, dynamic> rawShelter;
  final String id;
  final String name;
  final double distanceKm;
  final int availableCapacity;
  final double mlMatchConfidence; // 0.0 to 100.0 %
  final int inferenceLatencyMs;
  final Map<String, double> featureContributions;

  MLShelterRecommendation({
    required this.rawShelter,
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.availableCapacity,
    required this.mlMatchConfidence,
    required this.inferenceLatencyMs,
    required this.featureContributions,
  });
}

class ShelterMLRecommender {
  static final ShelterMLRecommender instance = ShelterMLRecommender._init();
  ShelterMLRecommender._init();

  static const List<String> _featureNames = [
    "Distance (km)", "Total Capacity", "Current Occupancy",
    "Hazard Level", "Generators", "Clean Water (L)", "First Aid Kits"
  ];

  /// Evaluates all cached shelters through the on-device ML model
  Future<List<MLShelterRecommendation>> getMLRecommendations({
    required double userLat,
    required double userLon,
  }) async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> rawShelters = await db.query('shelters');

    List<MLShelterRecommendation> recommendations = [];

    for (final s in rawShelters) {
      final String id = s['id'];
      final String name = s['name'];
      final double lat = (s['latitude'] as num).toDouble();
      final double lon = (s['longitude'] as num).toDouble();
      final int cap = s['capacity'] as int;
      final int occ = s['current_occupancy'] as int;
      final int hazard = s['hazard_rating'] as int;

      final double distKm = dbHelper.calculateDistanceKm(userLat, userLon, lat, lon);

      // Parse equipment JSON
      int generators = 0;
      double waterLiters = 0;
      int medicalKits = 0;

      if (s['equipment_json'] != null) {
        try {
          final Map<String, dynamic> equip = jsonDecode(s['equipment_json']);
          generators = equip['generators'] ?? 0;
          waterLiters = (equip['clean_water_liters'] ?? 0).toDouble();
          medicalKits = equip['first_aid_kits'] ?? 0;
        } catch (_) {}
      }

      // Build 7-feature input vector
      final List<double> features = [
        distKm,
        cap.toDouble(),
        occ.toDouble(),
        hazard.toDouble(),
        generators.toDouble(),
        waterLiters,
        medicalKits.toDouble(),
      ];

      // Run on-device ML inference
      final result = TFLiteEngine.instance.runInference(features, _featureNames);
      final double matchPercent = double.parse((result.predictionScore * 100.0).toStringAsFixed(1));

      recommendations.add(
        MLShelterRecommendation(
          rawShelter: s,
          id: id,
          name: name,
          distanceKm: double.parse(distKm.toStringAsFixed(2)),
          availableCapacity: cap - occ,
          mlMatchConfidence: matchPercent,
          inferenceLatencyMs: result.executionLatencyMs,
          featureContributions: result.featureContributions,
        ),
      );
    }

    // Sort descending by ML match confidence
    recommendations.sort((a, b) => b.mlMatchConfidence.compareTo(a.mlMatchConfidence));
    return recommendations;
  }
}
