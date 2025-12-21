from pydantic import BaseModel, EmailStr, UUID4, Field
from typing import Optional

class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None

class UserCreate(UserBase):
    password: str = Field(..., min_length=8, max_length=128, description="Password must be between 8 and 128 characters")

class UserLogin(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=128)

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

class OTPVerify(BaseModel):
    email: EmailStr
    otp_code: str

class ResendOTP(BaseModel):
    email: EmailStr

class ChangePassword(BaseModel):
    current_password: str = Field(..., min_length=1)
    new_password: str = Field(..., min_length=8, max_length=128, description="Password must be between 8 and 128 characters")

class TransactionPinRequest(BaseModel):
    current_password: str = Field(..., min_length=1, max_length=128)
    transaction_pin: str = Field(..., min_length=4, max_length=6, pattern=r'^\d{4,6}$', description="Numeric PIN between 4 and 6 digits")

class TransactionPinVerify(BaseModel):
    transaction_pin: str = Field(..., min_length=4, max_length=6, pattern=r'^\d{4,6}$')

class UserResponse(UserBase):
    id: UUID4
    is_active: bool
    
    class Config:
        from_attributes = True
