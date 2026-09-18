from fastapi import APIRouter
from datetime import datetime, timezone

router = APIRouter()

@router.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "ResQNet Backend",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "mode": "ONLINE_SYNC_READY"
    }
