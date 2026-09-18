from pydantic import BaseModel
from typing import List, Dict, Any, Optional

class SyncEntityChange(BaseModel):
    entity_type: str
    entity_id: str
    op: str
    payload: Dict[str, Any]
    vector_clock: Optional[Dict[str, int]] = {}
    updated_at: Optional[str] = None

class SyncPushRequest(BaseModel):
    client_id: str
    vector_clock: Dict[str, int]
    last_synced_at: Optional[str] = None
    changes: List[SyncEntityChange]

class SyncPushResponse(BaseModel):
    status: str
    server_vector_clock: Dict[str, int]
    processed_count: int
    conflicts_resolved: int
    server_changes: List[SyncEntityChange] = []
