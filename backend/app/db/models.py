import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Integer, Float, DateTime, Boolean, Text, JSON
from app.db.database import Base

def generate_uuid():
    return str(uuid.uuid4())

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=generate_uuid)
    email = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=False)
    hashed_password = Column(String, nullable=False)
    role = Column(String, default="CITIZEN")  # CITIZEN, FIRST_RESPONDER, ADMIN
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

class Shelter(Base):
    __tablename__ = "shelters"

    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    capacity = Column(Integer, nullable=False, default=100)
    current_occupancy = Column(Integer, nullable=False, default=0)
    hazard_rating = Column(Integer, nullable=False, default=0)  # 0 to 5
    equipment_json = Column(JSON, nullable=True, default={})
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    vector_clock = Column(JSON, nullable=True, default={})

class MedicalInfra(Base):
    __tablename__ = "medical_infra"

    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    type = Column(String, nullable=False)  # HOSPITAL, CLINIC, AID_STATION
    capacity = Column(Integer, nullable=False, default=50)

class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"

    id = Column(String, primary_key=True, default=generate_uuid)
    name = Column(String, nullable=False)
    type = Column(String, nullable=False)  # FIRE, POLICE, MEDICAL, DISASTER_HQ
    phone = Column(String, nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)

class SOSLog(Base):
    __tablename__ = "sos_logs"

    id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    status = Column(String, nullable=False, default="QUEUED")  # QUEUED, RELAYED, RECEIVED, RESOLVED
    timestamp = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    synced_bool = Column(Boolean, default=True)
    relay_path_json = Column(JSON, nullable=True, default=[])
    vector_clock = Column(JSON, nullable=True, default={})

class SyncConflictAudit(Base):
    __tablename__ = "sync_conflicts_audit"

    id = Column(String, primary_key=True, default=generate_uuid)
    entity_type = Column(String, nullable=False)
    entity_id = Column(String, nullable=False)
    winning_payload = Column(JSON, nullable=False)
    losing_payload = Column(JSON, nullable=False)
    client_id = Column(String, nullable=False)
    resolved_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
