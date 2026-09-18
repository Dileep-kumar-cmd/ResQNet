# ResQNet: Decentralized Offline-First Disaster Response System

**ResQNet** is a robust, resilient disaster response communications and coordination platform designed to function under total infrastructure collapse (no cellular connectivity, no internet, power grid failures). 

It integrates a **peer-to-peer Bluetooth Low Energy (BLE) mesh network**, an **offline-first Flutter mobile application**, an **intelligent FastAPI cloud/edge server with CRDT synchronization**, and a **real-time emergency admin command dashboard**.

---

## Architecture Overview

```
+-----------------------------------------------------------------------------------+
|                              ResQNet Architecture                                |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  +-------------------------------------+      +--------------------------------+  |
|  |     Physical Mobile Client          | BLE  |   Nearby P2P Mesh Devices      |  |
|  |     (Flutter / Android / iOS)       |<---->|   (Relay Nodes & Citizen SOS)  |  |
|  | - Store-and-forward SQLite          |      +--------------------------------+  |
|  | - Native 180Hz emergency audio      |                                          |
|  | - On-device ML shelter ranking      |                                          |
|  | - Turn-by-turn offline navigation   |                                          |
|  +-------------------------------------+                                          |
|                     |                                                             |
|                     | HTTP / Dynamic LAN / USB Port Forward                       |
|                     v                                                             |
|  +-------------------------------------+                                          |
|  |     FastAPI Backend Gateway         |                                          |
|  | - Vector Clock CRDT Sync            |                                          |
|  | - SQLite / PostgreSQL Store         |                                          |
|  | - Real-time WebSocket Alert Hub     |                                          |
|  +-------------------------------------+                                          |
|                     |                                                             |
|                     | WebSocket / REST API                                        |
|                     v                                                             |
|  +-------------------------------------+                                          |
|  |     Emergency Command Dashboard     |                                          |
|  |     (React + Vite + Web Audio)      |                                          |
|  | - Live incident tracking            |                                          |
|  | - Audio synthesis alerts            |                                          |
|  | - Rescue team dispatching           |                                          |
|  +-------------------------------------+                                          |
+-----------------------------------------------------------------------------------+
```

---

## Core Capabilities

1. **Decentralized BLE Mesh Networking**: Multi-hop peer-to-peer relaying with packet deduplication, TTL decrements, and store-and-forward persistence when out of range.
2. **Multi-Tier Emergency SOS Alerts**:
   - Immediate native hardware audio pulse synthesis (deep 180 Hz frequency) + synchronized haptics on victim and receiving peer devices.
   - Real-time WebSocket dispatch to Command HQ and rescue teams with turn-by-turn navigation coordinates.
3. **Offline-First Vector Clock Sync**: Deterministic CRDT delta synchronization between distributed field nodes and central databases without data loss.
4. **On-Device Machine Learning**: TFLite model scoring shelter suitability, capacity constraints, and depletion timelines.
5. **Interactive Admin Command Console**: Instantaneous map-based dispatching, resource reallocation, and live incident management.

---

## Project Structure

- **`/mobile`**: Flutter mobile application featuring offline mapping, emergency medical protocols, volunteer dispatch, and native BLE/Audio integrations.
- **`/backend`**: FastAPI Python server supporting asynchronous endpoints, CRDT synchronization algorithms, WebSocket channels, and automated test suites.
- **`/admin-dashboard`**: React + Vite command center with real-time Web Audio API siren synthesis, WebSocket listener, and operational metrics.
- **`/docs`**: In-depth synchronization protocol specifications and physical hardware testing manuals.

---

## Getting Started

### 1. Backend Server
```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. Admin Command Dashboard
```bash
cd admin-dashboard
npm install
npm run dev
```

### 3. Mobile Application
```bash
cd mobile
flutter pub get
flutter run
```

---

## Testing & Quality Assurance
- **Flutter Unit & Widget Tests**: `flutter test`
- **Backend API & Sync Tests**: `pytest`
- **Admin Dashboard Build**: `npm run build`
