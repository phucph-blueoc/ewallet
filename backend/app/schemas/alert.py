from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class AlertBase(BaseModel):
    type: str = Field(..., pattern="^(LARGE_TRANSACTION|LOW_BALANCE|BUDGET_WARNING|NEW_DEVICE)$")
    title: str
    message: str
    severity: str = Field(default="INFO", pattern="^(INFO|WARNING|CRITICAL)$")
    data: Optional[str] = None  # JSON string

class AlertResponse(AlertBase):
    id: str
    user_id: str
    is_read: bool
    created_at: datetime
    
    class Config:
        from_attributes = True

class AlertSettingsBase(BaseModel):
    large_transaction_threshold: Optional[float] = Field(None, gt=0)
    low_balance_threshold: Optional[float] = Field(None, gt=0)
    budget_warning_percentage: float = Field(default=80.0, ge=0, le=100)
    enable_large_transaction_alert: bool = True
    enable_low_balance_alert: bool = True
    enable_budget_alert: bool = True
    enable_new_device_alert: bool = True

class AlertSettingsResponse(AlertSettingsBase):
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class AlertSettingsUpdate(BaseModel):
    large_transaction_threshold: Optional[float] = Field(None, gt=0)
    low_balance_threshold: Optional[float] = Field(None, gt=0)
    budget_warning_percentage: Optional[float] = Field(None, ge=0, le=100)
    enable_large_transaction_alert: Optional[bool] = None
    enable_low_balance_alert: Optional[bool] = None
    enable_budget_alert: Optional[bool] = None
    enable_new_device_alert: Optional[bool] = None

