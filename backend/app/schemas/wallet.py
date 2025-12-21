from pydantic import BaseModel, UUID4, Field
from typing import Optional, List
from datetime import datetime

class WalletBase(BaseModel):
    currency: str = "VND"

class WalletResponse(WalletBase):
    id: UUID4
    user_id: UUID4
    balance: float
    
    class Config:
        from_attributes = True

class TransactionBase(BaseModel):
    amount: float = Field(..., gt=0)

class DepositRequest(TransactionBase):
    source_type: str = Field(default="manual", pattern=r'^(manual|bank_card|momo|zalopay)$')  # manual, bank_card, momo, zalopay
    source_id: Optional[str] = Field(None, description="ID của thẻ ngân hàng hoặc ví điện tử")  # card_id hoặc wallet_id
    transaction_pin: Optional[str] = Field(None, min_length=4, max_length=6, pattern=r'^\d{4,6}$', description="PIN giao dịch (bắt buộc nếu dùng thẻ ngân hàng)")

class WithdrawRequest(TransactionBase):
    destination_type: str = Field(default="manual", pattern=r'^(manual|bank_card|momo|zalopay)$')  # manual, bank_card, momo, zalopay
    destination_id: Optional[str] = Field(None, description="ID của thẻ ngân hàng hoặc ví điện tử")  # card_id hoặc wallet_id
    transaction_pin: Optional[str] = Field(None, min_length=4, max_length=6, pattern=r'^\d{4,6}$', description="PIN giao dịch (bắt buộc nếu rút về thẻ ngân hàng)")

class TransferRequest(TransactionBase):
    receiver_email: str
    note: Optional[str] = None
    transaction_pin: str = Field(..., min_length=4, max_length=6, pattern=r'^\d{4,6}$')
    otp_code: str = Field(..., min_length=6, max_length=6)

class TransferOTPRequest(BaseModel):
    amount: float = Field(..., gt=0)
    receiver_email: str
    transaction_pin: str = Field(..., min_length=4, max_length=6, pattern=r'^\d{4,6}$')

class TransactionResponse(BaseModel):
    id: UUID4
    sender_id: Optional[UUID4]
    receiver_id: Optional[UUID4]
    amount: float
    timestamp: datetime
    note: Optional[str] = None # Decrypted note
    type: str # "deposit", "withdraw", "transfer_in", "transfer_out"

    class Config:
        from_attributes = True
