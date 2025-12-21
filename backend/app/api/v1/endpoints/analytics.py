from fastapi import APIRouter, Depends, HTTPException, status, Request, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_, extract
from typing import List, Optional, Dict
from datetime import datetime, date, timedelta
from collections import defaultdict

from app.core.database import get_db
from app.core.security import get_current_user
from app.core.encryption import encryption_service
from app.core.rate_limit import limiter, GENERAL_LIMIT
from app.models import User, Transaction, Wallet
from app.schemas import (
    SpendingAnalyticsRequest,
    SpendingAnalyticsResponse,
    SpendingCategorySummary,
    TrendsResponse,
    DailyBreakdownItem,
)

router = APIRouter()


def _categorize_transaction(note: str) -> str:
    """Categorize transaction based on note content."""
    if not note:
        return "OTHER"
    
    note_lower = note.lower()
    
    # Food category
    food_keywords = ["ăn", "food", "restaurant", "nhà hàng", "cafe", "quán", "bữa", "đồ ăn"]
    if any(keyword in note_lower for keyword in food_keywords):
        return "FOOD"
    
    # Shopping category
    shopping_keywords = ["mua", "shopping", "shop", "cửa hàng", "siêu thị", "market"]
    if any(keyword in note_lower for keyword in shopping_keywords):
        return "SHOPPING"
    
    # Bills category
    bills_keywords = ["hóa đơn", "bill", "điện", "nước", "internet", "điện thoại", "cước"]
    if any(keyword in note_lower for keyword in bills_keywords):
        return "BILLS"
    
    # Transport category
    transport_keywords = ["xe", "taxi", "grab", "uber", "transport", "xăng", "đổ xăng"]
    if any(keyword in note_lower for keyword in transport_keywords):
        return "TRANSPORT"
    
    # Entertainment category
    entertainment_keywords = ["giải trí", "entertainment", "phim", "game", "cinema", "karaoke"]
    if any(keyword in note_lower for keyword in entertainment_keywords):
        return "ENTERTAINMENT"
    
    # Health category
    health_keywords = ["sức khỏe", "health", "bệnh viện", "thuốc", "pharmacy", "hospital"]
    if any(keyword in note_lower for keyword in health_keywords):
        return "HEALTH"
    
    # Education category
    education_keywords = ["học", "education", "trường", "sách", "school", "book"]
    if any(keyword in note_lower for keyword in education_keywords):
        return "EDUCATION"
    
    return "OTHER"


