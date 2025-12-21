from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime

from app.core.database import get_db
from app.core.security import get_current_user
from app.core.rate_limit import limiter, GENERAL_LIMIT
from app.models import User, Notification, NotificationSettings
from app.schemas import (
    NotificationResponse,
    NotificationSettingsResponse,
    NotificationSettingsUpdate,
    DeviceRegistrationRequest,
)

router = APIRouter()


def _get_or_create_notification_settings(db: Session, user_id: str) -> NotificationSettings:
    """Get or create notification settings for user."""
    settings = db.query(NotificationSettings).filter(
        NotificationSettings.user_id == user_id
    ).first()
    
    if not settings:
        settings = NotificationSettings(user_id=user_id)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    
    return settings


@router.post("/register", status_code=status.HTTP_200_OK)
@limiter.limit(GENERAL_LIMIT)
async def register_device(
    request: Request,
    device_data: DeviceRegistrationRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Register device token for push notifications.
    
    - Stores device token and type
    - Updates notification settings
    """
    settings = _get_or_create_notification_settings(db, current_user.id)
    settings.device_token = device_data.device_token
    settings.device_type = device_data.device_type
    db.commit()
    
    return {"message": "Device registered successfully"}


@router.get("", response_model=List[NotificationResponse])
@limiter.limit(GENERAL_LIMIT)
async def get_notifications(
    request: Request,
    unread_only: bool = False,
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get notifications for current user.
    
    - Returns list of notifications
    - Optional filter: unread_only
    - Limited to 50 by default
    """
    query = db.query(Notification).filter(Notification.user_id == current_user.id)
    
    if unread_only:
        query = query.filter(Notification.is_read == False)
    
    notifications = query.order_by(Notification.created_at.desc()).limit(limit).all()
    return notifications


@router.get("/unread-count")
@limiter.limit(GENERAL_LIMIT)
async def get_unread_count(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get count of unread notifications."""
    count = db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.is_read == False
    ).count()
    
    return {"unread_count": count}


@router.put("/{notification_id}/read", status_code=status.HTTP_200_OK)
@limiter.limit(GENERAL_LIMIT)
async def mark_notification_read(
    request: Request,
    notification_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mark a notification as read."""
    notification = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == current_user.id
    ).first()
    
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found"
        )
    
    notification.is_read = True
    db.commit()
    
    return {"message": "Notification marked as read"}


@router.put("/read-all", status_code=status.HTTP_200_OK)
@limiter.limit(GENERAL_LIMIT)
async def mark_all_notifications_read(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mark all notifications as read."""
    db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.is_read == False
    ).update({"is_read": True})
    db.commit()
    
    return {"message": "All notifications marked as read"}


@router.delete("/{notification_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(GENERAL_LIMIT)
async def delete_notification(
    request: Request,
    notification_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a notification."""
    notification = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == current_user.id
    ).first()
    
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found"
        )
    
    db.delete(notification)
    db.commit()
    
    return None


@router.get("/settings", response_model=NotificationSettingsResponse)
@limiter.limit(GENERAL_LIMIT)
async def get_notification_settings(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get notification settings for current user."""
    settings = _get_or_create_notification_settings(db, current_user.id)
    return settings


@router.put("/settings", response_model=NotificationSettingsResponse)
@limiter.limit(GENERAL_LIMIT)
async def update_notification_settings(
    request: Request,
    settings_update: NotificationSettingsUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update notification settings."""
    settings = _get_or_create_notification_settings(db, current_user.id)
    
    if settings_update.enable_transaction_notifications is not None:
        settings.enable_transaction_notifications = settings_update.enable_transaction_notifications
    if settings_update.enable_promotion_notifications is not None:
        settings.enable_promotion_notifications = settings_update.enable_promotion_notifications
    if settings_update.enable_security_notifications is not None:
        settings.enable_security_notifications = settings_update.enable_security_notifications
    if settings_update.enable_alert_notifications is not None:
        settings.enable_alert_notifications = settings_update.enable_alert_notifications
    
    db.commit()
    db.refresh(settings)
    
    return settings

