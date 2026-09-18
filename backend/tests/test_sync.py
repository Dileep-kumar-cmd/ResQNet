import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.db.database import engine, Base


@pytest.mark.asyncio
async def test_crdt_sync_push_and_admin_endpoints():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # 1. Post CRDT Sync Batch
        sync_payload = {
            "client_id": "test_device_01",
            "vector_clock": {"client_seq": 2},
            "last_synced_at": None,
            "changes": [
                {
                    "entity_type": "sos_logs",
                    "entity_id": "sos_crdt_101",
                    "op": "UPSERT",
                    "payload": {
                        "id": "sos_crdt_101",
                        "user_id": "usr_test_01",
                        "latitude": 37.7749,
                        "longitude": -122.4194,
                        "status": "QUEUED",
                        "relay_path": ["usr_test_01"]
                    },
                    "vector_clock": {"test_device_01": 1},
                    "updated_at": "2026-07-28T14:00:00Z"
                },
                {
                    "entity_type": "shelters",
                    "entity_id": "shl_crdt_201",
                    "op": "UPSERT",
                    "payload": {
                        "id": "shl_crdt_201",
                        "name": "CRDT Test Shelter",
                        "latitude": 37.7850,
                        "longitude": -122.4090,
                        "capacity": 300,
                        "current_occupancy": 120,
                        "hazard_rating": 1,
                        "equipment_json": {"generators": 2}
                    },
                    "vector_clock": {"test_device_01": 1},
                    "updated_at": "2026-07-28T14:00:00Z"
                }
            ]
        }

        response = await ac.post("/api/v1/sync/push", json=sync_payload)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "SUCCESS"
        assert data["processed_count"] == 2

        # 2. Verify Admin Shelters Endpoint
        shl_resp = await ac.get("/api/v1/admin/shelters")
        assert shl_resp.status_code == 200
        shelters_data = shl_resp.json()
        assert len(shelters_data) == 1
        assert shelters_data[0]["name"] == "CRDT Test Shelter"

        # 3. Verify Admin SOS Logs Endpoint
        sos_resp = await ac.get("/api/v1/admin/sos_logs")
        assert sos_resp.status_code == 200
        sos_data = sos_resp.json()
        assert len(sos_data) == 1
        assert sos_data[0]["status"] == "QUEUED"

        # 4. Perform Lattice Status Update Conflict
        update_payload = {
            "client_id": "test_device_02",
            "vector_clock": {"client_seq": 1},
            "changes": [
                {
                    "entity_type": "sos_logs",
                    "entity_id": "sos_crdt_101",
                    "op": "UPDATE_STATUS",
                    "payload": {
                        "status": "DISPATCHED",
                        "relay_path": ["usr_test_01", "usr_node_02"]
                    },
                    "vector_clock": {"test_device_02": 1},
                    "updated_at": "2026-07-28T14:05:00Z"
                }
            ]
        }
        update_resp = await ac.post("/api/v1/sync/push", json=update_payload)
        assert update_resp.status_code == 200
        update_data = update_resp.json()
        assert update_data["conflicts_resolved"] == 1

        # 5. Verify Conflicts Audit Log
        audit_resp = await ac.get("/api/v1/admin/conflicts_audit")
        assert audit_resp.status_code == 200
        audit_data = audit_resp.json()
        assert len(audit_data) == 1
        assert audit_data[0]["entity_type"] == "sos_logs"
