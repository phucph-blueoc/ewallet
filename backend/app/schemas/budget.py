from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class BudgetBase(BaseModel):
    category: str = Field(..., min_length=1, max_length=100)
    amount: float = Field(..., gt=0, description="Budget amount must be greater than 0")
    period: str = Field(default="MONTH", pattern="^(MONTH|YEAR)$")
    month: Optional[int] = Field(None, ge=1, le=12, description="Month (1-12) for monthly budgets")
    year: int = Field(..., ge=2000, le=2100)

class BudgetCreate(BudgetBase):
    pass

class BudgetUpdate(BaseModel):
    category: Optional[str] = Field(None, min_length=1, max_length=100)
    amount: Optional[float] = Field(None, gt=0)
    period: Optional[str] = Field(None, pattern="^(MONTH|YEAR)$")
    month: Optional[int] = Field(None, ge=1, le=12)
    year: Optional[int] = Field(None, ge=2000, le=2100)

class BudgetResponse(BudgetBase):
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class BudgetStatusResponse(BudgetResponse):
    spent_amount: float = Field(..., description="Total amount spent in this category/period")
    remaining_amount: float = Field(..., description="Remaining budget amount")
    percentage_used: float = Field(..., ge=0, le=100, description="Percentage of budget used")
    is_over_budget: bool = Field(..., description="Whether spending exceeds budget")

