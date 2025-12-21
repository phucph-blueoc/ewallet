from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime

class ContactBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    email: EmailStr
    phone: Optional[str] = Field(None, max_length=20)
    avatar_url: Optional[str] = None
    notes: Optional[str] = None

class ContactCreate(ContactBase):
    pass

class ContactUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    email: Optional[EmailStr] = None
    phone: Optional[str] = Field(None, max_length=20)
    avatar_url: Optional[str] = None
    notes: Optional[str] = None

class ContactResponse(ContactBase):
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class ContactStatsResponse(BaseModel):
    contact_id: str
    contact_name: str
    total_transactions: int
    total_amount_sent: float
    total_amount_received: float
    last_transaction_date: Optional[datetime] = None
    
    class Config:
        from_attributes = True

