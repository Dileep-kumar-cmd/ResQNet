import uuid
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.db.database import get_db
from app.db.models import Shelter, SOSLog, SyncConflictAudit
from app.api.alerts import alert_manager

router = APIRouter()

class ShelterCreate(BaseModel):
    id: Optional[str] = None
    name: str
    latitude: float
    longitude: float
    capacity: int = 100
    current_occupancy: int = 0
    hazard_rating: int = 0
    equipment_json: Optional[Dict[str, Any]] = None

class ShelterUpdate(BaseModel):
    name: Optional[str] = None
    capacity: Optional[int] = None
    current_occupancy: Optional[int] = None
    hazard_rating: Optional[int] = None
    equipment_json: Optional[Dict[str, Any]] = None

class SOSStatusUpdate(BaseModel):
    status: str

class SOSCreate(BaseModel):
    id: Optional[str] = None
    user_id: str
    latitude: float
    longitude: float
    status: str = "QUEUED"
    relay_path: Optional[List[str]] = None

@router.get("/shelters")
async def get_admin_shelters(db: AsyncSession = Depends(get_db)):
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

@router.post("/shelters", status_code=status.HTTP_201_CREATED)
async def create_admin_shelter(payload: ShelterCreate, db: AsyncSession = Depends(get_db)):
    shelter_id = payload.id or f"shl_{str(uuid.uuid4())[:8]}"
    new_shelter = Shelter(
        id=shelter_id,
        name=payload.name,
        latitude=payload.latitude,
        longitude=payload.longitude,
        capacity=payload.capacity,
        current_occupancy=payload.current_occupancy,
        hazard_rating=payload.hazard_rating,
        equipment_json=payload.equipment_json or {
            "generators": 1,
            "clean_water_liters": 2500,
            "first_aid_kits": 25,
            "food_meals": payload.capacity * 3
        },
        updated_at=datetime.now(timezone.utc)
    )
    db.add(new_shelter)
    await db.commit()
    await db.refresh(new_shelter)
    return {
        "id": new_shelter.id,
        "name": new_shelter.name,
        "latitude": new_shelter.latitude,
        "longitude": new_shelter.longitude,
        "capacity": new_shelter.capacity,
        "current_occupancy": new_shelter.current_occupancy,
        "hazard_rating": new_shelter.hazard_rating,
        "equipment_json": new_shelter.equipment_json,
        "updated_at": new_shelter.updated_at.isoformat() if new_shelter.updated_at else None
    }

@router.patch("/shelters/{shelter_id}")
async def update_admin_shelter(shelter_id: str, payload: ShelterUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Shelter).filter(Shelter.id == shelter_id))
    shelter = result.scalars().first()
    if not shelter:
        raise HTTPException(status_code=404, detail="Shelter not found")

    if payload.name is not None:
        shelter.name = payload.name
    if payload.capacity is not None:
        shelter.capacity = payload.capacity
    if payload.current_occupancy is not None:
        shelter.current_occupancy = payload.current_occupancy
    if payload.hazard_rating is not None:
        shelter.hazard_rating = payload.hazard_rating
    if payload.equipment_json is not None:
        shelter.equipment_json = payload.equipment_json

    shelter.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(shelter)
    return {
        "id": shelter.id,
        "name": shelter.name,
        "latitude": shelter.latitude,
        "longitude": shelter.longitude,
        "capacity": shelter.capacity,
        "current_occupancy": shelter.current_occupancy,
        "hazard_rating": shelter.hazard_rating,
        "equipment_json": shelter.equipment_json or {},
        "updated_at": shelter.updated_at.isoformat() if shelter.updated_at else None
    }

@router.delete("/shelters/{shelter_id}")
async def delete_admin_shelter(shelter_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Shelter).filter(Shelter.id == shelter_id))
    shelter = result.scalars().first()
    if not shelter:
        raise HTTPException(status_code=404, detail="Shelter not found")
    await db.delete(shelter)
    await db.commit()
    return {"status": "success", "message": f"Shelter {shelter_id} deleted"}

@router.get("/sos_logs")
async def get_admin_sos_logs(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(SOSLog).order_by(SOSLog.timestamp.desc()))
    logs = result.scalars().all()
    return [
        {
            "id": l.id,
            "user_id": l.user_id,
            "latitude": l.latitude,
            "longitude": l.longitude,
            "status": l.status,
            "synced_bool": l.synced_bool,
            "relay_path": l.relay_path_json or [],
            "timestamp": l.timestamp.isoformat() if l.timestamp else None
        }
        for l in logs
    ]

