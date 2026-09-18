from fastapi.testclient import TestClient
from app.main import app

def test_websocket_alerts_stream():
    client = TestClient(app)
    with client.websocket_connect("/api/v1/alerts/ws") as websocket:
        init_data = websocket.receive_json()
        assert init_data["type"] == "CONNECTED"
        
        # Dispatch emergency SOS
        sos_payload = {
            "id": "sos_unit_test_999",
            "user_id": "usr_rescuer_test",
            "latitude": 37.7812,
            "longitude": -122.4160,
            "status": "QUEUED",
            "medical_note": "Immediate extraction needed",
        }
        res = client.post("/api/v1/alerts/broadcast", json=sos_payload)
        assert res.status_code == 200

        # Verify WebSocket received the alert
        alert = websocket.receive_json()
        assert alert["type"] == "EMERGENCY_SOS_ALERT"
        assert alert["sound"] == "short_deep_emergency"
        assert alert["data"]["id"] == "sos_unit_test_999"
        assert alert["data"]["user_id"] == "usr_rescuer_test"
