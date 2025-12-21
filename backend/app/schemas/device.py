from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class UserDeviceBase(BaseModel):
    device_name: str
    device_type: str = Field(..., pattern=r'^(IOS|ANDROID|WEB)$')
    device_token: Optional[str] = None

class UserDeviceCreate(UserDeviceBase):
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None

class UserDeviceRename(BaseModel):
    device_name: str = Field(..., min_length=1, max_length=255)

class UserDeviceResponse(UserDeviceBase):
    id: str
    user_id: str
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    last_login: datetime
    created_at: datetime
    is_active: bool

    class Config:
        from_attributes = True

