from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import datetime
import re

class BankCardBase(BaseModel):
    card_holder_name: str = Field(..., min_length=1, max_length=255)
    bank_name: str = Field(..., min_length=1, max_length=100)
    card_type: str = Field(..., pattern=r'^(VISA|MASTERCARD|ATM)$')

class BankCardCreate(BankCardBase):
    card_number: str = Field(..., min_length=13, max_length=19)
    expiry_date: str = Field(..., pattern=r'^\d{2}/\d{2}$')  # MM/YY format
    cvv: str = Field(..., min_length=3, max_length=4, pattern=r'^\d{3,4}$')

    @validator('card_number')
    def validate_card_number(cls, v):
        # Remove spaces and dashes
        v = re.sub(r'[\s-]', '', v)
        # Check if all digits
        if not v.isdigit():
            raise ValueError('Card number must contain only digits')
        # Luhn algorithm check (simplified - just check length and format)
        if len(v) < 13 or len(v) > 19:
            raise ValueError('Card number must be between 13 and 19 digits')
        return v

    @validator('expiry_date')
    def validate_expiry_date(cls, v):
        parts = v.split('/')
        if len(parts) != 2:
            raise ValueError('Expiry date must be in MM/YY format')
        month = int(parts[0])
        year = int(parts[1])
        if month < 1 or month > 12:
            raise ValueError('Month must be between 01 and 12')
        if year < 0 or year > 99:
            raise ValueError('Year must be between 00 and 99')
        return v

class BankCardUpdate(BaseModel):
    card_holder_name: Optional[str] = Field(None, min_length=1, max_length=255)
    bank_name: Optional[str] = Field(None, min_length=1, max_length=100)

class BankCardResponse(BankCardBase):
    id: str
    user_id: str
    card_number_masked: str  # Last 4 digits only
    expiry_date_masked: str  # MM/YY format (not encrypted in response)
    is_verified: bool
    created_at: datetime

    class Config:
        from_attributes = True

class BankCardVerifyRequest(BaseModel):
    otp_code: str = Field(..., min_length=6, max_length=6, pattern=r'^\d{6}$')

class DepositFromCardRequest(BaseModel):
    card_id: str
    amount: float = Field(..., gt=0)
    transaction_pin: str = Field(..., min_length=4, max_length=6, pattern=r'^\d{4,6}$')

class WithdrawToCardRequest(BaseModel):
    card_id: str
    amount: float = Field(..., gt=0)
    transaction_pin: str = Field(..., min_length=4, max_length=6, pattern=r'^\d{4,6}$')

