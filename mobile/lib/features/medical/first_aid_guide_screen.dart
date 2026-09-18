import 'package:flutter/material.dart';
import 'package:mobile/features/medical/first_aid_data.dart';
import 'package:mobile/features/home/global_connectivity_banner.dart';

class FirstAidGuideScreen extends StatefulWidget {
  const FirstAidGuideScreen({super.key});

  @override
  State<FirstAidGuideScreen> createState() => _FirstAidGuideScreenState();
}

class _FirstAidGuideScreenState extends State<FirstAidGuideScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'ALL';
  List<FirstAidProtocol> _filteredProtocols = [];

  @override
  void initState() {
    super.initState();
    _filteredProtocols = FirstAidData.protocols;
    _searchCtrl.addListener(_filterProtocols);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterProtocols() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredProtocols = FirstAidData.protocols.where((p) {
        final matchesCat = _selectedCategory == 'ALL' || p.category == _selectedCategory;
        final matchesQuery = query.isEmpty ||
            p.title.toLowerCase().contains(query) ||
            p.overview.toLowerCase().contains(query) ||
            p.steps.any((s) => s.toLowerCase().contains(query)) ||
            p.category.toLowerCase().contains(query);
        return matchesCat && matchesQuery;
      }).toList();
    });
  }

  void _showProtocolDetail(FirstAidProtocol p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          maxChildSize: 0.96,
          builder: (context, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.urgency == 'CRITICAL'
                              ? Colors.red.shade100
                              : (p.urgency == 'HIGH' ? Colors.orange.shade100 : Colors.amber.shade100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          p.urgency,
                          style: TextStyle(
                            color: p.urgency == 'CRITICAL'
                                ? Colors.red.shade900
                                : (p.urgency == 'HIGH' ? Colors.orange.shade900 : Colors.amber.shade900),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          p.category.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.indigo.shade50,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.overview,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.3),
                  ),
                  const SizedBox(height: 16),

                  // Equipment Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.medical_services, color: Colors.indigo, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Equipment Needed: ${p.equipmentNeeded}',
                            style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Warnings Box
                  if (p.warnings.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                              SizedBox(width: 6),
                              Text('CRITICAL WARNINGS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...p.warnings.map((w) => Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text('• $w', style: TextStyle(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.w500)),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // What NOT To Do Box
                  if (p.whatNotToDo.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.do_not_disturb_on, color: Colors.amber.shade900, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'WHAT NOT TO DO',
                                style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...p.whatNotToDo.map((w) => Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text('• $w', style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold)),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'STEP-BY-STEP PROCEDURE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),

                  ...p.steps.asMap().entries.map((entry) {
                    final int idx = entry.key + 1;
                    final String stepText = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: Colors.indigo.shade900,
                            child: Text('$idx', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              stepText,
                              style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check),
                      label: const Text('DONE / CLOSE GUIDE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade900,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const categories = [
      'ALL',
      'INJURIES',
      'BURNS',
      'BREATHING',
      'CARDIAC',
      'NEUROLOGICAL',
      'BONE_MUSCLE',
      'BITES_STINGS',
      'ENVIRONMENTAL',
      'POISONING'
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Emergency First-Aid Library'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const GlobalConnectivityBanner(),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search 25+ protocols (e.g. CPR, bleeding, snake, asthma)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),

          // Category Chips Horizontal Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                final labelText = cat.replaceAll('_', ' ');
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: FilterChip(
                    label: Text(
                      labelText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.indigo.shade900,
                    onSelected: (val) {
                      setState(() {
                        _selectedCategory = cat;
                        _filterProtocols();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Protocol List
          Expanded(
            child: _filteredProtocols.isEmpty
                ? const Center(child: Text('No protocols match your search query.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: _filteredProtocols.length,
                    itemBuilder: (context, idx) {
                      final p = _filteredProtocols[idx];
                      final bool isCritical = p.urgency == 'CRITICAL';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 1.5,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCritical ? Colors.red.shade100 : Colors.indigo.shade100,
                            child: Icon(
                              isCritical ? Icons.medical_services : Icons.health_and_safety,
                              color: isCritical ? Colors.red : Colors.indigo,
                            ),
                          ),
                          title: Text(
                            p.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.overview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Category: ${p.category.replaceAll('_', ' ')}',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showProtocolDetail(p),
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
