import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from sqlalchemy import String, Integer, Float, DateTime, Boolean, JSON
from sqlalchemy.orm import Mapped, mapped_column
from app.db.database import Base

def generate_uuid() -> str:
    return str(uuid.uuid4())

class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=generate_uuid)
    email: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String, nullable=False)
    role: Mapped[str] = mapped_column(String, default="CITIZEN")  # CITIZEN, FIRST_RESPONDER, ADMIN
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

class Shelter(Base):
    __tablename__ = "shelters"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=generate_uuid)
    name: Mapped[str] = mapped_column(String, nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    capacity: Mapped[int] = mapped_column(Integer, nullable=False, default=100)
    current_occupancy: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    hazard_rating: Mapped[int] = mapped_column(Integer, nullable=False, default=0)  # 0 to 5
    equipment_json: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True, default=dict)
    updated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    vector_clock: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True, default=dict)

class MedicalInfra(Base):
    __tablename__ = "medical_infra"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=generate_uuid)
    name: Mapped[str] = mapped_column(String, nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    type: Mapped[str] = mapped_column(String, nullable=False)  # HOSPITAL, CLINIC, AID_STATION
    capacity: Mapped[int] = mapped_column(Integer, nullable=False, default=50)

class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=generate_uuid)
    name: Mapped[str] = mapped_column(String, nullable=False)
    type: Mapped[str] = mapped_column(String, nullable=False)  # FIRE, POLICE, MEDICAL, DISASTER_HQ
    phone: Mapped[str] = mapped_column(String, nullable=False)
    latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

class SOSLog(Base):
    __tablename__ = "sos_logs"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=generate_uuid)
    user_id: Mapped[str] = mapped_column(String, nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, default="QUEUED")  # QUEUED, RELAYED, RECEIVED, RESOLVED
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    synced_bool: Mapped[bool] = mapped_column(Boolean, default=True)
    relay_path_json: Mapped[Optional[List[Any]]] = mapped_column(JSON, nullable=True, default=list)
    vector_clock: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True, default=dict)

class SyncConflictAudit(Base):
    __tablename__ = "sync_conflicts_audit"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=generate_uuid)
    entity_type: Mapped[str] = mapped_column(String, nullable=False)
    entity_id: Mapped[str] = mapped_column(String, nullable=False)
    winning_payload: Mapped[Dict[str, Any]] = mapped_column(JSON, nullable=False)
    losing_payload: Mapped[Dict[str, Any]] = mapped_column(JSON, nullable=False)
    client_id: Mapped[str] = mapped_column(String, nullable=False)
    resolved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
