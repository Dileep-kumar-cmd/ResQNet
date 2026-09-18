// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile/features/auth/auth_service.dart';
import 'package:mobile/features/mesh/mesh_router.dart';
import 'package:mobile/features/sync/sync_service.dart';
import 'package:mobile/features/profile/profile_service.dart';
import 'package:mobile/data/local/database_helper.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _cachedSheltersCount = 0;
  int _pendingSyncCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    ProfileService.instance.loadProfile();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final shelters = await db.query('shelters');
      final syncQueue = await DatabaseHelper.instance.getPendingSyncItems();
      if (mounted) {
        setState(() {
          _cachedSheltersCount = shelters.length;
          _pendingSyncCount = syncQueue.length;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  void _showEditProfileSheet(BuildContext context, EmergencyProfileData data) {
    final bloodCtrl = TextEditingController(text: data.bloodType);
    final contactNameCtrl = TextEditingController(text: data.emergencyContactName);
    final contactPhoneCtrl = TextEditingController(text: data.emergencyContactPhone);
    final allergiesCtrl = TextEditingController(text: data.medicalAllergies);
    final conditionsCtrl = TextEditingController(text: data.medicalConditions);
    final sectorCtrl = TextEditingController(text: data.assignedSector);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Emergency & ICE Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSheetTextField('Blood Type (e.g. O+, A-, B+)', bloodCtrl, Icons.bloodtype),
                const SizedBox(height: 10),
                _buildSheetTextField('Emergency Contact Name', contactNameCtrl, Icons.person),
                const SizedBox(height: 10),
                _buildSheetTextField('Emergency Contact Phone', contactPhoneCtrl, Icons.phone),
                const SizedBox(height: 10),
                _buildSheetTextField('Medical Allergies', allergiesCtrl, Icons.warning_amber),
                const SizedBox(height: 10),
                _buildSheetTextField('Medical Conditions / Notes', conditionsCtrl, Icons.medical_services),
                const SizedBox(height: 10),
                _buildSheetTextField('Assigned Sector', sectorCtrl, Icons.fmd_good),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      await ProfileService.instance.updateEmergencyProfile(
                        bloodType: bloodCtrl.text.trim(),
                        emergencyContactName: contactNameCtrl.text.trim(),
                        emergencyContactPhone: contactPhoneCtrl.text.trim(),
                        medicalAllergies: allergiesCtrl.text.trim(),
                        medicalConditions: conditionsCtrl.text.trim(),
                        assignedSector: sectorCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Emergency profile updated and saved to secure offline storage.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('SAVE EMERGENCY DETAILS', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetTextField(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.cyanAccent, size: 20),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthService auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Sign Out Responder', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out? You will need your credentials or offline access to log back in.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
            child: const Text('SIGN OUT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final mesh = Provider.of<MeshRouter>(context);
    final session = auth.currentSession;

    final userName = session?.name ?? 'Lead Disaster Responder';
    final userEmail = session?.email ?? 'rescuer@resqnet.org';
    final userRole = session?.role ?? 'RESCUER';
    final userId = session?.id ?? 'usr_emergency_lead_01';
    final isOfflineSession = session?.isOfflineSession ?? false;
    final tokenPreview = session?.token != null && session!.token.length > 16
        ? '${session.token.substring(0, 8)}...${session.token.substring(session.token.length - 6)}'
        : 'SECURE_TOKEN_ACTIVE';

    // Initials for Avatar
    final nameParts = userName.trim().split(' ');
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : userName.isNotEmpty
            ? userName[0].toUpperCase()
            : 'R';

    return Scaffold(
      backgroundColor: const Color(0xFF0B111E),
      appBar: AppBar(
        title: const Text('Responder Profile & Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Diagnostics',
            onPressed: () {
              ProfileService.instance.loadProfile();
              _loadDiagnostics();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Diagnostics refreshed.'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: ProfileService.instance,
        builder: (context, _) {
          final profileData = ProfileService.instance.profile;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Identity & Role Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Avatar circle with status ring
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.indigo.shade800,
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.cyanAccent,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: auth.isAirplaneModeForced ? Colors.orange : Colors.greenAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF0F172A), width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Name, Email, and ID
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userEmail,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: userId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Responder ID copied to clipboard.')),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'ID: $userId',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: Colors.cyanAccent.withOpacity(0.8),
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.copy, size: 11, color: Colors.cyanAccent.withOpacity(0.7)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Color(0xFF1E293B)),
                      const SizedBox(height: 10),
                      // Role and Session Status Badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade900.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.indigoAccent.withOpacity(0.6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield, size: 13, color: Colors.cyanAccent),
                                const SizedBox(width: 6),
                                Text(
                                  'ROLE: $userRole',
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOfflineSession
                                  ? Colors.amber.shade900.withOpacity(0.4)
                                  : Colors.green.shade900.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isOfflineSession ? Colors.amber : Colors.greenAccent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOfflineSession ? Icons.offline_bolt : Icons.verified_user,
                                  size: 13,
                                  color: isOfflineSession ? Colors.amber : Colors.greenAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isOfflineSession ? 'OFFLINE SESSION' : 'ONLINE JWT ACTIVE',
                                  style: TextStyle(
                                    color: isOfflineSession ? Colors.amber : Colors.greenAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Auth Token Fingerprint: $tokenPreview',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 2. Emergency Medical & In-Case-of-Emergency (ICE) Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.medical_information_outlined, color: Colors.redAccent, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'EMERGENCY & MEDICAL (ICE)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => _showEditProfileSheet(context, profileData),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade800,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.edit, size: 12, color: Colors.cyanAccent),
                                  SizedBox(width: 4),
                                  Text('EDIT', style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Blood Group and ICE Contact
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('BLOOD TYPE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    profileData.bloodType,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 5,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('EMERGENCY ICE CONTACT', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    profileData.emergencyContactName,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    profileData.emergencyContactPhone,
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Allergies & Conditions
                      _buildInfoRow('Known Allergies', profileData.medicalAllergies, Icons.coronavirus_outlined),
                      const SizedBox(height: 6),
                      _buildInfoRow('Medical Status', profileData.medicalConditions, Icons.health_and_safety_outlined),
                      const SizedBox(height: 6),
                      _buildInfoRow('Certifications', profileData.certifications, Icons.badge_outlined),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Tactical Mesh & Operational Telemetry
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.radar, color: Colors.cyanAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'TACTICAL TELEMETRY & MESH',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Mesh Node Call Sign', mesh.nodeId, Icons.hub),
                      const SizedBox(height: 6),
                      _buildInfoRow('Active P2P Peers', '${mesh.activePeers.length} Live Nodes', Icons.wifi_tethering),
                      const SizedBox(height: 6),
                      _buildInfoRow('Assigned Sector', profileData.assignedSector, Icons.map),
                      const SizedBox(height: 6),
                      _buildInfoRow('Live GPS Grid', '37.7749° N, 122.4194° W (Accurate)', Icons.my_location),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 4. Offline Storage Diagnostics Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.storage, color: Colors.amberAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'OFFLINE STORAGE & DATABASE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDiagStat('Cached Shelters', _isLoadingStats ? '...' : '$_cachedSheltersCount', Colors.cyanAccent),
                          _buildDiagStat('Pending Syncs', _isLoadingStats ? '...' : '$_pendingSyncCount', _pendingSyncCount > 0 ? Colors.amberAccent : Colors.greenAccent),
                          _buildDiagStat('Map Tiles', 'Ready', Colors.greenAccent),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final res = await SyncService.instance.triggerSync();
                            await _loadDiagnostics();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: res.isSuccess ? Colors.green.shade800 : Colors.orange.shade800,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('TRIGGER CLOUD SYNC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.cyanAccent,
                            side: const BorderSide(color: Colors.cyanAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 5. Account Actions & Settings
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DEVICE CONTROLS & SESSION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Simulate Airplane Mode', style: TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: const Text('Force app to test offline mesh & local cache', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        value: auth.isAirplaneModeForced,
                        activeColor: Colors.amber,
                        onChanged: (val) {
                          auth.toggleAirplaneModeSim(val);
                        },
                      ),
                      const Divider(color: Color(0xFF1E293B)),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmLogout(context, auth),
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('SIGN OUT / SWITCH RESPONDER', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade900.withOpacity(0.8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.cyanAccent),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagStat(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(val, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}
