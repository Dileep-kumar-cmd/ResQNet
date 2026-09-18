# ResQNet Data Synchronization & CRDT Protocol Specification

## 1. Overview
ResQNet relies on an offline-first architecture. When cell towers and internet access fail, mobile devices collect SOS logs, shelter updates, and message relays locally. Once connectivity to the central server (FastAPI + PostgreSQL/PostGIS) is restored, bi-directional data synchronization occurs automatically.

To ensure deterministic merge operations without data loss or server-side locking, ResQNet utilizes **Conflict-free Replicated Data Types (CRDTs)** combined with **Vector Clocks** and **Last-Write-Wins Element-Set (LWW-Element-Set)** rules.

---

## 2. Sync Payload Format

Sync messages exchanged between the mobile client and the central server use JSON formatted over HTTPS (or WebSocket).

### 2.1 Sync Request (Mobile -> Server)
```json
{
  "client_id": "device_uuid_v4_string",
  "vector_clock": {
    "device_uuid_v4_string": 14,
    "server_node": 102
  },
  "last_synced_at": "2026-07-28T12:00:00Z",
  "changes": [
    {
      "entity_type": "sos_logs",
      "entity_id": "sos_8f9a2b1c",
      "op": "UPSERT",
      "payload": {
        "id": "sos_8f9a2b1c",
        "user_id": "usr_102",
        "latitude": 37.7749,
        "longitude": -122.4194,
        "status": "QUEUED",
        "timestamp": "2026-07-28T14:30:00Z",
        "relay_path": ["usr_102", "usr_105"],
        "version": 1
      },
      "vector_clock": {
        "device_uuid_v4_string": 14
      },
      "updated_at": "2026-07-28T14:30:00Z"
    },
    {
      "entity_type": "shelters",
      "entity_id": "shl_001",
      "op": "UPDATE_OCCUPANCY",
      "payload": {
        "id": "shl_001",
        "current_occupancy": 145,
        "updated_at": "2026-07-28T14:32:00Z"
      },
      "vector_clock": {
        "device_uuid_v4_string": 14
      },
      "updated_at": "2026-07-28T14:32:00Z"
    }
  ]
}
```

### 2.2 Sync Response (Server -> Mobile)
```json
{
  "status": "SUCCESS",
  "server_vector_clock": {
    "device_uuid_v4_string": 14,
    "server_node": 103
  },
  "processed_count": 2,
  "conflicts_resolved": 0,
  "server_changes": [
    {
      "entity_type": "shelters",
      "entity_id": "shl_002",
      "op": "UPSERT",
      "payload": {
        "id": "shl_002",
        "name": "Central High School Shelter",
        "latitude": 37.7833,
        "longitude": -122.4167,
        "capacity": 500,
        "current_occupancy": 320,
        "hazard_rating": 2,
        "equipment": {"generators": 3, "medical_supplies": true},
        "updated_at": "2026-07-28T14:00:00Z"
      },
      "vector_clock": {
        "server_node": 103
      },
      "updated_at": "2026-07-28T14:00:00Z"
    }
  ]
}
```

---

## 3. Conflict Resolution Strategy (CRDT & LWW)

### 3.1 Vector Clock & Causal Ordering
Each client device maintains an internal counter incremented on local mutations. Every mutated entity carries a `vector_clock` dictionary mapping device IDs to update sequences.

1. **Causally Precedes**: State A precedes State B if every node's counter in A is $\le$ B's counter, and at least one counter in B is strictly $>$.
2. **Concurrent States**: If neither State A nor State B causally precedes the other, a conflict exists.

### 3.2 LWW-Element-Set Rules
For concurrent modifications on the same entity (`entity_id` match):

1. **Monotonic Status Updates (SOS Logs)**:
   - Status transitions follow a strict lattice order: `QUEUED` $\rightarrow$ `RELAYED` $\rightarrow$ `RECEIVED_BY_SERVER` $\rightarrow$ `DISPATCHED` $\rightarrow$ `RESOLVED`.
   - Higher status state strictly supersedes lower status state regardless of timestamp.

2. **Occupancy & Capacity (Shelters)**:
   - Maximum timestamp (`updated_at`) wins (Last-Write-Wins).
   - In case of exact timestamp ties, server evaluates higher counter or deterministic Lexicographical comparison of `client_id`.

3. **Additive Relay Path Set**:
   - `relay_path` arrays are merged as a Grow-Only Set (G-Set union). Every device that participated in relaying an SOS is preserved without omission.

---

## 4. Audit & History

When a concurrent conflict is resolved server-side using LWW rules, an audit entry is written to `sync_conflicts_audit` table:
- `id`: Primary key
- `entity_type`: Table name
- `entity_id`: Record key
- `winning_payload`: JSON string of chosen state
- `losing_payload`: JSON string of discarded state
- `client_id`: ID of submitted client
- `timestamp`: Time conflict occurred

---

## 5. Local Storage Sync Queue (`sync_queue`) Lifecycle

On Mobile Device:
1. User modifies local DB record (e.g. sends SOS, updates shelter count).
2. Database trigger or helper inserts row into `sync_queue`: `(entity_type, entity_id, op, payload_json, vector_clock, created_at)`.
3. Sync worker runs when network status becomes `connected`.
4. Queue items are posted to `/api/v1/sync/push`.
5. Upon server HTTP 200 response with confirmation IDs, mobile deletes corresponding rows from `sync_queue`.
