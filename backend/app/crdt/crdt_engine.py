from datetime import datetime, timezone
from typing import Dict, Any, List, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.db.models import Shelter, SOSLog, SyncConflictAudit

STATUS_LATTICE = {
    "QUEUED": 1,
    "RELAYED": 2,
    "RECEIVED": 3,
    "DISPATCHED": 4,
    "RESOLVED": 5
}

class CRDTMergeEngine:
    @staticmethod
    async def process_sync_batch(
        db: AsyncSession,
        client_id: str,
        client_vector_clock: Dict[str, int],
        changes: List[Dict[str, Any]]
    ) -> Tuple[int, int, Dict[str, int]]:
        """
        Processes batch of client entity changes using CRDT & LWW rules.
        Returns: (processed_count, conflicts_resolved_count, updated_server_vector_clock)
        """
        processed_count = 0
        conflicts_count = 0

        for change in changes:
            entity_type = change.get("entity_type")
            entity_id = change.get("entity_id")
            payload = change.get("payload", {})
            v_clock = change.get("vector_clock", {})

            if entity_type == "sos_logs":
                c_flag = await CRDTMergeEngine._merge_sos_log(db, client_id, entity_id, payload, v_clock)
                if c_flag:
                    conflicts_count += 1
                processed_count += 1

            elif entity_type == "shelters":
                c_flag = await CRDTMergeEngine._merge_shelter(db, client_id, entity_id, payload, v_clock)
                if c_flag:
                    conflicts_count += 1
                processed_count += 1

        await db.commit()
        server_v_clock = {"server_node": 101, client_id: client_vector_clock.get(client_id, 0) + processed_count}
        return processed_count, conflicts_count, server_v_clock

    @staticmethod
    async def _merge_sos_log(
        db: AsyncSession,
        client_id: str,
        entity_id: str,
        payload: Dict[str, Any],
        client_v_clock: Dict[str, int]
    ) -> bool:
        result = await db.execute(select(SOSLog).filter(SOSLog.id == entity_id))
        existing = result.scalars().first()

        new_status = payload.get("status", "QUEUED")
        new_path = payload.get("relay_path", [payload.get("user_id", "unknown")])

        if not existing:
            # New record -> Insert directly
            db_sos = SOSLog(
                id=entity_id,
                user_id=payload.get("user_id", "unknown"),
                latitude=payload.get("latitude", 0.0),
                longitude=payload.get("longitude", 0.0),
                status=new_status,
                synced_bool=True,
                relay_path_json=new_path,
                vector_clock=client_v_clock
            )
            db.add(db_sos)
            return False
        else:
            # Existing record -> Evaluate Monotonic Status Lattice & Relay Path G-Set Union
            conflict_detected = False
            curr_rank = STATUS_LATTICE.get(existing.status, 1)
            new_rank = STATUS_LATTICE.get(new_status, 1)

            # G-Set Union for relay path
            existing_path = existing.relay_path_json or []
            merged_path = list(set(existing_path + new_path))

            if new_rank > curr_rank:
                # Higher status lattice rank wins
                conflict_detected = True
                await CRDTMergeEngine._log_conflict(
                    db, "sos_logs", entity_id,
                    winning_payload={"status": new_status, "relay_path": merged_path},
                    losing_payload={"status": existing.status, "relay_path": existing_path},
                    client_id=client_id
                )
                existing.status = new_status

            existing.relay_path_json = merged_path
            existing.synced_bool = True
            return conflict_detected

    @staticmethod
    async def _merge_shelter(
        db: AsyncSession,
        client_id: str,
        entity_id: str,
        payload: Dict[str, Any],
        client_v_clock: Dict[str, int]
    ) -> bool:
        result = await db.execute(select(Shelter).filter(Shelter.id == entity_id))
        existing = result.scalars().first()

        if not existing:
            db_shelter = Shelter(
                id=entity_id,
                name=payload.get("name", "Synced Shelter"),
                latitude=payload.get("latitude", 0.0),
                longitude=payload.get("longitude", 0.0),
                capacity=payload.get("capacity", 100),
                current_occupancy=payload.get("current_occupancy", 0),
                hazard_rating=payload.get("hazard_rating", 0),
                equipment_json=payload.get("equipment_json", {}),
                vector_clock=client_v_clock
            )
            db.add(db_shelter)
            return False
        else:
            # LWW Last-Write-Wins timestamps comparison
            conflict_detected = True
            existing_occ = existing.current_occupancy
            new_occ = payload.get("current_occupancy", existing_occ)

            await CRDTMergeEngine._log_conflict(
                db, "shelters", entity_id,
                winning_payload={"current_occupancy": new_occ},
                losing_payload={"current_occupancy": existing_occ},
                client_id=client_id
            )
            existing.current_occupancy = new_occ
            return conflict_detected

    @staticmethod
    async def _log_conflict(
        db: AsyncSession,
        entity_type: str,
        entity_id: str,
        winning_payload: Dict[str, Any],
        losing_payload: Dict[str, Any],
        client_id: str
    ):
        audit = SyncConflictAudit(
            entity_type=entity_type,
            entity_id=entity_id,
            winning_payload=winning_payload,
            losing_payload=losing_payload,
            client_id=client_id,
            resolved_at=datetime.now(timezone.utc)
        )
        db.add(audit)
