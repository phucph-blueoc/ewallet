from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class NotificationBase(BaseModel):
    title: str
    message: str
    type: str = Field(..., pattern="^(TRANSACTION|PROMOTION|SECURITY|ALERT)$")
    data: Optional[str] = None  # JSON string

class NotificationResponse(NotificationBase):
    id: str
    user_id: str
    is_read: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

class NotificationSettingsBase(BaseModel):
    enable_transaction_notifications: bool = True
    enable_promotion_notifications: bool = True
    enable_security_notifications: bool = True
    enable_alert_notifications: bool = True

class NotificationSettingsResponse(NotificationSettingsBase):
    id: str
    user_id: str
    device_token: Optional[str] = None
    device_type: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class NotificationSettingsUpdate(BaseModel):
    enable_transaction_notifications: Optional[bool] = None
    enable_promotion_notifications: Optional[bool] = None
    enable_security_notifications: Optional[bool] = None
    enable_alert_notifications: Optional[bool] = None

class DeviceRegistrationRequest(BaseModel):
    device_token: str = Field(..., min_length=1)
    device_type: str = Field(..., pattern="^(IOS|ANDROID|WEB)$")

