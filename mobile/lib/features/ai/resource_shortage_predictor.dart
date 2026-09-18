import 'dart:convert';
import 'dart:math';
import 'package:mobile/data/local/database_helper.dart';

enum ShortageRiskLevel { adequate, warning, critical }

class ResourceShortageForecast {
  final String shelterId;
  final String shelterName;
  final int occupantCount;
  final double waterHoursRemaining;
  final double foodHoursRemaining;
  final double medicalHoursRemaining;
  final ShortageRiskLevel overallRiskLevel;

  ResourceShortageForecast({
    required this.shelterId,
    required this.shelterName,
    required this.occupantCount,
    required this.waterHoursRemaining,
    required this.foodHoursRemaining,
    required this.medicalHoursRemaining,
    required this.overallRiskLevel,
  });
}

class ResourceShortagePredictor {
  static final ResourceShortagePredictor instance = ResourceShortagePredictor._init();
  ResourceShortagePredictor._init();

  /// Consumption rates per person per day
  static const double _waterLitersPerPersonDay = 3.5;
  static const double _mealsPerPersonDay = 2.0;
  static const double _medicalKitsPerPersonDay = 0.10;

  /// Forecasts resource depletion hours across all local shelters
  Future<List<ResourceShortageForecast>> predictShortages() async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> rawShelters = await db.query('shelters');

    List<ResourceShortageForecast> forecasts = [];

    for (final s in rawShelters) {
      final String id = s['id'];
      final String name = s['name'];
      final int occupants = max(1, s['current_occupancy'] as int);

      double waterLiters = 2500;
      double mealsCount = (occupants * 6).toDouble(); // default fallback 3 days of food
      double medicalKits = 25;

      if (s['equipment_json'] != null) {
        try {
          final Map<String, dynamic> equip = jsonDecode(s['equipment_json']);
          waterLiters = (equip['clean_water_liters'] ?? 2500).toDouble();
          medicalKits = (equip['first_aid_kits'] ?? 25).toDouble();
          mealsCount = (equip['food_meals'] ?? (occupants * 6)).toDouble();
        } catch (_) {}
      }

      // Calculate depletion hours: (Total Supply / (Occupants * (Rate / 24.0)))
      final double waterHours = waterLiters / (occupants * (_waterLitersPerPersonDay / 24.0));
      final double foodHours = mealsCount / (occupants * (_mealsPerPersonDay / 24.0));
      final double medHours = medicalKits / (occupants * (_medicalKitsPerPersonDay / 24.0));

      final minHours = [waterHours, foodHours, medHours].reduce((a, b) => a < b ? a : b);

      ShortageRiskLevel risk;
      if (minHours < 24.0) {
        risk = ShortageRiskLevel.critical;
      } else if (minHours < 72.0) {
        risk = ShortageRiskLevel.warning;
      } else {
        risk = ShortageRiskLevel.adequate;
      }

      forecasts.add(
        ResourceShortageForecast(
          shelterId: id,
          shelterName: name,
          occupantCount: occupants,
          waterHoursRemaining: double.parse(waterHours.toStringAsFixed(1)),
          foodHoursRemaining: double.parse(foodHours.toStringAsFixed(1)),
          medicalHoursRemaining: double.parse(medHours.toStringAsFixed(1)),
          overallRiskLevel: risk,
        ),
      );
    }

    // Sort ascending by hours remaining (most urgent first)
    forecasts.sort((a, b) => a.waterHoursRemaining.compareTo(b.waterHoursRemaining));
    return forecasts;
  }
}
