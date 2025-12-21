from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime, date

class SavingsGoalBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    target_amount: float = Field(..., gt=0, description="Target amount must be greater than 0")
    deadline: Optional[date] = None
    auto_deposit_amount: Optional[float] = Field(None, gt=0, description="Auto deposit amount per month")

class SavingsGoalCreate(SavingsGoalBase):
    pass

class SavingsGoalUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    target_amount: Optional[float] = Field(None, gt=0)
    deadline: Optional[date] = None
    auto_deposit_amount: Optional[float] = Field(None, gt=0)
    is_completed: Optional[bool] = None

class SavingsGoalResponse(SavingsGoalBase):
    id: str
    user_id: str
    current_amount: float
    is_completed: bool
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class SavingsGoalDepositRequest(BaseModel):
    amount: float = Field(..., gt=0, description="Amount to deposit into savings goal")

class SavingsGoalWithdrawRequest(BaseModel):
    amount: float = Field(..., gt=0, description="Amount to withdraw from savings goal")

