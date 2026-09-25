import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.db.database import engine, Base


@pytest.mark.asyncio
async def test_health_check():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "ResQNet Backend"

@pytest.mark.asyncio
async def test_user_registration_and_login():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Register user
        reg_payload = {
            "email": "rescuer@resqnet.org",
            "name": "Rescue Lead",
            "password": "EmergencyPassword2026!",
            "role": "FIRST_RESPONDER"
        }
        response = await ac.post("/api/v1/auth/register", json=reg_payload)
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["user"]["email"] == "rescuer@resqnet.org"

        # Login user
        login_payload = {
            "email": "rescuer@resqnet.org",
            "password": "EmergencyPassword2026!"
        }
        login_resp = await ac.post("/api/v1/auth/login", json=login_payload)
        assert login_resp.status_code == 200
        token_data = login_resp.json()
        assert "access_token" in token_data

@pytest.mark.asyncio
async def test_shelter_crud_and_delete():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Create shelter
        new_shelter = {
            "name": "Test Delete Shelter",
            "latitude": 37.7700,
            "longitude": -122.4200,
            "capacity": 150,
            "current_occupancy": 30,
            "hazard_rating": 0
        }
        res_create = await ac.post("/api/v1/admin/shelters", json=new_shelter)
        assert res_create.status_code == 201
        created = res_create.json()
        shelter_id = created["id"]
        assert created["name"] == "Test Delete Shelter"

        # Verify in sync shelters endpoint
        res_sync = await ac.get("/api/v1/sync/shelters")
        assert res_sync.status_code == 200
        all_sync = res_sync.json()
        assert any(s["id"] == shelter_id for s in all_sync)

        # Delete shelter
        res_del = await ac.delete(f"/api/v1/admin/shelters/{shelter_id}")
        assert res_del.status_code == 200
        assert res_del.json()["status"] == "success"

        # Verify not found on subsequent delete
        res_del404 = await ac.delete(f"/api/v1/admin/shelters/{shelter_id}")
        assert res_del404.status_code == 404
