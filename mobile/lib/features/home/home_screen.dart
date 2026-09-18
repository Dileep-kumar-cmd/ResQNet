import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/features/auth/auth_service.dart';
import 'package:mobile/data/local/database_helper.dart';
import 'package:mobile/features/map/offline_map_screen.dart';
import 'package:mobile/features/shelters/shelter_finder_screen.dart';
import 'package:mobile/features/ai/ai_dashboard_screen.dart';
import 'package:mobile/features/mesh/mesh_router.dart';
import 'package:mobile/features/mesh/mesh_monitor_screen.dart';
import 'package:mobile/features/medical/first_aid_guide_screen.dart';
import 'package:mobile/features/resources/resource_management_screen.dart';
import 'package:mobile/features/volunteers/volunteer_management_screen.dart';
import 'package:mobile/features/navigation/navigation_screen.dart';
import 'package:mobile/features/sync/sync_service.dart';
import 'dart:async';
import 'package:mobile/features/home/global_connectivity_banner.dart';
import 'package:mobile/features/profile/user_profile_screen.dart';
import 'package:mobile/features/alerts/emergency_alert_service.dart';
import 'package:mobile/core/config/api_config.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  StreamSubscription<EmergencyAlertEvent>? _alertSub;

  @override
  void initState() {
    super.initState();
    _alertSub = EmergencyAlertService.instance.alertStream.listen((event) {
      if (mounted) {
        _showEmergencyAlertDialog(event);
      }
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    super.dispose();
  }

  void _showEmergencyAlertDialog(EmergencyAlertEvent alert) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final auth = Provider.of<AuthService>(context, listen: false);
        final isRescuer = auth.currentSession?.role == 'RESCUER';

        return AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.isOriginator ? 'SOS BROADCAST CONFIRMED' : '🚨 EMERGENCY SOS ALERT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      alert.isOriginator
                          ? 'Mesh nodes alerted • Audio pulse active'
                          : 'Source: ${alert.source} • Priority: ${alert.priority}',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.cyanAccent, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Sender: ${alert.senderId}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.pin_drop, color: Colors.amberAccent, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'GPS: ${alert.latitude.toStringAsFixed(4)}, ${alert.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 8),
                    Text(
                      'Details: ${alert.medicalNote}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.volume_up, size: 16, color: Colors.cyanAccent),
                    label: const Text('Replay Sound', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                    onPressed: () {
                      EmergencyAlertService.instance.playEmergencySound();
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (isRescuer && !alert.isOriginator)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _currentTabIndex = 1); // Switch to Map tab
                },
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('DISPATCH & MAP ROUTE'),
              ),
            TextButton(
              onPressed: () {
                EmergencyAlertService.instance.dismissActiveAlert();
                Navigator.pop(ctx);
              },
              child: const Text('ACKNOWLEDGE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      const EmergencyHqTab(),
      const OfflineMapScreen(),
      const ShelterFinderScreen(),
      const FirstAidGuideScreen(),
      const ResourceManagementScreen(),
      const AIDashboardScreen(),
      const MeshMonitorScreen(),
      const VolunteerManagementScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentTabIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (idx) => setState(() => _currentTabIndex = idx),
        selectedItemColor: Colors.indigo.shade900,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shield),
            label: 'Emergency HQ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.night_shelter_outlined),
            label: 'Shelters',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services_outlined),
            label: 'First Aid',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Resources',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology_outlined),
            label: 'AI Center',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hub_outlined),
            label: 'Mesh',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            label: 'Volunteers',
          ),
        ],
      ),
    );
  }
}

class EmergencyHqTab extends StatefulWidget {
  const EmergencyHqTab({super.key});

  @override
  State<EmergencyHqTab> createState() => _EmergencyHqTabState();
}

class _EmergencyHqTabState extends State<EmergencyHqTab> {
  final double _userLat = 37.7749;
  final double _userLon = -122.4194;

  List<Map<String, dynamic>> _nearbyShelters = [];
  List<Map<String, dynamic>> _pendingSyncItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final shelters = await db.getNearbyShelters(_userLat, _userLon);
    final syncQueue = await db.getPendingSyncItems();

