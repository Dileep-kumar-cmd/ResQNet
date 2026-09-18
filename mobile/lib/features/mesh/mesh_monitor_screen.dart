// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/features/mesh/mesh_router.dart';
import 'package:mobile/features/mesh/mesh_packet.dart';

class MeshMonitorScreen extends StatefulWidget {
  const MeshMonitorScreen({super.key});

  @override
  State<MeshMonitorScreen> createState() => _MeshMonitorScreenState();
}

class _MeshMonitorScreenState extends State<MeshMonitorScreen> {
  /// Developer Diagnostic Tool: Injects a test packet into the mesh router
  /// to verify multi-hop forwarding and deduplication logic on a single physical device.
  Future<void> _injectDevTestPacket() async {
    final router = Provider.of<MeshRouter>(context, listen: false);
    final now = DateTime.now().toIso8601String();
    final testSosId = 'sos_devtest_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final testPacket = MeshPacket(
      packetId: 'pkt_$testSosId',
      senderId: 'node_peer_test_device',
      timestamp: now,
      type: MeshPacketType.sosAlert,
      priority: MeshPacketPriority.critical,
      payload: {
        'sos_id': testSosId,
        'user_id': 'node_peer_test_device',
        'latitude': 37.7800,
        'longitude': -122.4100,
        'status': 'RELAYED',
        'medical_note': 'Autonomous mesh multi-hop test packet',
      },
      ttlHops: 4,
      hopCount: 1,
      relayPath: ['node_peer_test_device'],
    );

    final bool relayed = await router.receiveIncomingPacket(testPacket);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            relayed
              ? 'Test SOS $testSosId received & relayed across BLE mesh!'
              : 'Packet suppressed: Duplicate detected in LRU cache.',
          ),
          backgroundColor: relayed ? Colors.green.shade800 : Colors.orange.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = Provider.of<MeshRouter>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B111E),
      appBar: AppBar(
        title: const Text('BLE Mesh Radio & Topology', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, size: 20),
            tooltip: 'Developer: Inject Test Packet',
            onPressed: _injectDevTestPacket,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mesh Router Status Card
            Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.hub, color: Colors.cyanAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              router.nodeId,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: router.isScanningActive ? Colors.greenAccent : Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  router.isScanningActive ? 'REAL BLE MESH ACTIVE' : 'RADIO INITIALIZING',
                                  style: TextStyle(
                                    color: router.isScanningActive ? Colors.greenAccent : Colors.orangeAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade900.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigoAccent),
                        ),
                        child: const Text(
                          'DUAL-ROLE BLE',
                          style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFF1E293B)),
                  const SizedBox(height: 8),

                  // Adaptive Duty Cycle Control
                  Row(
                    children: [
                      const Icon(Icons.battery_saver, color: Colors.cyanAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Radio Duty-Cycle:',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              router.isLowPowerDutyCycle ? 'Low Power (Balanced)' : 'Active (Low Latency)',
                              style: TextStyle(
                                color: router.isLowPowerDutyCycle ? Colors.amber : Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: router.isLowPowerDutyCycle,
                        activeColor: Colors.cyanAccent,
                        onChanged: (val) => router.toggleDutyCycle(val),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Statistics Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PACKETS RELAYED',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${router.relayedCount}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DUPLICATES SUPPRESSED',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${router.duplicatedSuppressedCount}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Discovered Nearby Peer Nodes (GENUINE HARDWARE)
            Row(
              children: [
                const Icon(Icons.sensors, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Physical Peer Nodes (${router.activePeers.length} Detected)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (router.activePeers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.bluetooth_searching, size: 36, color: Colors.cyanAccent.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    const Text(
                      'Continuous Autonomous BLE Scanning Active',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No fake peers. The radio is advertising and scanning for ResQNet nodes (UUID: 0000FE60). Bring another phone within Bluetooth range to automatically form the mesh.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: router.activePeers.values.length,
                itemBuilder: (context, idx) {
                  final peer = router.activePeers.values.elementAt(idx);
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: peer.isConnected ? Colors.cyanAccent.withOpacity(0.5) : const Color(0xFF1E293B),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: peer.isConnected ? Colors.indigo.shade900 : const Color(0xFF1E293B),
                          child: Icon(
                            peer.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                            color: peer.isConnected ? Colors.cyanAccent : Colors.white54,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                peer.nodeId,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'MAC: ${peer.address.isNotEmpty ? peer.address : 'Auto-Resolved'}',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: peer.isConnected ? Colors.green.shade900.withOpacity(0.5) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: peer.isConnected ? Colors.greenAccent : Colors.white24,
                                ),
                              ),
                              child: Text(
                                peer.isConnected ? 'CONNECTED' : 'DISCOVERED',
                                style: TextStyle(
                                  color: peer.isConnected ? Colors.greenAccent : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${peer.rssi} dBm',
                              style: TextStyle(
                                color: peer.rssi > -65 ? Colors.greenAccent : Colors.amberAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 20),

            // Multi-Hop Relayed Feed
            Row(
              children: [
                const Icon(Icons.alt_route, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Multi-Hop Relayed Packets Feed',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (router.relayedPackets.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: const Text(
                  'No packets relayed yet. When an emergency SOS or message arrives over BLE, it is verified, stored in SQLite, and relayed automatically.',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: router.relayedPackets.length,
                itemBuilder: (context, idx) {
                  final pkt = router.relayedPackets[idx];
                  final isAcked = router.acknowledgedPacketIds.contains(pkt.packetId);

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pkt.priority == MeshPacketPriority.critical
                          ? const Color(0xFF450A0A).withOpacity(0.4)
                          : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: pkt.priority == MeshPacketPriority.critical
                            ? Colors.redAccent.withOpacity(0.6)
                            : const Color(0xFF1E293B),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              pkt.type == MeshPacketType.ack ? Icons.verified : Icons.emergency,
                              color: pkt.type == MeshPacketType.ack ? Colors.greenAccent : Colors.redAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                pkt.packetId,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAcked) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade900.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.greenAccent),
                                ),
                                child: const Text(
                                  'ACK CONFIRMED',
                                  style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${pkt.ttlHops} TTL LEFT',
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sender: ${pkt.senderId} | Hops: ${pkt.hopCount}',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Path: ${pkt.relayPath.join(" ➔ ")}',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 20),

            // Live Hardware Event Stream
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Live Radio Event Stream',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              height: 140,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF030712),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: router.eventLogs.isEmpty
                  ? const Center(
                      child: Text(
                        'Radio event log empty. Hardware events will stream here live.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    )
                  : ListView.builder(
                      itemCount: router.eventLogs.length,
                      itemBuilder: (context, idx) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            router.eventLogs[idx],
                            style: const TextStyle(
                              color: Colors.lightGreenAccent,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
