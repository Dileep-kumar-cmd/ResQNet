from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from datetime import datetime, timezone
from app.core.config import settings
from app.db.database import engine, Base, AsyncSessionLocal
from app.db.models import User, Shelter, SOSLog
from app.core.security import hash_password
from sqlalchemy.future import select
from app.api import health, auth, sync, admin, alerts

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize DB tables on startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # Auto-seed default responder user, shelters, and SOS logs if DB is empty
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User).filter(User.email == "rescuer@resqnet.org"))
        existing_user = result.scalars().first()
        if not existing_user:
            default_user = User(
                email="rescuer@resqnet.org",
                name="Rescue Lead",
                hashed_password=hash_password("EmergencyPassword2026!"),
                role="RESCUER"
            )
            session.add(default_user)

        # Seed initial shelters if empty
        shelter_check = await session.execute(select(Shelter))
        if not shelter_check.scalars().first():
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
                session.add(s)

        # Seed initial SOS logs if empty
        sos_check = await session.execute(select(SOSLog))
        if not sos_check.scalars().first():
            now_time = datetime.now(timezone.utc)
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
                session.add(l)

        await session.commit()
    yield

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

# CORS Middleware configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, prefix=settings.API_V1_STR, tags=["Health"])
app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["Auth"])
app.include_router(sync.router, prefix=f"{settings.API_V1_STR}/sync", tags=["Sync"])
app.include_router(admin.router, prefix=f"{settings.API_V1_STR}/admin", tags=["Admin"])
app.include_router(alerts.router, prefix=f"{settings.API_V1_STR}/alerts", tags=["Alerts"])

@app.get("/")
async def root():
    return {
        "title": settings.PROJECT_NAME,
        "docs": "/docs",
        "health": f"{settings.API_V1_STR}/health"
    }
