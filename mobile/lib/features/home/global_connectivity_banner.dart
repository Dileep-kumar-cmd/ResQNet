import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/features/auth/auth_service.dart';
import 'package:mobile/features/sync/sync_service.dart';
import 'package:mobile/features/mesh/mesh_router.dart';

class GlobalConnectivityBanner extends StatelessWidget {
  const GlobalConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final syncService = Provider.of<SyncService>(context);
    final meshRouter = Provider.of<MeshRouter>(context);

    final bool isOffline = authService.isAirplaneModeForced;
    final int meshPeersCount = meshRouter.activePeers.length;
    final int relayedCount = meshRouter.relayedCount;
    final DateTime? lastSync = syncService.lastSyncTime;

    String lastSyncText = 'Not synced yet';
    if (lastSync != null) {
      final diff = DateTime.now().difference(lastSync);
      if (diff.inSeconds < 60) {
        lastSyncText = 'Synced just now';
      } else if (diff.inMinutes < 60) {
        lastSyncText = 'Synced ${diff.inMinutes}m ago';
      } else {
        lastSyncText = 'Synced ${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}';
      }
    }

    final Color bgColor = isOffline ? const Color(0xFFC2410C) : const Color(0xFF15803D);

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isOffline ? Colors.orangeAccent : Colors.greenAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isOffline ? Colors.orangeAccent : Colors.greenAccent).withOpacity(0.6),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOffline ? '🟠 OFFLINE MODE (Local SQLite Storage)' : '🟢 ONLINE MODE (Server Sync Active)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      isOffline
                          ? 'Zero Internet Connection • $lastSyncText'
                          : 'Connected to Central HQ • $lastSyncText',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Mesh Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hub, color: Colors.blueAccent, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'MESH: $meshPeersCount P2P ($relayedCount rx)',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Toggle Airplane Mode Button
              InkWell(
                onTap: () => authService.toggleAirplaneModeSim(!isOffline),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOffline ? Icons.airplanemode_active : Icons.wifi,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOffline ? 'GO ONLINE' : 'SIM OFFLINE',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (syncService.isSyncing) ...[
            const SizedBox(height: 4),
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}
