from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, date

from app.core.database import get_db
from app.core.security import get_current_user
from app.core.rate_limit import limiter, GENERAL_LIMIT
from app.models import User, SavingsGoal, Wallet, Transaction
from app.schemas import (
    SavingsGoalCreate,
    SavingsGoalUpdate,
    SavingsGoalResponse,
    SavingsGoalDepositRequest,
    SavingsGoalWithdrawRequest,
)

router = APIRouter()


@router.post("", response_model=SavingsGoalResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(GENERAL_LIMIT)
async def create_savings_goal(
    request: Request,
    goal: SavingsGoalCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a new savings goal.
    
    - Creates savings goal with initial amount 0
    """
    db_goal = SavingsGoal(
        user_id=current_user.id,
        name=goal.name,
        target_amount=goal.target_amount,
        deadline=goal.deadline,
        auto_deposit_amount=goal.auto_deposit_amount,
        current_amount=0.0,
        is_completed=False
    )
    
    db.add(db_goal)
    db.commit()
    db.refresh(db_goal)
    
    return db_goal


@router.get("", response_model=List[SavingsGoalResponse])
@limiter.limit(GENERAL_LIMIT)
async def get_savings_goals(
    request: Request,
    include_completed: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all savings goals for current user.
    
    - By default, excludes completed goals
    - Set include_completed=true to include completed goals
    """
    query = db.query(SavingsGoal).filter(SavingsGoal.user_id == current_user.id)
    
    if not include_completed:
        query = query.filter(SavingsGoal.is_completed == False)
    
    goals = query.order_by(SavingsGoal.created_at.desc()).all()
    return goals


@router.get("/{goal_id}", response_model=SavingsGoalResponse)
@limiter.limit(GENERAL_LIMIT)
async def get_savings_goal(
    request: Request,
    goal_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get a specific savings goal.
    """
    goal = db.query(SavingsGoal).filter(
        SavingsGoal.id == goal_id,
        SavingsGoal.user_id == current_user.id
    ).first()
    
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Savings goal not found"
        )
    
    return goal


@router.put("/{goal_id}", response_model=SavingsGoalResponse)
@limiter.limit(GENERAL_LIMIT)
async def update_savings_goal(
    request: Request,
    goal_id: str,
    goal_update: SavingsGoalUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update a savings goal.
    """
    goal = db.query(SavingsGoal).filter(
        SavingsGoal.id == goal_id,
        SavingsGoal.user_id == current_user.id
    ).first()
    
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Savings goal not found"
        )
    
    # Update fields
    if goal_update.name is not None:
        goal.name = goal_update.name
    if goal_update.target_amount is not None:
        goal.target_amount = goal_update.target_amount
    if goal_update.deadline is not None:
        goal.deadline = goal_update.deadline
    if goal_update.auto_deposit_amount is not None:
        goal.auto_deposit_amount = goal_update.auto_deposit_amount
    if goal_update.is_completed is not None:
        goal.is_completed = goal_update.is_completed
    
    # Auto-complete if current_amount >= target_amount
    if goal.current_amount >= goal.target_amount:
        goal.is_completed = True
    
    db.commit()
    db.refresh(goal)
    
    return goal


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(GENERAL_LIMIT)
async def delete_savings_goal(
    request: Request,
    goal_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete a savings goal.
    
    - Note: This will NOT return the money to wallet automatically
    - User should withdraw money first if needed
    """
    goal = db.query(SavingsGoal).filter(
        SavingsGoal.id == goal_id,
        SavingsGoal.user_id == current_user.id
    ).first()
    
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Savings goal not found"
        )
    
    db.delete(goal)
    db.commit()
    
    return None


@router.post("/{goal_id}/deposit", response_model=SavingsGoalResponse)
@limiter.limit(GENERAL_LIMIT)
async def deposit_to_savings_goal(
    request: Request,
    goal_id: str,
    deposit_request: SavingsGoalDepositRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Deposit money into a savings goal from wallet.
    
    - Deducts amount from wallet balance
    - Adds amount to savings goal current_amount
    - Creates a transaction record
    """
    goal = db.query(SavingsGoal).filter(
        SavingsGoal.id == goal_id,
        SavingsGoal.user_id == current_user.id
    ).first()
    
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Savings goal not found"
        )
    
    if goal.is_completed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot deposit to completed savings goal"
        )
    
    # Get user wallet
    wallet = db.query(Wallet).filter(Wallet.user_id == current_user.id).first()
    if not wallet:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Wallet not found"
        )
    
    # Check balance
    if wallet.balance < deposit_request.amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Insufficient wallet balance"
        )
    
    # Deduct from wallet
    wallet.balance -= deposit_request.amount
    
    # Add to savings goal
    goal.current_amount += deposit_request.amount
    
    # Check if goal is completed
    if goal.current_amount >= goal.target_amount:
        goal.is_completed = True
    
    # Create transaction record
    transaction = Transaction(
        sender_id=current_user.id,
        receiver_id=None,  # System transaction
        amount=deposit_request.amount,
        encrypted_note=f"Deposit to savings goal: {goal.name}"
    )
    db.add(transaction)
    
    db.commit()
    db.refresh(goal)
    
    return goal


@router.post("/{goal_id}/withdraw", response_model=SavingsGoalResponse)
@limiter.limit(GENERAL_LIMIT)
async def withdraw_from_savings_goal(
    request: Request,
    goal_id: str,
    withdraw_request: SavingsGoalWithdrawRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Withdraw money from a savings goal to wallet.
    
    - Deducts amount from savings goal current_amount
    - Adds amount to wallet balance
    - Creates a transaction record
    """
    goal = db.query(SavingsGoal).filter(
        SavingsGoal.id == goal_id,
        SavingsGoal.user_id == current_user.id
    ).first()
    
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Savings goal not found"
        )
    
    # Check if goal has enough balance
    if goal.current_amount < withdraw_request.amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Insufficient savings goal balance"
        )
    
    # Get user wallet
    wallet = db.query(Wallet).filter(Wallet.user_id == current_user.id).first()
    if not wallet:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Wallet not found"
        )
    
    # Deduct from savings goal
    goal.current_amount -= withdraw_request.amount
    
    # If goal was completed, mark as incomplete if below target
    if goal.is_completed and goal.current_amount < goal.target_amount:
        goal.is_completed = False
    
    # Add to wallet
    wallet.balance += withdraw_request.amount
    
    # Create transaction record
    transaction = Transaction(
        sender_id=None,  # System transaction
        receiver_id=current_user.id,
        amount=withdraw_request.amount,
        encrypted_note=f"Withdraw from savings goal: {goal.name}"
    )
    db.add(transaction)
    
    db.commit()
    db.refresh(goal)
    
    return goal

