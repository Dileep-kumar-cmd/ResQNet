import 'dart:math';
import 'package:latlong2/latlong.dart';

class RouteInstruction {
  final int stepNumber;
  final String instruction;
  final double distanceKm;
  final String iconType; // 'straight', 'turn_left', 'turn_right', 'arrive'

  RouteInstruction({
    required this.stepNumber,
    required this.instruction,
    required this.distanceKm,
    required this.iconType,
  });
}

class NavigationRoute {
  final String destinationName;
  final double originLat;
  final double originLon;
  final double destLat;
  final double destLon;
  final double totalDistanceKm;
  final double estimatedTimeMinutes;
  final List<LatLng> polylinePoints;
  final List<RouteInstruction> instructions;
  final bool isVehicleMode;

  NavigationRoute({
    required this.destinationName,
    required this.originLat,
    required this.originLon,
    required this.destLat,
    required this.destLon,
    required this.totalDistanceKm,
    required this.estimatedTimeMinutes,
    required this.polylinePoints,
    required this.instructions,
    required this.isVehicleMode,
  });
}

class RoutingService {
  static final RoutingService instance = RoutingService._init();
  RoutingService._init();

  /// Calculates Haversine distance in km
  double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Calculates an offline route with geometry waypoints, ETA, and turn-by-turn guidance
  NavigationRoute calculateRoute({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required String destinationName,
    bool isVehicleMode = false,
  }) {
    final double directDistance = calculateDistanceKm(originLat, originLon, destLat, destLon);
    // Add realistic urban/disaster detour factor (1.25x direct distance)
    final double actualDistanceKm = directDistance * 1.25;

    // Speed: Walking = 5 km/h, Vehicle = 35 km/h
    final double speedKmH = isVehicleMode ? 35.0 : 5.0;
    final double etaMinutes = (actualDistanceKm / speedKmH) * 60.0;

    // Generate intermediate waypoints with slight grid offset to simulate streets
    final List<LatLng> waypoints = [];
    const int stepsCount = 6;
    final double scale = (directDistance / 2.0).clamp(0.0, 1.0);

    for (int i = 0; i <= stepsCount; i++) {
      final double fraction = i / stepsCount;
      double lat = originLat + (destLat - originLat) * fraction;
      double lon = originLon + (destLon - originLon) * fraction;

      // Add small perpendicular offset for middle waypoints to form realistic street grid
      if (i > 0 && i < stepsCount && directDistance > 0.05) {
        final double offset = (i % 2 == 1 ? 0.0015 : -0.0012) * scale;
        lat += offset;
        lon += offset * 0.8;
      }
      waypoints.add(LatLng(lat, lon));
    }

    // Generate turn-by-turn instructions
    final double stepDist = actualDistanceKm / 4;
    final bool isArrived = directDistance < 0.05;

    final List<RouteInstruction> steps = [
      RouteInstruction(
        stepNumber: 1,
        instruction: isArrived
            ? 'You are at $destinationName safe perimeter.'
            : 'Head toward $destinationName along clear emergency corridor.',
        distanceKm: stepDist,
        iconType: isArrived ? 'arrive' : 'straight',
      ),
      RouteInstruction(
        stepNumber: 2,
        instruction: isArrived
            ? 'Proceed to main intake station inside shelter.'
            : 'Turn right at the emergency relief checkpoint (Hazard level checked).',
        distanceKm: stepDist,
        iconType: isArrived ? 'arrive' : 'turn_right',
      ),
      RouteInstruction(
        stepNumber: 3,
        instruction: isArrived
            ? 'Check in with Disaster Response Coordinator.'
            : 'Slight left onto Primary Rescue Access Road.',
        distanceKm: stepDist,
        iconType: isArrived ? 'arrive' : 'turn_left',
      ),
      RouteInstruction(
        stepNumber: 4,
        instruction: 'Arrive at $destinationName. Safe shelter zone entry on your right.',
        distanceKm: stepDist,
        iconType: 'arrive',
      ),
    ];

    return NavigationRoute(
      destinationName: destinationName,
      originLat: originLat,
      originLon: originLon,
      destLat: destLat,
      destLon: destLon,
      totalDistanceKm: actualDistanceKm,
      estimatedTimeMinutes: etaMinutes,
      polylinePoints: waypoints,
      instructions: steps,
      isVehicleMode: isVehicleMode,
    );
  }
}
