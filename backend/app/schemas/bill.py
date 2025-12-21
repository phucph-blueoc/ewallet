from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

# Bill Provider Schemas
class BillProviderResponse(BaseModel):
    id: str
    name: str
    code: str
    logo_url: Optional[str] = None
    is_active: bool

    class Config:
        from_attributes = True

# Saved Bill Schemas
class SavedBillBase(BaseModel):
    provider_id: str
    customer_code: str = Field(..., min_length=1, max_length=100)
    customer_name: Optional[str] = Field(None, max_length=255)
    alias: Optional[str] = Field(None, max_length=100)

class SavedBillCreate(SavedBillBase):
    pass

class SavedBillUpdate(BaseModel):
    customer_name: Optional[str] = Field(None, max_length=255)
    alias: Optional[str] = Field(None, max_length=100)

class SavedBillResponse(BaseModel):
    id: str
    user_id: str
    provider_id: str
    provider_name: str
    customer_code: str
    customer_name: Optional[str] = None
    alias: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# Bill Check Schemas
class BillCheckRequest(BaseModel):
    provider_id: str
    customer_code: str = Field(..., min_length=1, max_length=100)

class BillInfo(BaseModel):
    customer_code: str
    customer_name: Optional[str] = None
    amount: float
    bill_period: Optional[str] = None  # e.g., "12/2024"
    due_date: Optional[datetime] = None
    description: Optional[str] = None

class BillCheckResponse(BaseModel):
    has_bill: bool
    bill_info: Optional[BillInfo] = None
    message: Optional[str] = None

# Bill Pay Schemas
class BillPayRequest(BaseModel):
    provider_id: str
    customer_code: str = Field(..., min_length=1, max_length=100)
    amount: float = Field(..., gt=0)
    transaction_pin: str = Field(..., min_length=4, max_length=6, pattern=r'^\d{4,6}$')
    save_bill: bool = Field(default=False)  # Lưu hóa đơn để thanh toán lại
    alias: Optional[str] = Field(None, max_length=100)  # Tên gợi nhớ nếu lưu

class BillPayResponse(BaseModel):
    bill_transaction_id: str
    transaction_id: str
    amount: float
    bill_period: Optional[str] = None
    paid_at: datetime

# Bill History Schemas
class BillHistoryResponse(BaseModel):
    id: str
    provider_id: str
    provider_name: str
    customer_code: str
    amount: float
    bill_period: Optional[str] = None
    transaction_id: str
    created_at: datetime

    class Config:
        from_attributes = True

