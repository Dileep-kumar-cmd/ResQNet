import 'package:flutter/material.dart';
import 'package:mobile/features/ai/shelter_ml_recommender.dart';
import 'package:mobile/features/ai/resource_shortage_predictor.dart';

class AIDashboardScreen extends StatefulWidget {
  const AIDashboardScreen({super.key});

  @override
  State<AIDashboardScreen> createState() => _AIDashboardScreenState();
}

class _AIDashboardScreenState extends State<AIDashboardScreen> {
  final double _userLat = 37.7749;
  final double _userLon = -122.4194;

  List<MLShelterRecommendation> _mlRecommendations = [];
  List<ResourceShortageForecast> _shortageForecasts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _runAiInference();
  }

  Future<void> _runAiInference() async {
    setState(() => _isLoading = true);

    final recs = await ShelterMLRecommender.instance.getMLRecommendations(
      userLat: _userLat,
      userLon: _userLon,
    );

    final forecasts = await ResourceShortagePredictor.instance.predictShortages();

    setState(() {
      _mlRecommendations = recs;
      _shortageForecasts = forecasts;
      _isLoading = false;
    });
  }

  void _showFeatureContributions(MLShelterRecommendation rec) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.purpleAccent, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Chip(
                    label: Text('${rec.mlMatchConfidence}% ML Match', style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.purple.shade200,
                  )
                ],
              ),
              const SizedBox(height: 16),
              const Text('TFLITE FEATURE WEIGHT ATTRIBUTION', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24),

              ...rec.featureContributions.entries.map((e) {
                final String featName = e.key;
                final double contrib = e.value;
                final bool isPositive = contrib >= 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(featName, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      Text(
                        '${isPositive ? '+' : ''}${contrib.toStringAsFixed(3)}',
                        style: TextStyle(
                          color: isPositive ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('On-Device AI Intelligence'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            onPressed: _runAiInference,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // On-Device ML Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade900, Colors.indigo.shade900],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.memory, color: Colors.purpleAccent, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TFLite Quantized Neural Engine',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'Latency: ${_mlRecommendations.isNotEmpty ? _mlRecommendations.first.inferenceLatencyMs : 4} ms | 0 Server Round-Trips',
                                style: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 1: AI Optimal Shelter Recommendations
                  Text(
                    'ML-Recommended Optimal Shelters',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _mlRecommendations.length,
                    itemBuilder: (context, idx) {
                      final rec = _mlRecommendations[idx];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.purple.shade100,
                                    child: const Icon(Icons.auto_awesome, color: Colors.purple),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(rec.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text(
                                          '${rec.distanceKm} km away | ${rec.availableCapacity} beds available',
                                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Chip(
                                    label: Text('${rec.mlMatchConfidence}% Match', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    backgroundColor: Colors.purple.shade100,
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _showFeatureContributions(rec),
                                  icon: const Icon(Icons.analytics, size: 16),
                                  label: const Text('View Neural Feature Weights'),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Section 2: Resource Shortage Predictor
                  Text(
                    'Resource Shortage & Depletion Predictor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _shortageForecasts.length,
                    itemBuilder: (context, idx) {
                      final f = _shortageForecasts[idx];
                      final isCritical = f.overallRiskLevel == ShortageRiskLevel.critical;
                      final isWarning = f.overallRiskLevel == ShortageRiskLevel.warning;

                      return Card(
                        color: isCritical ? Colors.red.shade50 : (isWarning ? Colors.amber.shade50 : Colors.white),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isCritical ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                                    color: isCritical ? Colors.red : Colors.indigo,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(f.shelterName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ),
                                  Chip(
                                    label: Text(
                                      isCritical ? 'CRITICAL SHORTAGE' : (isWarning ? 'WARNING' : 'ADEQUATE'),
                                      style: TextStyle(
                                        color: isCritical ? Colors.red.shade900 : (isWarning ? Colors.amber.shade900 : Colors.green.shade900),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                    backgroundColor: isCritical ? Colors.red.shade100 : (isWarning ? Colors.amber.shade100 : Colors.green.shade100),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSupplyStat('Water', '${f.waterHoursRemaining} hrs', Colors.blue),
                                  _buildSupplyStat('Food', '${f.foodHoursRemaining} hrs', Colors.orange),
                                  _buildSupplyStat('Medical', '${f.medicalHoursRemaining} hrs', Colors.red),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSupplyStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
