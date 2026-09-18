// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mobile/features/navigation/routing_service.dart';

class NavigationScreen extends StatefulWidget {
  final String destinationName;
  final double destinationLat;
  final double destinationLon;
  final double userLat;
  final double userLon;

  const NavigationScreen({
    super.key,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLon,
    this.userLat = 37.7749,
    this.userLon = -122.4194,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> with SingleTickerProviderStateMixin {
  bool _isVehicleMode = false;
  late NavigationRoute _route;
  int _currentStepIndex = 0;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _recalculateRoute();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _recalculateRoute() {
    setState(() {
      _route = RoutingService.instance.calculateRoute(
        originLat: widget.userLat,
        originLon: widget.userLon,
        destLat: widget.destinationLat,
        destLon: widget.destinationLon,
        destinationName: widget.destinationName,
        isVehicleMode: _isVehicleMode,
      );
      if (_currentStepIndex >= _route.instructions.length) {
        _currentStepIndex = 0;
      }
    });
  }

  void _nextStep() {
    if (_currentStepIndex < _route.instructions.length - 1) {
      setState(() => _currentStepIndex++);
    }
  }

  void _prevStep() {
    if (_currentStepIndex > 0) {
      setState(() => _currentStepIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final etaStr = _route.estimatedTimeMinutes.toStringAsFixed(0);
    final distStr = _route.totalDistanceKm.toStringAsFixed(2);
    final currentStep = _route.instructions.isNotEmpty && _currentStepIndex < _route.instructions.length
        ? _route.instructions[_currentStepIndex]
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B111E),
      appBar: AppBar(
        title: Text(
          'Navigation: ${widget.destinationName}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isVehicleMode ? Icons.directions_car : Icons.directions_walk,
              color: Colors.cyanAccent,
            ),
            tooltip: _isVehicleMode ? 'Switch to Walking (5 km/h)' : 'Switch to Vehicle (35 km/h)',
            onPressed: () {
              setState(() {
                _isVehicleMode = !_isVehicleMode;
                _recalculateRoute();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isVehicleMode ? 'Switched to Vehicle Rescue Mode (35 km/h)' : 'Switched to Walking Evacuation Mode (5 km/h)',
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF1E293B),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Route Summary Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _isVehicleMode ? Icons.directions_car : Icons.directions_walk,
                                  color: Colors.greenAccent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$etaStr MINS ($distStr km)',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Target: ${widget.destinationName}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _recalculateRoute();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Offline route recalculated using latest emergency waypoints.'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Color(0xFF1E293B),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reroute'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isVehicleMode = !_isVehicleMode;
                          _recalculateRoute();
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isVehicleMode ? Colors.amber.shade900.withOpacity(0.4) : Colors.indigo.shade900.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _isVehicleMode ? Colors.amber : Colors.indigoAccent, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_isVehicleMode ? Icons.directions_car : Icons.directions_walk, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              _isVehicleMode ? 'Vehicle (35 km/h)' : 'Walking (5 km/h)',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade900.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.greenAccent, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 12, color: Colors.greenAccent),
                          SizedBox(width: 4),
                          Text('Offline Corridor Verified', style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tactical Route Map Vector Visualizer Canvas with HUD overlay
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          color: const Color(0xFF090D16),
                          child: CustomPaint(
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                            painter: RoutePainter(
                              route: _route,
                              userLat: widget.userLat,
                              userLon: widget.userLon,
                              activeStepIndex: _currentStepIndex,
                              pulseValue: _animController.value,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                // Tactical HUD Overlay (Compass / North Indicator & Scale)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.redAccent, width: 1.5),
                              ),
                              child: const Center(
                                child: Text('N', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('TACTICAL GRID', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('GPS LOCK: ACTIVE', style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),

                // Floating Step Controller Banner (Above Instructions)
                if (currentStep != null)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Step Turn Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getStepIcon(currentStep.iconType),
                              color: Colors.cyanAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Step Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'STEP ${_currentStepIndex + 1} OF ${_route.instructions.length}',
                                      style: const TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${currentStep.distanceKm.toStringAsFixed(2)} km',
                                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentStep.instruction,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Step Prev/Next Arrows
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                                onPressed: _currentStepIndex > 0 ? _prevStep : null,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, color: Colors.white),
                                onPressed: _currentStepIndex < _route.instructions.length - 1 ? _nextStep : null,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Step-by-Step Guidance List
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF0A0F1D),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'EMERGENCY NAVIGATION STEPS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${_route.instructions.length} Checkpoints',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _route.instructions.length,
                      itemBuilder: (context, idx) {
                        final step = _route.instructions[idx];
                        final isCurrent = idx == _currentStepIndex;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCurrent ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCurrent ? Colors.cyanAccent : const Color(0xFF1E293B),
                              width: isCurrent ? 1.5 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: isCurrent ? Colors.cyanAccent : Colors.white12,
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  color: isCurrent ? Colors.black : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              step.instruction,
                              style: TextStyle(
                                color: isCurrent ? Colors.white : Colors.white70,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'Distance: ${step.distanceKm.toStringAsFixed(2)} km',
                              style: TextStyle(
                                color: isCurrent ? Colors.cyanAccent : Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            trailing: isCurrent
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.cyanAccent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'CURRENT',
                                      style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
                            onTap: () => setState(() => _currentStepIndex = idx),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Navigation ended. Safe shelter check-in recorded.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('ARRIVED / END NAVIGATION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStepIcon(String iconType) {
    switch (iconType) {
      case 'turn_right':
        return Icons.turn_right;
      case 'turn_left':
        return Icons.turn_left;
      case 'arrive':
        return Icons.place;
      case 'straight':
      default:
        return Icons.navigation;
    }
  }
}

class RoutePainter extends CustomPainter {
  final NavigationRoute route;
  final double userLat;
  final double userLon;
  final int activeStepIndex;
  final double pulseValue;

  RoutePainter({
    required this.route,
    required this.userLat,
    required this.userLon,
    this.activeStepIndex = 0,
    this.pulseValue = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Compute route center & span with aspect ratio preservation
    final midLat = (userLat + route.destLat) / 2;
    final midLon = (userLon + route.destLon) / 2;

    final latDist = (userLat - route.destLat).abs();
    final lonDist = (userLon - route.destLon).abs();
    final maxSpan = max(max(latDist, lonDist), 0.003) * 1.55;

    final scaleX = (size.width * 0.72) / maxSpan;
    final scaleY = (size.height * 0.72) / maxSpan;
    final scale = min(scaleX, scaleY);

    Offset toCanvasPos(double lat, double lon) {
      final dx = (lon - midLon) * scale;
      final dy = -(lat - midLat) * scale;
      return center + Offset(dx, dy);
    }

    // 1. Tactical Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.4)
      ..strokeWidth = 1.0;
    const double gridSize = 35.0;
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Simulated Urban Street Network (Corridors)
    final streetPaint = Paint()
      ..color = const Color(0xFF334155).withOpacity(0.3)
      ..strokeWidth = 6.0;

    // Background reference street axes
    canvas.drawLine(Offset(0, center.dy - 60), Offset(size.width, center.dy - 60), streetPaint);
    canvas.drawLine(Offset(0, center.dy + 70), Offset(size.width, center.dy + 70), streetPaint);
    canvas.drawLine(Offset(center.dx - 80, 0), Offset(center.dx - 80, size.height), streetPaint);
    canvas.drawLine(Offset(center.dx + 80, 0), Offset(center.dx + 80, size.height), streetPaint);

    // Street Corridor Labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    void drawStreetLabel(String text, Offset pos) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.2),
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, pos);
    }

    drawStreetLabel('CIVIC RESCUE CORRIDOR', Offset(16, center.dy - 74));
    drawStreetLabel('MISSION TRANSIT WAY', Offset(16, center.dy + 56));
    drawStreetLabel('8TH ST ROUTE', Offset(center.dx - 74, 16));

    // 3. Safe Evacuation Corridor Buffer (Glow band along polyline)
    if (route.polylinePoints.isNotEmpty) {
      final bufferPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final corridorPath = Path();
      final p0 = toCanvasPos(route.polylinePoints.first.latitude, route.polylinePoints.first.longitude);
      corridorPath.moveTo(p0.dx, p0.dy);
      for (int i = 1; i < route.polylinePoints.length; i++) {
        final pi = toCanvasPos(route.polylinePoints[i].latitude, route.polylinePoints[i].longitude);
        corridorPath.lineTo(pi.dx, pi.dy);
      }
      canvas.drawPath(corridorPath, bufferPaint);

      // Outer route glow
      final routeGlow = Paint()
        ..color = Colors.cyanAccent.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(corridorPath, routeGlow);

      // Core route line
      final routeLine = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(corridorPath, routeLine);

      // 4. Directional Chevrons along route segments
      final chevronPaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < route.polylinePoints.length - 1; i++) {
        final start = toCanvasPos(route.polylinePoints[i].latitude, route.polylinePoints[i].longitude);
        final end = toCanvasPos(route.polylinePoints[i + 1].latitude, route.polylinePoints[i + 1].longitude);

        final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
        final angle = atan2(end.dy - start.dy, end.dx - start.dx);

        const arrowLen = 6.0;
        final pA = mid - Offset(arrowLen * cos(angle - 0.5), arrowLen * sin(angle - 0.5));
        final pB = mid - Offset(arrowLen * cos(angle + 0.5), arrowLen * sin(angle + 0.5));

        canvas.drawLine(pA, mid, chevronPaint);
        canvas.drawLine(pB, mid, chevronPaint);
      }

      // 5. Waypoint Turn Indicators (Steps 1 to 4)
      final stepIndices = [0, 2, 4, route.polylinePoints.length - 1];
      for (int s = 0; s < stepIndices.length && s < route.instructions.length; s++) {
        final ptIdx = stepIndices[s].clamp(0, route.polylinePoints.length - 1);
        final pt = route.polylinePoints[ptIdx];
        final pos = toCanvasPos(pt.latitude, pt.longitude);
        final isStepActive = (s == activeStepIndex);

        if (isStepActive) {
          // Animated Pulse around active waypoint
          final activePulsePaint = Paint()
            ..color = Colors.cyanAccent.withOpacity((1.0 - pulseValue).clamp(0.0, 0.6))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          canvas.drawCircle(pos, 12 + (pulseValue * 10), activePulsePaint);
        }

        // Draw waypoint bubble
        final wpBgPaint = Paint()..color = isStepActive ? Colors.cyanAccent : const Color(0xFF1E293B);
        final wpBorderPaint = Paint()
          ..color = isStepActive ? Colors.white : Colors.cyanAccent.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        canvas.drawCircle(pos, 7, wpBgPaint);
        canvas.drawCircle(pos, 7, wpBorderPaint);

        // Step number text inside waypoint
        final numPainter = TextPainter(
          text: TextSpan(
            text: '${s + 1}',
            style: TextStyle(
              color: isStepActive ? Colors.black : Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        numPainter.layout();
        numPainter.paint(canvas, pos - Offset(numPainter.width / 2, numPainter.height / 2));
      }
    }

    // 6. User Origin Pin (YOU)
    final userPos = toCanvasPos(userLat, userLon);
    final userPulsePaint = Paint()
      ..color = Colors.greenAccent.withOpacity((0.4 * (1.0 - pulseValue * 0.5)).clamp(0.1, 0.4))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userPos, 16 + (pulseValue * 6), userPulsePaint);

    final userCorePaint = Paint()..color = Colors.greenAccent;
    canvas.drawCircle(userPos, 8, userCorePaint);
    final userWhitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(userPos, 3, userWhitePaint);

    // Draw "YOU" label
    final youPainter = TextPainter(
      text: const TextSpan(
        text: 'YOU (START)',
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0xFF0F172A),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    youPainter.layout();
    youPainter.paint(canvas, userPos + const Offset(-24, 12));

    // 7. Shelter Destination Pin
    final destPos = toCanvasPos(route.destLat, route.destLon);
    final destPulsePaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(destPos, 18, destPulsePaint);

    final destCorePaint = Paint()..color = const Color(0xFFFF3366);
    canvas.drawCircle(destPos, 9, destCorePaint);
    final destWhiteCross = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;
    canvas.drawLine(destPos + const Offset(-4, 0), destPos + const Offset(4, 0), destWhiteCross);
    canvas.drawLine(destPos + const Offset(0, -4), destPos + const Offset(0, 4), destWhiteCross);

    // Draw "SHELTER" badge
    final shelterPainter = TextPainter(
      text: TextSpan(
        text: route.destinationName.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0xFFDC2626),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    shelterPainter.layout();
    shelterPainter.paint(canvas, destPos + const Offset(-20, -22));
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) => true;
}
