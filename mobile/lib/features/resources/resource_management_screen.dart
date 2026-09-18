import 'package:flutter/material.dart';
import 'package:mobile/data/local/database_helper.dart';
import 'package:mobile/features/home/global_connectivity_banner.dart';

class EmergencyResource {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final String unit;
  final String status; // AVAILABLE, LOW, CRITICAL, UNAVAILABLE
  final String locationName;

  EmergencyResource({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.status,
    required this.locationName,
  });
}

class ResourceManagementScreen extends StatefulWidget {
  const ResourceManagementScreen({super.key});

  @override
  State<ResourceManagementScreen> createState() => _ResourceManagementScreenState();
}

class _ResourceManagementScreenState extends State<ResourceManagementScreen> {
  final List<EmergencyResource> _resources = [
    EmergencyResource(
      id: 'res_01',
      name: 'Clean Drinking Water',
      category: 'WATER',
      quantity: 5000,
      unit: 'Liters',
      status: 'AVAILABLE',
      locationName: 'Civic Community Shelter',
    ),
    EmergencyResource(
      id: 'res_02',
      name: 'Ready-to-Eat MRE Meals',
      category: 'FOOD',
      quantity: 120,
      unit: 'Boxes',
      status: 'LOW',
      locationName: 'North Hill Shelter',
    ),
    EmergencyResource(
      id: 'res_03',
      name: 'Trauma First Aid Kits',
      category: 'MEDICINE',
      quantity: 15,
      unit: 'Kits',
      status: 'CRITICAL',
      locationName: 'Civic Community Shelter',
    ),
    EmergencyResource(
      id: 'res_04',
      name: 'Thermal Emergency Blankets',
      category: 'SUPPLIES',
      quantity: 450,
      unit: 'Units',
      status: 'AVAILABLE',
      locationName: 'Presidio Hub',
    ),
    EmergencyResource(
      id: 'res_05',
      name: 'Type O- Negative Blood Packs',
      category: 'MEDICINE',
      quantity: 0,
      unit: 'Packs',
      status: 'UNAVAILABLE',
      locationName: 'Metro General Hospital',
    ),
  ];

  void _showAddResourceDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '100');
    final unitCtrl = TextEditingController(text: 'Units');
    String selectedCategory = 'WATER';
    String selectedStatus = 'AVAILABLE';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Register Resource Supply'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Resource Item Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'WATER', child: Text('Clean Water', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'FOOD', child: Text('Food & Rations', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'MEDICINE', child: Text('Medical & Supplies', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'SUPPLIES', child: Text('Blankets & Gear', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) selectedCategory = val;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(labelText: 'Unit (Liters/Boxes)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Availability Status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'AVAILABLE', child: Text('AVAILABLE (Sufficient)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'LOW', child: Text('LOW (Running Low)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'CRITICAL', child: Text('CRITICAL (Urgent)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'UNAVAILABLE', child: Text('UNAVAILABLE (Depleted)', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) selectedStatus = val;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final resId = 'res_${DateTime.now().millisecondsSinceEpoch}';
                final newRes = EmergencyResource(
                  id: resId,
                  name: name,
                  category: selectedCategory,
                  quantity: int.tryParse(qtyCtrl.text) ?? 100,
                  unit: unitCtrl.text.trim(),
                  status: selectedStatus,
                  locationName: 'Local Relief Hub',
                );

                // Save to local SQLite sync queue
                final db = DatabaseHelper.instance;
                await db.queueSyncOperation(
                  entityType: 'resources',
                  entityId: resId,
                  op: 'INSERT',
                  payload: {
                    'name': newRes.name,
                    'category': newRes.category,
                    'quantity': newRes.quantity,
                    'unit': newRes.unit,
                    'status': newRes.status,
                  },
                );

                setState(() => _resources.insert(0, newRes));
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Resource "$name" registered & queued for sync!')),
                  );
                }
              },
              child: const Text('REGISTER ITEM'),
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
        title: const Text('Disaster Supplies & Resources'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            tooltip: 'Add Supply Item',
            onPressed: _showAddResourceDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          const GlobalConnectivityBanner(),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _resources.length,
              itemBuilder: (context, idx) {
                final res = _resources[idx];

                Color statusBg = Colors.green.shade100;
                Color statusFg = Colors.green.shade900;
                if (res.status == 'LOW') {
                  statusBg = Colors.amber.shade100;
                  statusFg = Colors.amber.shade900;
                } else if (res.status == 'CRITICAL') {
                  statusBg = Colors.orange.shade100;
                  statusFg = Colors.orange.shade900;
                } else if (res.status == 'UNAVAILABLE') {
                  statusBg = Colors.red.shade100;
                  statusFg = Colors.red.shade900;
                }

                IconData categoryIcon = Icons.water_drop;
                if (res.category == 'FOOD') categoryIcon = Icons.restaurant;
                if (res.category == 'MEDICINE') categoryIcon = Icons.medical_services;
                if (res.category == 'SUPPLIES') categoryIcon = Icons.king_bed;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusBg,
                      child: Icon(categoryIcon, color: statusFg),
                    ),
                    title: Text(
                      res.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Qty: ${res.quantity} ${res.unit} | ${res.locationName}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Chip(
                      label: Text(
                        res.status,
                        style: TextStyle(color: statusFg, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                      backgroundColor: statusBg,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