@router.get("/spending", response_model=SpendingAnalyticsResponse)
@limiter.limit(GENERAL_LIMIT)
async def get_spending_analytics(
    request: Request,
    period: str = Query(default="month", pattern="^(day|week|month|year)$"),
    year: Optional[int] = Query(None, ge=2000, le=2100),
    month: Optional[int] = Query(None, ge=1, le=12),
    category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get spending analytics for a period.
    
    - Returns spending breakdown by category
    - Supports day, week, month, year periods
    """
    # Determine date range
    now = datetime.utcnow()
    if year is None:
        year = now.year
    if month is None:
        month = now.month
    
    if period == "day":
        start_date = date(year, month, now.day if month == now.month and year == now.year else 1)
        end_date = start_date + timedelta(days=1)
    elif period == "week":
        # Get start of week (Monday)
        start_date = date(year, month, now.day if month == now.month and year == now.year else 1)
        days_since_monday = start_date.weekday()
        start_date = start_date - timedelta(days=days_since_monday)
        end_date = start_date + timedelta(days=7)
    elif period == "month":
        start_date = date(year, month, 1)
        if month == 12:
            end_date = date(year + 1, 1, 1)
        else:
            end_date = date(year, month + 1, 1)
    else:  # year
        start_date = date(year, 1, 1)
        end_date = date(year + 1, 1, 1)
    
    # Get all transactions where user is sender (spending)
    query = db.query(Transaction).filter(
        Transaction.sender_id == current_user.id,
        Transaction.timestamp >= datetime.combine(start_date, datetime.min.time()),
        Transaction.timestamp < datetime.combine(end_date, datetime.min.time())
    )
    
    transactions = query.all()
    
    # Get all transactions where user is receiver (income)
    income_query = db.query(Transaction).filter(
        Transaction.receiver_id == current_user.id,
        Transaction.sender_id.isnot(None),  # Exclude deposits
        Transaction.timestamp >= datetime.combine(start_date, datetime.min.time()),
        Transaction.timestamp < datetime.combine(end_date, datetime.min.time())
    )
    income_transactions = income_query.all()
    
    # Calculate spending by category
    category_totals = defaultdict(lambda: {"amount": 0.0, "count": 0})
    
    for tx in transactions:
        # Decrypt note
        try:
            note = encryption_service.decrypt(tx.encrypted_note) if tx.encrypted_note else ""
        except:
            note = ""
        
        tx_category = _categorize_transaction(note)
        
        if category and tx_category != category:
            continue
        
        category_totals[tx_category]["amount"] += tx.amount
        category_totals[tx_category]["count"] += 1
    
    # Calculate totals
    total_spending = sum(tx.amount for tx in transactions)
    total_income = sum(tx.amount for tx in income_transactions)
    net_amount = total_income - total_spending
    
    # Build category summaries
    category_summaries = []
    for cat, data in category_totals.items():
        percentage = (data["amount"] / total_spending * 100) if total_spending > 0 else 0
        category_summaries.append(SpendingCategorySummary(
            category=cat,
            total_amount=data["amount"],
            transaction_count=data["count"],
            percentage=round(percentage, 2)
        ))
    
    # Sort by amount descending
    category_summaries.sort(key=lambda x: x.total_amount, reverse=True)
    
    # Daily breakdown (for month and year periods)
    daily_breakdown = None
    if period in ["month", "year"]:
        daily_totals = defaultdict(float)
        for tx in transactions:
            tx_date = tx.timestamp.date()
            daily_totals[tx_date.isoformat()] += tx.amount
        
        daily_breakdown = [
            DailyBreakdownItem(date=date_str, amount=amount)
            for date_str, amount in sorted(daily_totals.items())
        ]
    
    return SpendingAnalyticsResponse(
        period=period,
        start_date=start_date,
        end_date=end_date - timedelta(days=1),  # End date is exclusive
        total_spending=total_spending,
        total_income=total_income,
        net_amount=net_amount,
        transaction_count=len(transactions),
        categories=category_summaries,
        daily_breakdown=daily_breakdown
    )


@router.get("/trends", response_model=TrendsResponse)
@limiter.limit(GENERAL_LIMIT)
async def get_spending_trends(
    request: Request,
    period: str = Query(default="month", pattern="^(week|month|year)$"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get spending trends comparing current period with previous period.
    """
    now = datetime.utcnow()
    
    # Calculate current period
    if period == "week":
        days_since_monday = now.weekday()
        current_start = (now - timedelta(days=days_since_monday)).date()
        current_end = current_start + timedelta(days=7)
        previous_start = current_start - timedelta(days=7)
        previous_end = current_start
    elif period == "month":
        current_start = date(now.year, now.month, 1)
        if now.month == 12:
            current_end = date(now.year + 1, 1, 1)
        else:
            current_end = date(now.year, now.month + 1, 1)
        # Previous month
        if now.month == 1:
            previous_start = date(now.year - 1, 12, 1)
            previous_end = date(now.year, 1, 1)
        else:
            previous_start = date(now.year, now.month - 1, 1)
            previous_end = date(now.year, now.month, 1)
    else:  # year
        current_start = date(now.year, 1, 1)
        current_end = date(now.year + 1, 1, 1)
        previous_start = date(now.year - 1, 1, 1)
        previous_end = date(now.year, 1, 1)
    
    # Get current period spending
    current_query = db.query(func.sum(Transaction.amount)).filter(
        Transaction.sender_id == current_user.id,
        Transaction.timestamp >= datetime.combine(current_start, datetime.min.time()),
        Transaction.timestamp < datetime.combine(current_end, datetime.min.time())
    )
    current_amount = current_query.scalar() or 0.0
    
    # Get previous period spending
    previous_query = db.query(func.sum(Transaction.amount)).filter(
        Transaction.sender_id == current_user.id,
        Transaction.timestamp >= datetime.combine(previous_start, datetime.min.time()),
        Transaction.timestamp < datetime.combine(previous_end, datetime.min.time())
    )
    previous_amount = previous_query.scalar() or 0.0
    
    # Calculate change
    if previous_amount == 0:
        change_percentage = 100.0 if current_amount > 0 else 0.0
    else:
        change_percentage = ((current_amount - previous_amount) / previous_amount) * 100
    
    # Determine trend
    if abs(change_percentage) < 5:
        trend = "stable"
    elif change_percentage > 0:
        trend = "up"
    else:
        trend = "down"
    
    return TrendsResponse(
        period=period,
        current_period_amount=current_amount,
        previous_period_amount=previous_amount,
        change_percentage=round(change_percentage, 2),
        trend=trend
    )

