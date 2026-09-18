import 'package:flutter/material.dart';
import 'package:mobile/features/shelters/shelter_ranking_service.dart';
import 'package:mobile/features/navigation/navigation_screen.dart';
import 'package:mobile/features/home/global_connectivity_banner.dart';

class ShelterFinderScreen extends StatefulWidget {
  const ShelterFinderScreen({super.key});

  @override
  State<ShelterFinderScreen> createState() => _ShelterFinderScreenState();
}

class _ShelterFinderScreenState extends State<ShelterFinderScreen> {
  final double _userLat = 37.7749;
  final double _userLon = -122.4194;

  List<RankedShelter> _rankedShelters = [];
  bool _isLoading = true;
  int _executionMs = 0;
  bool _filterHasSpaceOnly = false;

  @override
  void initState() {
    super.initState();
    _computeRankings();
  }

  Future<void> _computeRankings() async {
    final stopwatch = Stopwatch()..start();
    setState(() => _isLoading = true);

    final results = await ShelterRankingService.instance.rankShelters(
      userLat: _userLat,
      userLon: _userLon,
    );

    stopwatch.stop();

    setState(() {
      _rankedShelters = results;
      _executionMs = stopwatch.elapsedMilliseconds;
      _isLoading = false;
    });
  }

  void _navigateToShelter(RankedShelter s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          destinationName: s.name,
          destinationLat: s.latitude,
          destinationLon: s.longitude,
          userLat: _userLat,
          userLon: _userLon,
        ),
      ),
    );
  }

  void _showScoreBreakdown(RankedShelter s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars, color: Colors.amber, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${s.compositeScore} / 100', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    backgroundColor: Colors.amber.shade200,
                  )
                ],
              ),
              const SizedBox(height: 16),
              const Text('MULTI-CRITERIA MATCH BREAKDOWN', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24),
              _buildScoreRow('Spatial Proximity (40% Weight)', '${s.distanceKm.toStringAsFixed(2)} km away', s.proximitySubScore, Colors.blue),
              _buildScoreRow('Capacity Margin (35% Weight)', '${s.availableCapacity} beds open', s.capacitySubScore, Colors.green),
              _buildScoreRow('Hazard Zone Safety (25% Weight)', 'Level ${s.hazardRating} hazard rating', s.hazardSubScore, Colors.orange),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToShelter(s);
                  },
                  icon: const Icon(Icons.navigation),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('START TURN-BY-TURN NAVIGATION', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildScoreRow(String label, String detail, double score, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${score.toStringAsFixed(1)} pts', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          Text(detail, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (score / 100.0).clamp(0.0, 1.0),
            color: color,
            backgroundColor: Colors.white10,
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterHasSpaceOnly
        ? _rankedShelters.where((s) => s.availableCapacity > 0).toList()
        : _rankedShelters;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intelligent Shelter Finder'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _computeRankings,
          )
        ],
      ),
      body: Column(
        children: [
          const GlobalConnectivityBanner(),

          // Algorithm Performance Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.indigo.shade50,
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.indigo, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Multi-Criteria Ranking ($_executionMs ms)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Has Space', style: TextStyle(fontSize: 11)),
                  selected: _filterHasSpaceOnly,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  onSelected: (val) => setState(() => _filterHasSpaceOnly = val),
                ),
              ],
            ),
          ),

          // Ranked Shelter List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('No shelters match current filter.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final s = filtered[idx];
                          final int rankNum = idx + 1;
                          final double occPercent = (s.currentOccupancy / s.capacity).clamp(0.0, 1.0);

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 15,
                                        backgroundColor: rankNum == 1 ? Colors.amber : Colors.indigo.shade100,
                                        child: Text(
                                          '#$rankNum',
                                          style: TextStyle(
                                            color: rankNum == 1 ? Colors.black : Colors.indigo,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Dist: ${s.distanceKm.toStringAsFixed(2)} km | Hazard Lvl ${s.hazardRating}',
                                              style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.green.shade300),
                                        ),
                                        child: Text(
                                          '${s.compositeScore} Match',
                                          style: TextStyle(
                                            color: Colors.green.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Capacity Progress Bar
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Beds: ${s.availableCapacity} open (${s.currentOccupancy}/${s.capacity})',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${(occPercent * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: occPercent > 0.9 ? Colors.red : Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: occPercent,
                                      minHeight: 8,
                                      color: occPercent > 0.9 ? Colors.red : Colors.green,
                                      backgroundColor: Colors.grey.shade200,
                                    ),
                                  ),

                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _showScoreBreakdown(s),
                                        icon: const Icon(Icons.analytics_outlined, size: 15),
                                        label: const Text('Breakdown', style: TextStyle(fontSize: 12)),
                                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _navigateToShelter(s),
                                        icon: const Icon(Icons.navigation, size: 15),
                                        label: const Text('NAVIGATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.indigo.shade900,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
