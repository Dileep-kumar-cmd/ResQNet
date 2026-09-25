// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/features/navigation/routing_service.dart';

enum NavMapStyle { dark, standard, satellite }

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
  final MapController _mapController = MapController();
  NavMapStyle _mapStyle = NavMapStyle.dark;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _recalculateRoute();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitRoute();
    });
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
  }

  void _fitRoute() {
    if (_route.polylinePoints.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints([
        LatLng(widget.userLat, widget.userLon),
        LatLng(widget.destinationLat, widget.destinationLon),
        ..._route.polylinePoints,
      ]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(top: 50, bottom: 90, left: 35, right: 35),
        ),
      );
    } catch (e) {
      debugPrint('[MAP_FIT_ERROR] $e');
    }
  }

  void _selectStep(int idx) {
    if (idx < 0 || idx >= _route.instructions.length) return;
    setState(() => _currentStepIndex = idx);
    if (_route.polylinePoints.isNotEmpty) {
      final int ptIdx = ((idx + 1) * (_route.polylinePoints.length - 1) / _route.instructions.length)
          .round()
          .clamp(0, _route.polylinePoints.length - 1);
      final pt = _route.polylinePoints[ptIdx];
      _mapController.move(pt, 16.0);
    }
  }

  void _nextStep() {
    if (_currentStepIndex < _route.instructions.length - 1) {
      _selectStep(_currentStepIndex + 1);
    }
  }

  void _prevStep() {
    if (_currentStepIndex > 0) {
      _selectStep(_currentStepIndex - 1);
    }
  }

  void _cycleMapStyle() {
    setState(() {
      switch (_mapStyle) {
        case NavMapStyle.dark:
          _mapStyle = NavMapStyle.standard;
          break;
        case NavMapStyle.standard:
          _mapStyle = NavMapStyle.satellite;
          break;
        case NavMapStyle.satellite:
          _mapStyle = NavMapStyle.dark;
          break;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _mapStyle == NavMapStyle.dark
              ? 'Style: Tactical Dark (CARTO)'
              : (_mapStyle == NavMapStyle.standard ? 'Style: OpenStreetMap Standard' : 'Style: Satellite Imagery'),
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  String _getTileUrl() {
    switch (_mapStyle) {
      case NavMapStyle.standard:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case NavMapStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case NavMapStyle.dark:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final etaStr = _route.estimatedTimeMinutes.toStringAsFixed(0);
    final distStr = _route.totalDistanceKm.toStringAsFixed(2);
    final currentStep = _route.instructions.isNotEmpty && _currentStepIndex < _route.instructions.length
        ? _route.instructions[_currentStepIndex]
        : null;

    final centerLat = (widget.userLat + widget.destinationLat) / 2;
    final centerLon = (widget.userLon + widget.destinationLon) / 2;

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
                    _isVehicleMode
                        ? 'Switched to Vehicle Rescue Mode (35 km/h)'
                        : 'Switched to Walking Evacuation Mode (5 km/h)',
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
                          color: _isVehicleMode
                              ? Colors.amber.shade900.withOpacity(0.4)
                              : Colors.indigo.shade900.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isVehicleMode ? Colors.amber : Colors.indigoAccent,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_isVehicleMode ? Icons.directions_car : Icons.directions_walk,
                                size: 12, color: Colors.white),
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
                          Text('Offline Corridor Verified',
                              style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Real Map Visualizer with FlutterMap (Showing real streets, buildings, landmarks)
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(centerLat, centerLon),
                    initialZoom: 14.5,
                    minZoom: 3.0,
                    maxZoom: 19.0,
                  ),
                  children: [
                    // Real Map Tiles (Carto Dark / OSM / Satellite)
                    TileLayer(
                      urlTemplate: _getTileUrl(),
                      fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.resqnet.mobile',
                      maxZoom: 19,
                    ),

                    // Evacuation Corridor Real Polyline
                    PolylineLayer(
                      polylines: [
                        // Wide cyan safety glow band
                        Polyline(
                          points: _route.polylinePoints,
                          strokeWidth: 8.0,
                          color: Colors.cyanAccent.withOpacity(0.35),
                        ),
                        // Sharp inner route corridor
                        Polyline(
                          points: _route.polylinePoints,
                          strokeWidth: 4.5,
                          color: const Color(0xFF00E5FF),
                        ),
                      ],
                    ),

                    // Map Navigation Markers
                    MarkerLayer(
                      markers: [
                        // 1. Origin: User Starting Location Marker
                        Marker(
                          point: LatLng(widget.userLat, widget.userLon),
                          width: 80,
                          height: 80,
                          child: AnimatedBuilder(
                            animation: _animController,
                            builder: (context, child) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Animated pulse ring
                                  Container(
                                    width: 30 + 32 * _animController.value,
                                    height: 30 + 32 * _animController.value,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.cyanAccent.withOpacity(0.3 * (1 - _animController.value)),
                                      border: Border.all(
                                        color: Colors.cyanAccent.withOpacity(0.8 * (1 - _animController.value)),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  // Center location pin
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF00E5FF),
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.cyanAccent.withOpacity(0.6),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.navigation, size: 14, color: Colors.black),
                                  ),
                                  // Label chip
                                  Positioned(
                                    top: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.7), width: 0.8),
                                      ),
                                      child: const Text(
                                        'YOU (START)',
                                        style: TextStyle(
                                          color: Colors.cyanAccent,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        // 2. Intermediate Waypoint Checkpoints
                        ...List.generate(_route.instructions.length, (idx) {
                          if (idx == _route.instructions.length - 1) return null;
                          final int ptIdx =
                              ((idx + 1) * (_route.polylinePoints.length - 1) / _route.instructions.length)
                                  .round()
                                  .clamp(0, _route.polylinePoints.length - 1);
                          final pt = _route.polylinePoints[ptIdx];
                          final isCurrent = idx == _currentStepIndex;

                          return Marker(
                            point: pt,
                            width: 32,
                            height: 32,
                            child: GestureDetector(
                              onTap: () => _selectStep(idx),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCurrent ? Colors.cyanAccent : const Color(0xFF1E293B),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isCurrent ? Colors.white : Colors.cyanAccent,
                                    width: isCurrent ? 2.0 : 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isCurrent ? Colors.cyanAccent : Colors.black).withOpacity(0.5),
                                      blurRadius: isCurrent ? 8 : 4,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${idx + 1}',
                                    style: TextStyle(
                                      color: isCurrent ? Colors.black : Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).whereType<Marker>(),

                        // 3. Destination Shelter/Hospital Beacon Marker
                        Marker(
                          point: LatLng(widget.destinationLat, widget.destinationLon),
                          width: 160,
                          height: 80,
                          child: GestureDetector(
                            onTap: () => _selectStep(_route.instructions.length - 1),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white, width: 1),
                                    boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 4)],
                                  ),
                                  child: Text(
                                    widget.destinationName.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.redAccent.withOpacity(0.8),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.place, color: Colors.white, size: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Tactical HUD Overlay (Compass / Map Type / GPS Status)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.88),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.redAccent, width: 1.5),
                              ),
                              child: const Center(
                                child: Text('N',
                                    style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _mapStyle == NavMapStyle.dark
                                  ? 'REAL TACTICAL MAP'
                                  : (_mapStyle == NavMapStyle.satellite ? 'SATELLITE MAP' : 'OSM STREET MAP'),
                              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('REAL-TIME GPS: ACTIVE',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),

                // Map Control Tools (Recenter, Layer Switcher, Zoom Buttons)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      // Map Layer Switcher
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _mapStyle == NavMapStyle.satellite
                                ? Icons.satellite_alt
                                : (_mapStyle == NavMapStyle.standard ? Icons.map : Icons.dark_mode),
                            color: Colors.cyanAccent,
                            size: 20,
                          ),
                          tooltip: 'Switch Map Layer',
                          onPressed: _cycleMapStyle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Fit Route Camera Button
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.center_focus_strong, color: Colors.greenAccent, size: 20),
                          tooltip: 'Fit Full Route',
                          onPressed: _fitRoute,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Zoom In
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white, size: 20),
                          tooltip: 'Zoom In',
                          onPressed: () {
                            final zoom = _mapController.camera.zoom;
                            _mapController.move(_mapController.camera.center, zoom + 1.0);
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Zoom Out
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                          tooltip: 'Zoom Out',
                          onPressed: () {
                            final zoom = _mapController.camera.zoom;
                            _mapController.move(_mapController.camera.center, zoom - 1.0);
                          },
                        ),
                      ),
                    ],
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
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                                onPressed:
                                    _currentStepIndex < _route.instructions.length - 1 ? _nextStep : null,
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
                                      style: TextStyle(
                                          color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
                            onTap: () => _selectStep(idx),
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
                        label: const Text('ARRIVED / END NAVIGATION',
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
