import 'dart:math';
import 'package:mobile/data/local/database_helper.dart';

class RankedShelter {
  final Map<String, dynamic> rawData;
  final String id;
  final String name;
  final double distanceKm;
  final int capacity;
  final int currentOccupancy;
  final int availableCapacity;
  final int hazardRating;
  final double compositeScore; // 0 to 100
  final double proximitySubScore;
  final double capacitySubScore;
  final double hazardSubScore;

  double get latitude => (rawData['latitude'] as num).toDouble();
  double get longitude => (rawData['longitude'] as num).toDouble();

  RankedShelter({
    required this.rawData,
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.capacity,
    required this.currentOccupancy,
    required this.availableCapacity,
    required this.hazardRating,
    required this.compositeScore,
    required this.proximitySubScore,
    required this.capacitySubScore,
    required this.hazardSubScore,
  });
}

class ShelterRankingService {
  static final ShelterRankingService instance = ShelterRankingService._init();
  ShelterRankingService._init();

  /// Ranks all cached shelters using multi-criteria weighted scoring
  Future<List<RankedShelter>> rankShelters({
    required double userLat,
    required double userLon,
    double weightProximity = 0.40,
    double weightCapacity = 0.35,
    double weightHazard = 0.25,
  }) async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> rawShelters = await db.query('shelters');

    List<RankedShelter> rankedList = [];

    for (final s in rawShelters) {
      final String id = s['id'];
      final String name = s['name'];
      final double lat = (s['latitude'] as num).toDouble();
      final double lon = (s['longitude'] as num).toDouble();
      final int cap = s['capacity'] as int;
      final int occ = s['current_occupancy'] as int;
      final int hazard = s['hazard_rating'] as int;

      final double distKm = dbHelper.calculateDistanceKm(userLat, userLon, lat, lon);
      final int availCap = max(0, cap - occ);

      // 1. Sub-Score: Proximity (decay curve: 1.0 at 0km, 0.5 at 5km)
      final double proxScore = (1.0 / (1.0 + (distKm / 3.0))) * 100.0;

      // 2. Sub-Score: Available Capacity Ratio (0% available -> 0, 100% available -> 100)
      final double capRatio = cap > 0 ? (availCap / cap) : 0.0;
      final double capScore = capRatio * 100.0;

      // 3. Sub-Score: Hazard Safety (hazard rating 0 -> 100, hazard rating 5 -> 0)
      final double hazardScore = max(0.0, (1.0 - (hazard / 5.0))) * 100.0;

      // Weighted Composite Score calculation
      final double composite = (proxScore * weightProximity) +
          (capScore * weightCapacity) +
          (hazardScore * weightHazard);

      rankedList.add(
        RankedShelter(
          rawData: s,
          id: id,
          name: name,
          distanceKm: distKm,
          capacity: cap,
          currentOccupancy: occ,
          availableCapacity: availCap,
          hazardRating: hazard,
          compositeScore: double.parse(composite.toStringAsFixed(1)),
          proximitySubScore: double.parse(proxScore.toStringAsFixed(1)),
          capacitySubScore: double.parse(capScore.toStringAsFixed(1)),
          hazardSubScore: double.parse(hazardScore.toStringAsFixed(1)),
        ),
      );
    }

    // Sort descending by composite score
    rankedList.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
    return rankedList;
  }
}