    setState(() {
      _nearbyShelters = shelters;
      _pendingSyncItems = syncQueue;
      _isLoading = false;
    });
  }

  Future<void> _triggerCloudSync() async {
    final result = await SyncService.instance.triggerSync();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.isSuccess ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      );
    }
    await _refreshData();
  }

  void _showServerConfigDialog() async {
    final currentCustom = await ApiConfig.getCustomHost() ?? '192.168.51.229:8000';
    final hostCtrl = TextEditingController(text: currentCustom);
    String testStatus = '';

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Row(
                children: [
                  Icon(Icons.dns, color: Colors.cyanAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Backend Cloud Endpoint',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Specify host IP to sync SOS logs and receive alerts (USB cable or local Wi-Fi):',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hostCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Host:Port',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        backgroundColor: const Color(0xFF1E293B),
                        label: const Text('Wi-Fi LAN (192.168.51.229:8000)', style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                        onPressed: () => setDialogState(() => hostCtrl.text = '192.168.51.229:8000'),
                      ),
                      ActionChip(
                        backgroundColor: const Color(0xFF1E293B),
                        label: const Text('USB adb reverse (127.0.0.1:8000)', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                        onPressed: () => setDialogState(() => hostCtrl.text = '127.0.0.1:8000'),
                      ),
                    ],
                  ),
                  if (testStatus.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      testStatus,
                      style: TextStyle(
                        color: testStatus.contains('Online') ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    setDialogState(() => testStatus = 'Testing connection...');
                    try {
                      final url = 'http://${hostCtrl.text.trim()}/api/v1/health';
                      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
                      if (res.statusCode == 200) {
                        setDialogState(() => testStatus = '✓ Online & Reachable (200 OK)');
                      } else {
                        setDialogState(() => testStatus = 'HTTP ${res.statusCode}');
                      }
                    } catch (e) {
                      setDialogState(() => testStatus = 'Connection failed: $e');
                    }
                  },
                  child: const Text('TEST PING', style: TextStyle(color: Colors.cyanAccent)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await ApiConfig.setCustomHost(hostCtrl.text.trim());
                    if (context.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved backend endpoint: ${hostCtrl.text.trim()}'),
                          backgroundColor: Colors.green.shade800,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                  child: const Text('SAVE & APPLY'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSosConfirmationModal() {
    final noteCtrl = TextEditingController(text: 'Emergency medical & rescue assistance requested.');
    String urgencyLevel = 'CRITICAL';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CONFIRM EMERGENCY SOS',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will broadcast an urgent SOS packet to nearby P2P Mesh nodes and queue it in your local database for cloud sync.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text('Priority Level:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                initialValue: urgencyLevel,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'CRITICAL',
                    child: Text('CRITICAL (Immediate Life Hazard)', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: 'HIGH',
                    child: Text('HIGH (Injury / Trapped)', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: 'MEDIUM',
                    child: Text('MEDIUM (Supply Request)', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) urgencyLevel = val;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Medical Note / Location Details',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final auth = Provider.of<AuthService>(context, listen: false);
                final userId = auth.currentSession?.id ?? 'usr_guest_offline';

                final meshRouter = MeshRouter.instance;
                final packet = await meshRouter.broadcastSOSPacket(
                  userId: userId,
                  lat: _userLat,
                  lon: _userLon,
                  medicalNote: noteCtrl.text.trim(),
                );

                // Auto-sync to backend immediately if online!
                if (!auth.isAirplaneModeForced) {
                  await SyncService.instance.triggerSync();
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🆘 SOS Alert ${packet.payload['sos_id']} Broadcasted & Synced!'),
                      backgroundColor: Colors.red.shade900,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                await _refreshData();
              },
              icon: const Icon(Icons.sos),
              label: const Text('CONFIRM & BROADCAST SOS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
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
    final auth = Provider.of<AuthService>(context);
    final session = auth.currentSession;
    final userName = session?.name ?? 'Lead Disaster Responder';
    final userRole = session?.role ?? 'RESCUER';

    final nameParts = userName.trim().split(' ');
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : userName.isNotEmpty
            ? userName[0].toUpperCase()
            : 'R';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ResQNet Disaster Command HQ'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: 'Trigger Cloud Sync',
            onPressed: _triggerCloudSync,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Local Data',
            onPressed: _refreshData,
          ),
          // Responder Profile Avatar & Menu
          Padding(
            padding: const EdgeInsets.only(right: 8.0, left: 4.0),
            child: PopupMenuButton<String>(
              icon: Stack(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.indigo.shade700,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: auth.isAirplaneModeForced ? Colors.orange : Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.indigo.shade900, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              tooltip: 'Responder Profile Menu',
              color: const Color(0xFF0F172A),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF1E293B)),
              ),
              onSelected: (val) {
                if (val == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                  );
                } else if (val == 'server_config') {
                  _showServerConfigDialog();
                } else if (val == 'airplane') {
                  auth.toggleAirplaneModeSim(!auth.isAirplaneModeForced);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        auth.isAirplaneModeForced
                            ? 'Simulating Airplane Mode (Offline Test Active)'
                            : 'Switched to Normal Online Mode',
                      ),
                      backgroundColor: const Color(0xFF1E293B),
                    ),
                  );
                } else if (val == 'logout') {
                  auth.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle, color: Colors.cyanAccent, size: 22),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Role: $userRole • View Profile', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem(
                  value: 'server_config',
                  child: Row(
                    children: [
                      Icon(Icons.dns, color: Colors.lightGreenAccent, size: 20),
                      SizedBox(width: 12),
                      Text('Backend Cloud Server IP', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'airplane',
                  child: Row(
                    children: [
                      Icon(
                        auth.isAirplaneModeForced ? Icons.airplanemode_active : Icons.airplanemode_inactive,
                        color: Colors.amberAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        auth.isAirplaneModeForced ? 'Disable Airplane Sim' : 'Simulate Airplane Mode',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      SizedBox(width: 12),
                      Text('Sign Out Responder', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const GlobalConnectivityBanner(),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prominent SOS Quick Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _showSosConfirmationModal,
                      icon: const Icon(Icons.warning_amber_rounded, size: 32),
                      label: const Text(
                        'EMERGENCY SOS (TAP TO BROADCAST)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Quick Action Buttons Grid
                  Text(
                    'Emergency Operations Grid',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                    children: [
                      _buildQuickActionTile(
                        context,
                        title: 'Find Shelter',
                        subtitle: 'Multi-criteria matching',
                        icon: Icons.night_shelter,
                        color: Colors.blue.shade800,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ShelterFinderScreen()),
                          );
                        },
                      ),
                      _buildQuickActionTile(
                        context,
                        title: 'First Aid Guide',
                        subtitle: '25+ offline protocols',
                        icon: Icons.medical_services,
                        color: Colors.red.shade800,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FirstAidGuideScreen()),
                          );
                        },
                      ),
                      _buildQuickActionTile(
                        context,
                        title: 'Supplies & Food',
                        subtitle: 'Resource inventory',
                        icon: Icons.inventory_2,
                        color: Colors.orange.shade800,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ResourceManagementScreen()),
                          );
                        },
                      ),
                      _buildQuickActionTile(
                        context,
                        title: 'Volunteer Hub',
                        subtitle: 'Tasks & responder list',
                        icon: Icons.group,
                        color: Colors.teal.shade800,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const VolunteerManagementScreen()),
                          );
                        },
                      ),
                      _buildQuickActionTile(
                        context,
                        title: 'Vector Map',
                        subtitle: 'Offline map tiles',
                        icon: Icons.map,
                        color: Colors.indigo.shade800,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const OfflineMapScreen()),
                          );
                        },
                      ),
                      _buildQuickActionTile(
                        context,
                        title: 'AI Intelligence',
                        subtitle: 'On-device TFLite',
                        icon: Icons.psychology,
                        color: Colors.purple.shade800,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AIDashboardScreen()),
                          );
                        },
                      ),
                      _buildQuickActionTile(
                        context,
                        title: 'Responder Profile',
                        subtitle: 'ICE card & details',
                        icon: Icons.account_circle,
                        color: Colors.blueGrey.shade800,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                          );
                        },
                      ),
                      _buildQuickActionTile(
                        context,
                        title: 'Mesh Network',
                        subtitle: 'P2P radio monitor',
                        icon: Icons.hub,
                        color: Colors.indigo.shade800,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MeshMonitorScreen()),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Nearby Shelters Proximity List
                  Text(
                    'Nearest Shelters & Navigation',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _nearbyShelters.isEmpty
                          ? const Text('No shelters cached locally.')
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _nearbyShelters.length,
                              itemBuilder: (context, idx) {
                                final s = _nearbyShelters[idx];
                                final dist = (s['distance_km'] as double).toStringAsFixed(2);
                                final sLat = (s['latitude'] as num).toDouble();
                                final sLon = (s['longitude'] as num).toDouble();

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  elevation: 2,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.indigo.shade100,
                                      child: const Icon(Icons.night_shelter, color: Colors.indigo),
                                    ),
                                    title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      'Beds: ${s['current_occupancy']}/${s['capacity']} | Distance: $dist km',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => NavigationScreen(
                                              destinationName: s['name'],
                                              destinationLat: sLat,
                                              destinationLon: sLon,
                                              userLat: _userLat,
                                              userLon: _userLon,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.navigation, size: 14),
                                      label: const Text('NAVIGATE', style: TextStyle(fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo.shade900,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                  const SizedBox(height: 24),

                  // Sync Queue Status & Trigger Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Local Sync Queue (${_pendingSyncItems.length} Pending)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _triggerCloudSync,
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('SYNC NOW'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade900,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _pendingSyncItems.isEmpty
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text('All local changes synced to central server.'),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingSyncItems.length,
                          itemBuilder: (context, idx) {
                            final item = _pendingSyncItems[idx];
                            return Card(
                              color: Colors.amber.shade50,
                              child: ListTile(
                                leading: const Icon(Icons.sync, color: Colors.amber),
                                title: Text('${item['entity_type']} - ${item['entity_id']}'),
                                subtitle: Text('Op: ${item['op']} | Queued: ${item['created_at']}'),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
