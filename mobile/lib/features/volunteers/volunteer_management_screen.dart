import 'package:flutter/material.dart';
import 'package:mobile/data/local/database_helper.dart';
import 'package:mobile/features/home/global_connectivity_banner.dart';

class VolunteerTask {
  final String id;
  final String title;
  final String location;
  final String skillRequired;
  final String urgency;
  String status; // PENDING, IN_PROGRESS, COMPLETED

  VolunteerTask({
    required this.id,
    required this.title,
    required this.location,
    required this.skillRequired,
    required this.urgency,
    required this.status,
  });
}

class VolunteerManagementScreen extends StatefulWidget {
  const VolunteerManagementScreen({super.key});

  @override
  State<VolunteerManagementScreen> createState() => _VolunteerManagementScreenState();
}

class _VolunteerManagementScreenState extends State<VolunteerManagementScreen> {
  bool _isAvailable = true;
  String _selectedSkill = 'First Aid & Triage';

  final List<VolunteerTask> _tasks = [
    VolunteerTask(
      id: 'task_01',
      title: 'Distribute Clean Water Packs at Zone B',
      location: 'Civic Community Shelter',
      skillRequired: 'Logistics & Distribution',
      urgency: 'HIGH',
      status: 'PENDING',
    ),
    VolunteerTask(
      id: 'task_02',
      title: 'Assist Medical Triage Tents with Bandaging',
      location: 'Metro General Hospital',
      skillRequired: 'First Aid & Triage',
      urgency: 'CRITICAL',
      status: 'IN_PROGRESS',
    ),
    VolunteerTask(
      id: 'task_03',
      title: 'Debris Clearance & Search Operations',
      location: 'North Hill High Area',
      skillRequired: 'Search & Rescue',
      urgency: 'HIGH',
      status: 'PENDING',
    ),
  ];

  void _toggleTaskStatus(VolunteerTask task) async {
    setState(() {
      if (task.status == 'PENDING') {
        task.status = 'IN_PROGRESS';
      } else if (task.status == 'IN_PROGRESS') {
        task.status = 'COMPLETED';
      } else {
        task.status = 'PENDING';
      }
    });

    final db = DatabaseHelper.instance;
    await db.queueSyncOperation(
      entityType: 'volunteer_tasks',
      entityId: task.id,
      op: 'UPDATE',
      payload: {
        'task_id': task.id,
        'status': task.status,
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${task.title}" updated to ${task.status}! Sync queued.'),
          backgroundColor: task.status == 'COMPLETED' ? Colors.green.shade800 : Colors.indigo.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer & Responder Center'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const GlobalConnectivityBanner(),

          // Volunteer Status Header Card
          Card(
            margin: const EdgeInsets.all(12),
            color: _isAvailable ? Colors.green.shade50 : Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _isAvailable ? Colors.green : Colors.grey,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Volunteer Duty Status',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              _isAvailable ? 'ACTIVE & ON-CALL FOR DISPATCH' : 'OFF DUTY / RESTING',
                              style: TextStyle(
                                color: _isAvailable ? Colors.green.shade900 : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isAvailable,
                        activeColor: Colors.green,
                        onChanged: (val) => setState(() => _isAvailable = val),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const Text('Primary Skill: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedSkill,
                          isExpanded: true,
                          underline: Container(),
                          style: const TextStyle(color: Colors.black87, fontSize: 13),
                          items: const [
                            DropdownMenuItem(value: 'First Aid & Triage', child: Text('First Aid & Triage', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'Search & Rescue', child: Text('Search & Rescue', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'Logistics & Distribution', child: Text('Logistics & Distribution', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'Shelter Admin', child: Text('Shelter Admin', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSkill = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Disaster Dispatch Tasks Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Emergency Dispatch Queue',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('${_tasks.length} Assigned', style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.indigo.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _tasks.length,
              itemBuilder: (context, idx) {
                final t = _tasks[idx];

                Color statusFg = Colors.amber.shade900;
                if (t.status == 'IN_PROGRESS') {
                  statusFg = Colors.blue.shade900;
                } else if (t.status == 'COMPLETED') {
                  statusFg = Colors.green.shade900;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 1.5,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: t.urgency == 'CRITICAL' ? Colors.red.shade100 : Colors.indigo.shade100,
                              child: Icon(
                                t.urgency == 'CRITICAL' ? Icons.warning_amber_rounded : Icons.assignment,
                                color: t.urgency == 'CRITICAL' ? Colors.red : Colors.indigo,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Location: ${t.location}',
                                    style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                                  ),
                                  Text(
                                    'Skill: ${t.skillRequired}',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status: ${t.status}',
                              style: TextStyle(color: statusFg, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            ElevatedButton(
                              onPressed: () => _toggleTaskStatus(t),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: t.status == 'COMPLETED' ? Colors.grey : Colors.indigo.shade900,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                minimumSize: const Size(80, 32),
                              ),
                              child: Text(
                                t.status == 'PENDING'
                                    ? 'ACCEPT'
                                    : (t.status == 'IN_PROGRESS' ? 'COMPLETE' : 'REOPEN'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
