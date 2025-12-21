from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class SecurityHistoryResponse(BaseModel):
    id: str
    user_id: str
    action_type: str  # LOGIN, LOGOUT, PASSWORD_CHANGE, PIN_CHANGE, 2FA_ENABLE, 2FA_DISABLE, SETTINGS_CHANGE
    description: Optional[str] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    device_id: Optional[str] = None
    device_name: Optional[str] = None  # From relationship
    created_at: datetime

    class Config:
        from_attributes = True

