from pydantic import BaseModel, Field
from typing import Optional, List, Dict
from datetime import datetime, date

class SpendingCategorySummary(BaseModel):
    category: str
    total_amount: float
    transaction_count: int
    percentage: float = Field(..., ge=0, le=100, description="Percentage of total spending")

class SpendingPeriodSummary(BaseModel):
    period: str  # e.g., "2024-01", "2024-Q1", "2024"
    total_amount: float
    transaction_count: int
    categories: List[SpendingCategorySummary]

class SpendingAnalyticsRequest(BaseModel):
    period: str = Field(default="month", pattern="^(day|week|month|year)$")
    year: Optional[int] = Field(None, ge=2000, le=2100)
    month: Optional[int] = Field(None, ge=1, le=12)
    category: Optional[str] = None

class DailyBreakdownItem(BaseModel):
    date: str  # ISO date string like "2024-01-01"
    amount: float

class SpendingAnalyticsResponse(BaseModel):
    period: str
    start_date: date
    end_date: date
    total_spending: float
    total_income: float
    net_amount: float
    transaction_count: int
    categories: List[SpendingCategorySummary]
    daily_breakdown: Optional[List[DailyBreakdownItem]] = None

class BudgetComparisonResponse(BaseModel):
    category: str
    budget_amount: float
    spent_amount: float
    remaining_amount: float
    percentage_used: float
    is_over_budget: bool

class TrendsResponse(BaseModel):
    period: str
    current_period_amount: float
    previous_period_amount: float
    change_percentage: float
    trend: str = Field(..., pattern="^(up|down|stable)$")

