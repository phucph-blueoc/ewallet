from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

from app.core.database import get_db
from app.core.security import get_current_user
from app.core.rate_limit import limiter, GENERAL_LIMIT
from app.models import User, Alert, AlertSettings
from app.schemas import (
    AlertResponse,
    AlertSettingsResponse,
    AlertSettingsUpdate,
)

router = APIRouter()


def _get_or_create_alert_settings(db: Session, user_id: str) -> AlertSettings:
    """Get or create alert settings for user."""
    settings = db.query(AlertSettings).filter(
        AlertSettings.user_id == user_id
    ).first()
    
    if not settings:
        settings = AlertSettings(user_id=user_id)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    
    return settings


@router.get("", response_model=List[AlertResponse])
@limiter.limit(GENERAL_LIMIT)
async def get_alerts(
    request: Request,
    unread_only: bool = False,
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get alerts for current user.
    
    - Returns list of alerts
    - Optional filter: unread_only
    - Limited to 50 by default
    """
    query = db.query(Alert).filter(Alert.user_id == current_user.id)
    
    if unread_only:
        query = query.filter(Alert.is_read == False)
    
    alerts = query.order_by(Alert.created_at.desc()).limit(limit).all()
    return alerts


@router.get("/unread-count")
@limiter.limit(GENERAL_LIMIT)
async def get_unread_alert_count(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get count of unread alerts."""
    count = db.query(Alert).filter(
        Alert.user_id == current_user.id,
        Alert.is_read == False
    ).count()
    
    return {"unread_count": count}


@router.put("/{alert_id}/read", status_code=status.HTTP_200_OK)
@limiter.limit(GENERAL_LIMIT)
async def mark_alert_read(
    request: Request,
    alert_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mark an alert as read."""
    alert = db.query(Alert).filter(
        Alert.id == alert_id,
        Alert.user_id == current_user.id
    ).first()
    
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found"
        )
    
    alert.is_read = True
    db.commit()
    
    return {"message": "Alert marked as read"}


@router.put("/read-all", status_code=status.HTTP_200_OK)
@limiter.limit(GENERAL_LIMIT)
async def mark_all_alerts_read(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mark all alerts as read."""
    db.query(Alert).filter(
        Alert.user_id == current_user.id,
        Alert.is_read == False
    ).update({"is_read": True})
    db.commit()
    
    return {"message": "All alerts marked as read"}


@router.delete("/{alert_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(GENERAL_LIMIT)
async def delete_alert(
    request: Request,
    alert_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete an alert."""
    alert = db.query(Alert).filter(
        Alert.id == alert_id,
        Alert.user_id == current_user.id
    ).first()
    
    if not alert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found"
        )
    
    db.delete(alert)
    db.commit()
    
    return None


@router.get("/settings", response_model=AlertSettingsResponse)
@limiter.limit(GENERAL_LIMIT)
async def get_alert_settings(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get alert settings for current user."""
    settings = _get_or_create_alert_settings(db, current_user.id)
    return settings


@router.put("/settings", response_model=AlertSettingsResponse)
@limiter.limit(GENERAL_LIMIT)
async def update_alert_settings(
    request: Request,
    settings_update: AlertSettingsUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update alert settings."""
    settings = _get_or_create_alert_settings(db, current_user.id)
    
    if settings_update.large_transaction_threshold is not None:
        settings.large_transaction_threshold = settings_update.large_transaction_threshold
    if settings_update.low_balance_threshold is not None:
        settings.low_balance_threshold = settings_update.low_balance_threshold
    if settings_update.budget_warning_percentage is not None:
        settings.budget_warning_percentage = settings_update.budget_warning_percentage
    if settings_update.enable_large_transaction_alert is not None:
        settings.enable_large_transaction_alert = settings_update.enable_large_transaction_alert
    if settings_update.enable_low_balance_alert is not None:
        settings.enable_low_balance_alert = settings_update.enable_low_balance_alert
    if settings_update.enable_budget_alert is not None:
        settings.enable_budget_alert = settings_update.enable_budget_alert
    if settings_update.enable_new_device_alert is not None:
        settings.enable_new_device_alert = settings_update.enable_new_device_alert
    
    db.commit()
    db.refresh(settings)
    
    return settings

