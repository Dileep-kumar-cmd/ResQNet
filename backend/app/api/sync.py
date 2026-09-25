from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.db.database import get_db
from app.db.models import Shelter
from app.schemas.sync import SyncPushRequest, SyncPushResponse
from app.crdt.crdt_engine import CRDTMergeEngine
from app.api.alerts import alert_manager

router = APIRouter()

@router.get("/shelters")
async def get_sync_shelters(db: AsyncSession = Depends(get_db)):
    """Allows clients to fetch latest active shelters."""
    result = await db.execute(select(Shelter))
    shelters = result.scalars().all()
    return [
        {
            "id": s.id,
            "name": s.name,
            "latitude": s.latitude,
            "longitude": s.longitude,
            "capacity": s.capacity,
            "current_occupancy": s.current_occupancy,
            "hazard_rating": s.hazard_rating,
            "equipment_json": s.equipment_json or {},
            "updated_at": s.updated_at.isoformat() if s.updated_at else None
        }
        for s in shelters
    ]

@router.post("/push", response_model=SyncPushResponse)
async def push_sync(payload: SyncPushRequest, db: AsyncSession = Depends(get_db)):
    """Receives offline sync queue items from mobile client and merges them using CRDT & LWW rules."""
    changes_dicts = [c.model_dump() for c in payload.changes]
    
    processed, conflicts, server_v_clock = await CRDTMergeEngine.process_sync_batch(
        db=db,
        client_id=payload.client_id,
        client_vector_clock=payload.vector_clock,
        changes=changes_dicts
    )

    # Broadcast emergency SOS packets to admin dashboard & responders immediately
    for change in changes_dicts:
        if change.get("entity_type") == "sos_logs":
            raw_payload = change.get("payload", {})
            sos_data = {
                "id": change.get("entity_id"),
                "user_id": raw_payload.get("user_id", payload.client_id),
                "latitude": raw_payload.get("latitude", 37.7749),
                "longitude": raw_payload.get("longitude", -122.4194),
                "status": raw_payload.get("status", "QUEUED"),
                "medical_note": raw_payload.get("medical_note", "Emergency SOS reported"),
                "synced_bool": True,
                "timestamp": change.get("timestamp")
            }
            await alert_manager.broadcast_sos(sos_data)

    return SyncPushResponse(
        status="SUCCESS",
        server_vector_clock=server_v_clock,
        processed_count=processed,
        conflicts_resolved=conflicts,
        server_changes=[]
    )
