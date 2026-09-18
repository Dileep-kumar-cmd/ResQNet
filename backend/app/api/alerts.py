import json
import logging
from datetime import datetime, timezone
from typing import List, Dict, Any
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

logger = logging.getLogger("resqnet.alerts")

router = APIRouter()

class AlertConnectionManager:
    """Manages real-time WebSocket connections for SOS alerts to Admin Dashboard and Responders."""
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"[ALERTS_WS] Client connected. Active clients: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
            logger.info(f"[ALERTS_WS] Client disconnected. Remaining: {len(self.active_connections)}")

    async def broadcast_sos(self, sos_payload: Dict[str, Any]):
        """Broadcast an emergency SOS event to all connected dashboard and rescue clients."""
        message = {
            "type": "EMERGENCY_SOS_ALERT",
            "sound": "short_deep_emergency",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "data": sos_payload
        }
        text_data = json.dumps(message)
        logger.warning(f"[ALERTS_WS_BROADCAST] Broadcasting SOS to {len(self.active_connections)} clients: {sos_payload.get('id', 'unknown')}")

        dead_connections = []
        for connection in self.active_connections:
            try:
                await connection.send_text(text_data)
            except Exception as e:
                logger.error(f"[ALERTS_WS_ERROR] Failed to send to client: {e}")
                dead_connections.append(connection)

        for dead in dead_connections:
            self.disconnect(dead)

alert_manager = AlertConnectionManager()

@router.websocket("/ws")
async def websocket_alerts_endpoint(websocket: WebSocket):
    await alert_manager.connect(websocket)
    try:
        # Send initial connection confirmation
        await websocket.send_text(json.dumps({
            "type": "CONNECTED",
            "message": "Connected to ResQNet Emergency Alerts Stream",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }))
        while True:
            # Keep socket alive and accept ping/pong or client messages
            data = await websocket.receive_text()
            try:
                parsed = json.loads(data)
                if parsed.get("type") == "PING":
                    await websocket.send_text(json.dumps({"type": "PONG"}))
            except Exception:
                pass
    except WebSocketDisconnect:
        alert_manager.disconnect(websocket)
    except Exception as e:
        logger.warning(f"[ALERTS_WS] Connection terminated: {e}")
        alert_manager.disconnect(websocket)

@router.post("/broadcast")
async def manual_broadcast_sos(payload: Dict[str, Any]):
    """Manually dispatch an SOS alert over the broadcast channel."""
    await alert_manager.broadcast_sos(payload)
    return {
        "status": "SUCCESS",
        "recipients": len(alert_manager.active_connections),
        "payload": payload
    }
