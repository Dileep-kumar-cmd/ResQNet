import pytest
import pytest_asyncio
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
