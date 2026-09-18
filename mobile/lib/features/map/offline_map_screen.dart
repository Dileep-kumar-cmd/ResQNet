import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mobile/data/local/database_helper.dart';
import 'package:mobile/features/navigation/navigation_screen.dart';
import 'package:mobile/features/home/global_connectivity_banner.dart';

enum MapViewMode { vector, satellite, topographic }

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  static const MethodChannel _methodChannel = MethodChannel('com.resqnet.mobile/vector_map_channel');
  static const EventChannel _eventChannel = EventChannel('com.resqnet.mobile/vector_map_events');

  StreamSubscription? _eventSubscription;

  List<Map<String, dynamic>> _shelters = [];
  List<Map<String, dynamic>> _medicalInfra = [];
  bool _isLoading = true;

  MapViewMode _viewMode = MapViewMode.vector;
  Map<String, dynamic>? _selectedMarker;
  double? _userLat;
  double? _userLon;

  // Offline status
  String _offlineStatus = 'No Offline Map Available';
  int _downloadProgress = 0;
  bool _isDownloading = false;

  // Legend & Controls
  bool _isLegendExpanded = true;
  bool _isRadiusVisible = false;
  double _radiusKm = 5.0;
  double _currentZoom = 12.0;

  // Region fallback: centroid or configured region
  double _centerLat = 37.7749;
  double _centerLon = -122.4194;

  bool _isNativeMapReady = false;

  @override
  void initState() {
    super.initState();
    _loadLocalMapData();
    if (kIsWeb) {
      _offlineStatus = 'Offline Web Map Ready';
    } else {
      _subscribeToMapEvents();
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToMapEvents() {
    if (kIsWeb) return;
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final String eventType = event['eventType'] ?? '';
        switch (eventType) {
          case 'mapLoaded':
            setState(() => _isNativeMapReady = true);
            _sendFeaturesToNative();
            _checkOfflineRegions();
            break;
          case 'locationUpdate':
            setState(() {
              _userLat = (event['latitude'] as num).toDouble();
              _userLon = (event['longitude'] as num).toDouble();
            });
            break;
          case 'markerSelected':
            setState(() {
              if (event.containsKey('id') && event['id'] != null && event['id'].toString().isNotEmpty) {
                _selectedMarker = Map<String, dynamic>.from(event);
              } else {
                _selectedMarker = null;
              }
            });
            if (_selectedMarker != null) {
              _showMarkerBottomSheet(_selectedMarker!);
            }
            break;
          case 'offlineDownloadProgress':
            setState(() {
              _downloadProgress = (event['percentage'] as num).toInt();
              _isDownloading = true;
              _offlineStatus = 'Downloading Map: $_downloadProgress%';
            });
            break;
          case 'offlineMapReady':
            setState(() {
              _isDownloading = false;
              _offlineStatus = 'Offline Map Ready';
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Offline map region "${event['regionName']}" downloaded successfully!'),
                  backgroundColor: Colors.green.shade800,
                ),
              );
            }
            break;
          case 'downloadFailure':
            setState(() {
              _isDownloading = false;
              _offlineStatus = 'No Offline Map Available';
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Offline download failed: ${event['error']}'),
                  backgroundColor: Colors.red.shade800,
                ),
              );
            }
            break;

          case 'mapError':
            debugPrint('Map Error: ${event['message']}');
            break;
        }
      }
    });
  }

  Future<void> _loadLocalMapData() async {
    try {
      if (kIsWeb) {
        setState(() {
          _shelters = [
            {
              'id': 'sh_01',
              'name': 'SF Central High Shelter',
              'latitude': 37.7749,
              'longitude': -122.4194,
              'capacity': 250,
              'current_occupancy': 120,
              'type_category': 'SHELTER',
              'hazard_rating': 1,
            },
            {
              'id': 'sh_02',
              'name': 'Presidio Relief Hub',
              'latitude': 37.7950,
              'longitude': -122.4650,
              'capacity': 180,
              'current_occupancy': 45,
              'type_category': 'SHELTER',
              'hazard_rating': 0,
            },
          ];
          _medicalInfra = [
            {
              'id': 'med_01',
              'name': 'UCSF Emergency Medical Center',
              'latitude': 37.7630,
              'longitude': -122.4580,
              'capacity': 100,
              'type': 'Level-1 Trauma Center',
              'type_category': 'HOSPITAL',
            },
            {
              'id': 'med_02',
              'name': 'San Francisco General Hospital',
              'latitude': 37.7550,
              'longitude': -122.4050,
              'capacity': 150,
              'type': 'Urgent Care & Surgery',
              'type_category': 'HOSPITAL',
            },
          ];
          _isLoading = false;
        });
        return;
      }

      final db = await DatabaseHelper.instance.database;
      final shelters = await db.query('shelters');
      final medical = await db.query('medical_infra');

      // Calculate centroid of shelters as initial center fallback if no GPS
      if (shelters.isNotEmpty) {
        double sumLat = 0.0;
        double sumLon = 0.0;
        for (final s in shelters) {
          sumLat += (s['latitude'] as num).toDouble();
          sumLon += (s['longitude'] as num).toDouble();
        }
        _centerLat = sumLat / shelters.length;
        _centerLon = sumLon / shelters.length;
      }

      setState(() {
        _shelters = shelters;
        _medicalInfra = medical;
        _isLoading = false;
      });

      _sendFeaturesToNative();
    } catch (e) {
      debugPrint('Error loading map database features: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendFeaturesToNative() async {
    if (kIsWeb || !_isNativeMapReady) return;
    try {
      await _methodChannel.invokeMethod('setFeaturesData', {
        'sheltersJson': jsonEncode(_shelters),
        'hospitalsJson': jsonEncode(_medicalInfra),
      });
    } catch (e) {
      debugPrint('Error sending features data to native MapLibre: $e');
    }
  }

  Future<void> _checkOfflineRegions() async {
    if (kIsWeb || !_isNativeMapReady) return;
    try {
      final List<dynamic>? regions = await _methodChannel.invokeListMethod('listOfflineRegions');
      setState(() {
        if (regions != null && regions.isNotEmpty) {
          _offlineStatus = 'Offline Map Ready';
        } else {
          _offlineStatus = 'No Offline Map Available';
        }
      });
    } catch (e) {
      debugPrint('Error checking offline regions: $e');
    }
  }

  Future<void> _locateUser() async {
    if (kIsWeb) {
      setState(() {
        _userLat = _centerLat;
        _userLon = _centerLon;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Web User Location set to emergency centroid coordinates.'),
            backgroundColor: Colors.indigo,
          ),
        );
      }
      return;
    }

    try {
      await _methodChannel.invokeMethod('locateUser');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Requesting location permission... Please grant location access when prompted by Android.'),
            backgroundColor: Colors.indigo,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _setZoom(double zoomDelta) async {
    final newZoom = (_currentZoom + zoomDelta).clamp(5.0, 18.0);
    setState(() => _currentZoom = newZoom);
    if (!kIsWeb && _isNativeMapReady) {
      try {
        await _methodChannel.invokeMethod('setZoom', {'zoom': newZoom});
      } catch (e) {
        debugPrint('Error setting zoom: $e');
      }
    }
  }

  Future<void> _toggleEmergencyRadius(bool visible) async {
    setState(() => _isRadiusVisible = visible);
    if (!kIsWeb && _isNativeMapReady) {
      try {
        await _methodChannel.invokeMethod('setEmergencyRadius', {
          'latitude': _userLat ?? _centerLat,
          'longitude': _userLon ?? _centerLon,
          'radiusKm': _radiusKm,
          'visible': visible,
        });
      } catch (e) {
        debugPrint('Error setting emergency radius: $e');
      }
    }
  }

  Future<void> _updateRadiusKm(double val) async {
    setState(() => _radiusKm = val);
    if (_isRadiusVisible) {
      await _toggleEmergencyRadius(true);
    }
  }

  void _handleModeSwitch(MapViewMode mode) async {
    setState(() => _viewMode = mode);
    if (!kIsWeb) {
      try {
        final String styleKey = mode == MapViewMode.satellite
            ? 'satellite'
            : (mode == MapViewMode.topographic ? 'relief' : 'vector');
        await _methodChannel.invokeMethod('setMapStyle', {'style': styleKey});
      } catch (e) {
        debugPrint('Error invoking setMapStyle native method: $e');
      }
    }
  }

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  void _showMarkerBottomSheet(Map<String, dynamic> marker) {
    final bool isShelter = marker['type_category'] == 'SHELTER';
    final double lat = double.tryParse(marker['latitude']?.toString() ?? '0') ?? 0.0;
    final double lon = double.tryParse(marker['longitude']?.toString() ?? '0') ?? 0.0;

    final String distanceStr = (_userLat != null && _userLon != null)
        ? '${_calculateDistanceKm(_userLat!, _userLon!, lat, lon).toStringAsFixed(2)} km away'
        : 'Distance unknown';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isShelter ? Colors.blue.shade900 : Colors.red.shade900,
                    child: Icon(
                      isShelter ? Icons.night_shelter : Icons.local_hospital,
                      color: isShelter ? Colors.blueAccent : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          marker['name'] ?? (isShelter ? 'Shelter' : 'Hospital'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isShelter ? 'Emergency Shelter' : (marker['type'] ?? 'Trauma Center'),
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Colors.blueAccent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)} ($distanceStr)',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isShelter) ...[
                Row(
                  children: [
                    const Icon(Icons.people_outline, color: Colors.amberAccent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Occupancy: ${marker['current_occupancy'] ?? 0} / ${marker['capacity'] ?? 100} beds',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Hazard Level: ${marker['hazard_rating'] ?? 0}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    const Icon(Icons.local_hospital_outlined, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Bed Capacity: ${marker['capacity'] ?? 50} beds',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    final String destName = marker['name'] ?? (isShelter ? 'Shelter' : 'Hospital');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NavigationScreen(
                          destinationName: destName,
                          destinationLat: lat,
                          destinationLon: lon,
                          userLat: _userLat ?? _centerLat,
                          userLon: _userLon ?? _centerLon,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('START TURN-BY-TURN NAVIGATION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOfflineManagerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Offline Map Region Manager', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: $_offlineStatus',
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can download current local map bounds for offline disaster response usage.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (_isDownloading)
                LinearProgressIndicator(value: _downloadProgress / 100.0, backgroundColor: Colors.white12),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton.icon(
              onPressed: _isDownloading
                  ? null
                  : () {
                      Navigator.pop(context);
                      if (!kIsWeb) {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() {
                          _isDownloading = true;
                          _downloadProgress = 0;
                          _offlineStatus = 'Downloading Map: 0%';
                        });
                        _methodChannel.invokeMethod('startOfflineDownload', {
                          'minLat': _centerLat - 0.05,
                          'minLon': _centerLon - 0.05,
                          'maxLat': _centerLat + 0.05,
                          'maxLon': _centerLon + 0.05,
                          'regionName': 'Disaster Response Zone',
                        }).catchError((err) {
                          if (mounted) {
                            setState(() {
                              _isDownloading = false;
                              _offlineStatus = 'No Offline Map Available';
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Download failed: $err'),
                                backgroundColor: Colors.red.shade800,
                              ),
                            );
                          }
                        });
                      }
                    },
              icon: const Icon(Icons.download),
              label: const Text('DOWNLOAD REGION'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vector Geographical Map'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Offline Map Manager',
            onPressed: _showOfflineManagerDialog,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _setZoom(1.0),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _setZoom(-1.0),
          ),
        ],
      ),
      body: Column(
        children: [
          const GlobalConnectivityBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
              children: [
                // Render Web Vector Map View on Web, or Native MapLibre on Android
                if (kIsWeb)
                  WebVectorMapView(
                    shelters: _shelters,
                    medicalInfra: _medicalInfra,
                    centerLat: _userLat ?? _centerLat,
                    centerLon: _userLon ?? _centerLon,
                    zoomLevel: _currentZoom,
                    isRadiusVisible: _isRadiusVisible,
                    radiusKm: _radiusKm,
                    selectedMarker: _selectedMarker,
                    onMarkerTap: (marker) {
                      setState(() => _selectedMarker = marker);
                      _showMarkerBottomSheet(marker);
                    },
                  )
                else
                  // Real MapLibre Native PlatformView with Hybrid Composition
                  PlatformViewLink(
                    viewType: 'com.resqnet.mobile/vector_map',
                    surfaceFactory: (context, controller) {
                      return AndroidViewSurface(
                        controller: controller as AndroidViewController,
                        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
                        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                      );
                    },
                    onCreatePlatformView: (params) {
                      return PlatformViewsService.initExpensiveAndroidView(
                        id: params.id,
                        viewType: 'com.resqnet.mobile/vector_map',
                        layoutDirection: TextDirection.ltr,
                        creationParams: {
                          'sheltersJson': jsonEncode(_shelters),
                          'hospitalsJson': jsonEncode(_medicalInfra),
                          'initialLat': _userLat ?? _centerLat,
                          'initialLon': _userLon ?? _centerLon,
                          'initialZoom': _currentZoom,
                        },
                        creationParamsCodec: const StandardMessageCodec(),
                        onFocus: () {
                          params.onPlatformViewCreated(params.id);
                        },
                      )
                        ..addOnPlatformViewCreatedListener((id) {
                          params.onPlatformViewCreated(id);
                          if (mounted) {
                            setState(() => _isNativeMapReady = true);
                            _sendFeaturesToNative();
                            _checkOfflineRegions();
                          }
                        })
                        ..create();
                    },
                  ),

                // Offline Download Progress Indicator Banner
                if (_isDownloading)
                  Positioned(
                    top: 56,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xF00F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.cyanAccent.shade700),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Downloading Offline Map Tiles ($_downloadProgress%)',
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _downloadProgress / 100.0,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Offline Status Indicator Badge (Tappable to manage/download)
                Positioned(
                  top: 16,
                  left: 16,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showOfflineManagerDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xEE0F172A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _offlineStatus.contains('Ready') ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _offlineStatus.contains('Ready') ? Icons.offline_pin : Icons.download_for_offline_outlined,
                            color: _offlineStatus.contains('Ready') ? Colors.greenAccent : Colors.orangeAccent,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _offlineStatus,
                            style: TextStyle(
                              color: _offlineStatus.contains('Ready') ? Colors.greenAccent : Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!_offlineStatus.contains('Ready')) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.touch_app, color: Colors.orangeAccent, size: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Top Right Mode Switcher
                Positioned(
                  top: 56,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xEE0F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.indigo.shade400),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeButton('Vector', MapViewMode.vector),
                        _buildModeButton('Satellite', MapViewMode.satellite),
                        _buildModeButton('Relief', MapViewMode.topographic),
                      ],
                    ),
                  ),
                ),

                // Collapsible Map Legend
                Positioned(
                  bottom: 90,
                  left: 16,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xEE0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.shade400),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _isLegendExpanded = !_isLegendExpanded),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.map, color: Colors.indigoAccent, size: 16),
                              const SizedBox(width: 6),
                              const Text(
                                'MAP LEGEND',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _isLegendExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                color: Colors.white70,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        if (_isLegendExpanded) ...[
                          const SizedBox(height: 8),
                          _buildLegendRow(Colors.blueAccent, 'Shelters (Tap for details)'),
                          const SizedBox(height: 4),
                          _buildLegendRow(Colors.redAccent, 'Hospitals & Trauma Centers'),
                          const SizedBox(height: 4),
                          _buildLegendRow(const Color(0xFF10B981), 'User GPS Location', isCircle: true),
                        ],
                      ],
                    ),
                  ),
                ),

                // Emergency Coverage Radius Control Overlay
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 80,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xEE0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.shade400),
                    ),
                    child: Row(
                      children: [
                        Switch(
                          value: _isRadiusVisible,
                          onChanged: _toggleEmergencyRadius,
                          activeTrackColor: Colors.blueAccent,
                        ),
                        Text(
                          'Radius: ${_radiusKm.toStringAsFixed(1)} km',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Slider(
                            value: _radiusKm,
                            min: 1.0,
                            max: 20.0,
                            divisions: 19,
                            activeColor: Colors.blueAccent,
                            onChanged: _isRadiusVisible ? _updateRadiusKm : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating "Locate Me" Button
                Positioned(
                  bottom: 20,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'locate_me_fab',
                    onPressed: _locateUser,
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String title, MapViewMode mode) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleModeSwitch(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo.shade600 : const Color(0x01FFFFFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label, {bool isCircle = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class WebVectorMapView extends StatelessWidget {
  final List<Map<String, dynamic>> shelters;
  final List<Map<String, dynamic>> medicalInfra;
  final double centerLat;
  final double centerLon;
  final double zoomLevel;
  final bool isRadiusVisible;
  final double radiusKm;
  final Map<String, dynamic>? selectedMarker;
  final Function(Map<String, dynamic>) onMarkerTap;

  const WebVectorMapView({
    super.key,
    required this.shelters,
    required this.medicalInfra,
    required this.centerLat,
    required this.centerLon,
    required this.zoomLevel,
    required this.isRadiusVisible,
    required this.radiusKm,
    required this.selectedMarker,
    required this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Container(
          width: size.width,
          height: size.height,
          color: const Color(0xFF0F172A),
          child: CustomPaint(
            size: size,
            painter: WebMapPainter(
              shelters: shelters,
              medicalInfra: medicalInfra,
              centerLat: centerLat,
              centerLon: centerLon,
              zoomLevel: zoomLevel,
              isRadiusVisible: isRadiusVisible,
              radiusKm: radiusKm,
              selectedMarker: selectedMarker,
            ),
          ),
        );
      },
    );
  }
}

class WebMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> shelters;
  final List<Map<String, dynamic>> medicalInfra;
  final double centerLat;
  final double centerLon;
  final double zoomLevel;
  final bool isRadiusVisible;
  final double radiusKm;
  final Map<String, dynamic>? selectedMarker;

  WebMapPainter({
    required this.shelters,
    required this.medicalInfra,
    required this.centerLat,
    required this.centerLon,
    required this.zoomLevel,
    required this.isRadiusVisible,
    required this.radiusKm,
    required this.selectedMarker,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    Offset toCanvasPos(double lat, double lon) {
      final dx = (lon - centerLon) * (100 * zoomLevel);
      final dy = -(lat - centerLat) * (100 * zoomLevel);
      return center + Offset(dx, dy);
    }

    // 1. Water Body (SF Bay)
    final waterPaint = Paint()..color = const Color(0xFF0F2035);
    final bayPath = Path()
      ..moveTo(toCanvasPos(37.8100, -122.3900).dx, toCanvasPos(37.8100, -122.3900).dy)
      ..lineTo(toCanvasPos(37.8200, -122.3600).dx, toCanvasPos(37.8200, -122.3600).dy)
      ..lineTo(toCanvasPos(37.7600, -122.3700).dx, toCanvasPos(37.7600, -122.3700).dy)
      ..close();
    canvas.drawPath(bayPath, waterPaint);

    // 2. Parks
    final parkPaint = Paint()..color = const Color(0xFF143525);
    final parkRect = Rect.fromPoints(
      toCanvasPos(37.7730, -122.5100),
      toCanvasPos(37.7650, -122.4500),
    );
    canvas.drawRect(parkRect, parkPaint);

    // 3. Highways
    final highwayPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    final us101 = Path()
      ..moveTo(toCanvasPos(37.7400, -122.4050).dx, toCanvasPos(37.7400, -122.4050).dy)
      ..lineTo(toCanvasPos(37.7749, -122.4194).dx, toCanvasPos(37.7749, -122.4194).dy)
      ..lineTo(toCanvasPos(37.8000, -122.4350).dx, toCanvasPos(37.8000, -122.4350).dy);
    canvas.drawPath(us101, highwayPaint);

    // 4. Emergency Radius Circle
    if (isRadiusVisible) {
      final radPaint = Paint()..color = const Color(0x333B82F6);
      final radBorder = Paint()
        ..color = const Color(0xFF60A5FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final radPx = radiusKm * 10 * zoomLevel;
      canvas.drawCircle(center, radPx, radPaint);
      canvas.drawCircle(center, radPx, radBorder);
    }

    // 5. Shelters (Blue)
    final shelterPaint = Paint()..color = const Color(0xFF3B82F6);
    final shelterBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final s in shelters) {
      final lat = (s['latitude'] as num).toDouble();
      final lon = (s['longitude'] as num).toDouble();
      final pos = toCanvasPos(lat, lon);
      canvas.drawCircle(pos, 12, shelterPaint);
      canvas.drawCircle(pos, 12, shelterBorder);
    }

    // 6. Medical Infra (Red)
    final medPaint = Paint()..color = const Color(0xFFEF4444);
    final medBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final m in medicalInfra) {
      final lat = (m['latitude'] as num).toDouble();
      final lon = (m['longitude'] as num).toDouble();
      final pos = toCanvasPos(lat, lon);
      canvas.drawCircle(pos, 12, medPaint);
      canvas.drawCircle(pos, 12, medBorder);
    }

    // 7. User Location Dot
    final userPulse = Paint()..color = const Color(0x4D10B981);
    final userDot = Paint()..color = const Color(0xFF10B981);
    final userBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 20, userPulse);
    canvas.drawCircle(center, 9, userDot);
    canvas.drawCircle(center, 9, userBorder);
  }

  @override
  bool shouldRepaint(covariant WebMapPainter oldDelegate) => true;
}