@router.post("/sos_logs", status_code=status.HTTP_201_CREATED)
async def create_admin_sos_log(payload: SOSCreate, db: AsyncSession = Depends(get_db)):
    sos_id = payload.id or f"sos_{str(uuid.uuid4())[:8]}"
    new_sos = SOSLog(
        id=sos_id,
        user_id=payload.user_id,
        latitude=payload.latitude,
        longitude=payload.longitude,
        status=payload.status,
        synced_bool=True,
        relay_path_json=payload.relay_path or ["node_direct_admin"],
        timestamp=datetime.now(timezone.utc)
    )
    db.add(new_sos)
    await db.commit()
    await db.refresh(new_sos)

    sos_dict = {
        "id": new_sos.id,
        "user_id": new_sos.user_id,
        "latitude": new_sos.latitude,
        "longitude": new_sos.longitude,
        "status": new_sos.status,
        "synced_bool": new_sos.synced_bool,
        "relay_path": new_sos.relay_path_json or [],
        "timestamp": new_sos.timestamp.isoformat() if new_sos.timestamp else None
    }
    await alert_manager.broadcast_sos(sos_dict)
    return sos_dict

@router.patch("/sos_logs/{sos_id}")
async def update_admin_sos_status(sos_id: str, payload: SOSStatusUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(SOSLog).filter(SOSLog.id == sos_id))
    sos = result.scalars().first()
    if not sos:
        raise HTTPException(status_code=404, detail="SOS Log not found")

    sos.status = payload.status
    await db.commit()
    await db.refresh(sos)
    return {
        "id": sos.id,
        "user_id": sos.user_id,
        "latitude": sos.latitude,
        "longitude": sos.longitude,
        "status": sos.status,
        "synced_bool": sos.synced_bool,
        "relay_path": sos.relay_path_json or [],
        "timestamp": sos.timestamp.isoformat() if sos.timestamp else None
    }

@router.get("/conflicts_audit")
async def get_admin_conflicts(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(SyncConflictAudit).order_by(SyncConflictAudit.resolved_at.desc()))
    audits = result.scalars().all()
    return [
        {
            "id": a.id,
            "entity_type": a.entity_type,
            "entity_id": a.entity_id,
            "winning_payload": a.winning_payload,
            "losing_payload": a.losing_payload,
            "client_id": a.client_id,
            "resolved_at": a.resolved_at.isoformat() if a.resolved_at else None
        }
        for a in audits
    ]

@router.post("/seed_demo")
async def seed_demo_data(db: AsyncSession = Depends(get_db)):
    now_time = datetime.now(timezone.utc)
    sample_shelters = [
        Shelter(
            id="shl_001",
            name="Civic Community Shelter",
            latitude=37.7812,
            longitude=-122.4160,
            capacity=250,
            current_occupancy=85,
            hazard_rating=1,
            equipment_json={"generators": 2, "clean_water_liters": 5000, "first_aid_kits": 40, "food_meals": 1200},
            updated_at=now_time
        ),
        Shelter(
            id="shl_002",
            name="North Hill High School Shelter",
            latitude=37.7850,
            longitude=-122.4090,
            capacity=500,
            current_occupancy=320,
            hazard_rating=0,
            equipment_json={"generators": 4, "clean_water_liters": 12000, "first_aid_kits": 100, "food_meals": 3000},
            updated_at=now_time
        ),
        Shelter(
            id="shl_003",
            name="Eastside Sports Arena",
            latitude=37.7650,
            longitude=-122.3950,
            capacity=400,
            current_occupancy=385,
            hazard_rating=2,
            equipment_json={"generators": 3, "clean_water_liters": 4500, "first_aid_kits": 30, "food_meals": 850},
            updated_at=now_time
        ),
        Shelter(
            id="shl_004",
            name="South Waterfront Aid Station",
            latitude=37.7550,
            longitude=-122.4250,
            capacity=180,
            current_occupancy=45,
            hazard_rating=0,
            equipment_json={"generators": 1, "clean_water_liters": 3200, "first_aid_kits": 60, "food_meals": 900},
            updated_at=now_time
        )
    ]
    for s in sample_shelters:
        existing = await db.execute(select(Shelter).filter(Shelter.id == s.id))
        if not existing.scalars().first():
            db.add(s)

    sample_sos = [
        SOSLog(
            id="sos_101",
            user_id="usr_citizen_88",
            latitude=37.7749,
            longitude=-122.4194,
            status="QUEUED",
            synced_bool=True,
            relay_path_json=["node_alpha", "node_beta"],
            timestamp=now_time
        ),
        SOSLog(
            id="sos_102",
            user_id="usr_field_medic_04",
            latitude=37.7850,
            longitude=-122.4090,
            status="DISPATCHED",
            synced_bool=True,
            relay_path_json=["node_gamma"],
            timestamp=now_time
        ),
        SOSLog(
            id="sos_103",
            user_id="usr_responder_12",
            latitude=37.7690,
            longitude=-122.4280,
            status="RESOLVED",
            synced_bool=True,
            relay_path_json=["node_mesh_01", "node_alpha"],
            timestamp=now_time
        )
    ]
    for l in sample_sos:
        existing = await db.execute(select(SOSLog).filter(SOSLog.id == l.id))
        if not existing.scalars().first():
            db.add(l)

    await db.commit()
    return {"status": "SUCCESS", "message": "Demo data seeded successfully"}
