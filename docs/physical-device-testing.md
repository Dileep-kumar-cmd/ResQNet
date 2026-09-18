# ResQNet Physical Hardware Testing & Mesh Verification Protocol

This document provides explicit instructions, commands, and verification logging formats for testing ResQNet on **physical Android and iOS hardware**.

---

## 1. Test 1: True Airplane Mode & Zero-Network Capture Protocol

### Purpose
Confirm zero network calls (including DNS lookups, socket attempts, or background telemetry) occur anywhere in the application when the physical device radio is disabled.

### Prerequisites & Tools
- **Android Physical Hardware**: Android device (API 26+) with `adb` USB debugging enabled.
- **iOS Physical Hardware**: iPhone running iOS 15+.
- **Network Traffic Monitor**:
  - Android: `adb shell` + `tcpdump` OR Charles Proxy / Wireshark on host PC.
  - iOS: Charles Proxy configured as manual HTTP proxy target OR Wireshark packet capture on isolated Wi-Fi Access Point.

### Step-by-Step Test Procedure

```bash
# 1. Start packet capture on connected Android device via ADB
adb shell "su -c 'tcpdump -i any -w /sdcard/resqnet_airplane_test.pcap'"

# 2. Toggle system Airplane Mode ON via Settings on target phone
# Ensure Wi-Fi, Cellular Data, and NFC are OFF in system settings.

# 3. Launch ResQNet app cold on phone
flutter run --release -d <device_id>
```

#### User Execution Flow to Test
1. Launch app cold from home screen.
2. Login screen $\rightarrow$ Enter credentials (triggers local salted hash offline auth fallback).
3. Open **Vector Map** tab $\rightarrow$ Pan and zoom across cached regional tiles.
4. Open **Shelter Finder** tab $\rightarrow$ Run rule-based ranking engine.
5. Open **AI Center** tab $\rightarrow$ Execute TFLite on-device ML model inference.
6. Open **First Aid** tab $\rightarrow$ Search protocols (`CPR`, `Bleeding`, `Burns`).
7. Tap **One-Tap SOS** button $\rightarrow$ Verify packet queues locally in SQLite `sos_logs`.
8. Background and foreground app twice.

#### Packet Capture Analysis & Verification
```bash
# Pull PCAP capture file from device to host PC
adb pull /sdcard/resqnet_airplane_test.pcap .

# Analyze PCAP for any DNS (port 53) or HTTP/HTTPS (ports 80, 443) outbound traffic
tcpdump -r resqnet_airplane_test.pcap "dst port 53 or dst port 80 or dst port 443"
```

> [!IMPORTANT]
> **Pass Criteria**: `tcpdump` must return **0 matching packets**. Any socket connection attempt or failed DNS resolution constitutes a test failure.

---

## 2. Test 2: Two-Device & Multi-Hop P2P Mesh Relay Protocol

### Purpose
Confirm an SOS message composed on **Device A** physically relays over **BLE / Wi-Fi Direct / Multipeer Connectivity** to **Device B** (direct hop) and **Device C** (multi-hop), verifying TTL decrementing, `relay_path` trail appending, and LRU deduplication suppression.

---

### Hardware Setup & OS Pairing Matrix

| Test Scenario | Sender Device A | Intermediate Relay B | Recipient Device C | Transport Protocol Active |
| :--- | :--- | :--- | :--- | :--- |
| **Android $\leftrightarrow$ Android (Direct)** | Pixel 7 (Android 14) | — | Galaxy S23 (Android 14) | Wi-Fi Direct / BLE |
| **Android $\leftrightarrow$ iOS (Direct)** | Pixel 7 (Android 14) | — | iPhone 14 (iOS 17) | BLE / Multipeer Abstraction |
| **Multi-Hop Relay (3 Devices)** | Pixel 7 (Android 14) | Galaxy S22 (Android 13) | iPhone 14 (iOS 17) | Multi-Hop BLE + P2P |

---

### Step-by-Step Multi-Hop Test Procedure

1. **Hardware Preparation**:
   - Turn OFF cellular data and Wi-Fi internet connection on all devices.
   - Turn ON Bluetooth on all devices.
   - Position Device A and Device C outside direct range of each other (~30 meters apart), with Device B positioned midway between them.

2. **Step A: Direct Hop Verification (A $\rightarrow$ B)**
   - On Device A: Tap **ONE-TAP SOS (BROADCAST TO MESH)**.
   - Check Device B log stream.

   ```log
   [MESH_DEBUG 15:15:02.102] RECEIVED_PACKET | ID: pkt_sos_1722179702 | Sender: usr_device_A | Hops: 0 | TTL: 5 | Path: [usr_device_A]
   [MESH_DEBUG 15:15:02.115] FORWARDED_PACKET | ID: pkt_sos_1722179702 | Next TTL: 4 | Updated Path: [usr_device_A, node_device_B]
   ```

3. **Step B: Multi-Hop Relay Verification (A $\rightarrow$ B $\rightarrow$ C)**
   - Check Device C log stream.

   ```log
   [MESH_DEBUG 15:15:02.148] RECEIVED_PACKET | ID: pkt_sos_1722179702 | Sender: usr_device_A | Hops: 2 | TTL: 3 | Path: [usr_device_A, node_device_B, node_device_C]
   ```

4. **Step C: Deduplication Suppression Verification**
   - Retransmit identical packet from Device A.
   - Check Device B log stream:

   ```log
   [MESH_DEBUG 15:15:05.320] DEDUPLICATION_SUPPRESSED | ID: pkt_sos_1722179702 | Reason: Already present in LRU MeshDeduplicator cache. Packet re-broadcast halted.
   ```

---

## 3. Battery Drain & Duty-Cycling Benchmark

- Leave `MeshRouter` active in background for 30 minutes in low-power duty-cycling mode (`isLowPowerDutyCycle = true`).
- Measure battery consumption:
  - **Pass Threshold**: $< 1.5\%$ battery drain over 30 minutes.
