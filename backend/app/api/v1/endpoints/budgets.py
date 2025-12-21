from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_
from typing import List, Optional
from datetime import datetime, date

from app.core.database import get_db
from app.core.security import get_current_user
from app.core.encryption import encryption_service
from app.core.rate_limit import limiter, GENERAL_LIMIT
from app.models import User, Budget, Transaction, Wallet
from app.schemas import (
    BudgetCreate,
    BudgetUpdate,
    BudgetResponse,
    BudgetStatusResponse,
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

def _calculate_spending_for_budget(db: Session, user_id: str, budget: Budget) -> float:
    """Calculate total spending for a budget category and period."""
    # Determine date range based on period
    if budget.period == "MONTH":
        start_date = date(budget.year, budget.month, 1)
        # Get last day of month
        if budget.month == 12:
            end_date = date(budget.year + 1, 1, 1)
        else:
            end_date = date(budget.year, budget.month + 1, 1)
    else:  # YEAR
        start_date = date(budget.year, 1, 1)
        end_date = date(budget.year + 1, 1, 1)
    
    # Get all transactions where user is sender (spending) in the period
    transactions = db.query(Transaction).filter(
        Transaction.sender_id == user_id,
        Transaction.timestamp >= datetime.combine(start_date, datetime.min.time()),
        Transaction.timestamp < datetime.combine(end_date, datetime.min.time())
    ).all()
    
    # Calculate spending only for transactions matching the budget category
    total_spending = 0.0
    for tx in transactions:
        # Decrypt note to categorize transaction
        try:
            note = encryption_service.decrypt(tx.encrypted_note) if tx.encrypted_note else ""
        except:
            note = ""
        
        # Categorize transaction
        tx_category = _categorize_transaction(note)
        
        # Only count if category matches budget category
        if tx_category == budget.category:
            total_spending += tx.amount
    
    return total_spending


@router.post("", response_model=BudgetResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(GENERAL_LIMIT)
async def create_budget(
    request: Request,
    budget: BudgetCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a new budget.
    
    - Validates period and month/year combination
    - Creates budget record
    """
    # Validate month for MONTH period
    if budget.period == "MONTH" and budget.month is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Month is required for MONTH period"
        )
    
    # Check if budget already exists for this category/period
    existing = db.query(Budget).filter(
        Budget.user_id == current_user.id,
        Budget.category == budget.category,
        Budget.period == budget.period,
        Budget.year == budget.year,
        Budget.month == budget.month if budget.period == "MONTH" else True
    ).first()
    
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Budget already exists for this category and period"
        )
    
    db_budget = Budget(
        user_id=current_user.id,
        category=budget.category,
        amount=budget.amount,
        period=budget.period,
        month=budget.month,
        year=budget.year
    )
    
    db.add(db_budget)
    db.commit()
    db.refresh(db_budget)
    
    return db_budget


@router.get("", response_model=List[BudgetResponse])
@limiter.limit(GENERAL_LIMIT)
async def get_budgets(
    request: Request,
    year: Optional[int] = None,
    month: Optional[int] = None,
    category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all budgets for current user.
    
    - Optional filters: year, month, category
    """
    query = db.query(Budget).filter(Budget.user_id == current_user.id)
    
    if year:
        query = query.filter(Budget.year == year)
    if month:
        query = query.filter(Budget.month == month)
    if category:
        query = query.filter(Budget.category == category)
    
    budgets = query.order_by(Budget.year.desc(), Budget.month.desc(), Budget.category.asc()).all()
    return budgets


@router.get("/{budget_id}", response_model=BudgetStatusResponse)
@limiter.limit(GENERAL_LIMIT)
async def get_budget(
    request: Request,
    budget_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get a specific budget with spending status.
    
    - Returns budget details with spent amount and remaining amount
    """
    budget = db.query(Budget).filter(
        Budget.id == budget_id,
        Budget.user_id == current_user.id
    ).first()
    
    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found"
        )
    
    # Calculate spending
    spent_amount = _calculate_spending_for_budget(db, current_user.id, budget)
    remaining_amount = max(0, budget.amount - spent_amount)
    percentage_used = (spent_amount / budget.amount * 100) if budget.amount > 0 else 0
    is_over_budget = spent_amount > budget.amount
    
    return BudgetStatusResponse(
        id=budget.id,
        user_id=budget.user_id,
        category=budget.category,
        amount=budget.amount,
        period=budget.period,
        month=budget.month,
        year=budget.year,
        created_at=budget.created_at,
        updated_at=budget.updated_at,
        spent_amount=spent_amount,
        remaining_amount=remaining_amount,
        percentage_used=min(100, percentage_used),
        is_over_budget=is_over_budget
    )


@router.put("/{budget_id}", response_model=BudgetResponse)
@limiter.limit(GENERAL_LIMIT)
async def update_budget(
    request: Request,
    budget_id: str,
    budget_update: BudgetUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update a budget.
    """
    budget = db.query(Budget).filter(
        Budget.id == budget_id,
        Budget.user_id == current_user.id
    ).first()
    
    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found"
        )
    
    # Update fields
    if budget_update.category is not None:
        budget.category = budget_update.category
    if budget_update.amount is not None:
        budget.amount = budget_update.amount
    if budget_update.period is not None:
        budget.period = budget_update.period
    if budget_update.month is not None:
        budget.month = budget_update.month
    if budget_update.year is not None:
        budget.year = budget_update.year
    
    db.commit()
    db.refresh(budget)
    
    return budget


@router.delete("/{budget_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(GENERAL_LIMIT)
async def delete_budget(
    request: Request,
    budget_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete a budget.
    """
    budget = db.query(Budget).filter(
        Budget.id == budget_id,
        Budget.user_id == current_user.id
    ).first()
    
    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found"
        )
    
    db.delete(budget)
    db.commit()
    
    return None


@router.get("/{budget_id}/status", response_model=BudgetStatusResponse)
@limiter.limit(GENERAL_LIMIT)
async def get_budget_status(
    request: Request,
    budget_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get budget status with spending details.
    
    - Same as GET /{budget_id} but more explicit endpoint
    """
    return await get_budget(request, budget_id, current_user, db)

