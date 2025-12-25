"""
Service for creating and sending notifications.
"""
import json
import logging
import threading
from typing import Optional
from sqlalchemy.orm import Session
from app.models import Notification, NotificationSettings
from app.services.fcm_service import send_push_notification

logger = logging.getLogger(__name__)


def create_notification(
    db: Session,
    user_id: str,
    title: str,
    message: str,
    notification_type: str,
    data: Optional[dict] = None
) -> Notification:
    """
    Create a notification in the database.
    
    Args:
        db: Database session
        user_id: User ID to send notification to
        title: Notification title
        message: Notification message
        notification_type: Type of notification (TRANSACTION, PROMOTION, SECURITY, ALERT)
        data: Optional additional data as dict (will be converted to JSON string)
    
    Returns:
        Created Notification object
    """
    notification = Notification(
        user_id=user_id,
        title=title,
        message=message,
        type=notification_type,
        data=json.dumps(data) if data else None,
        is_read=False
    )
    
    db.add(notification)
    db.commit()
    db.refresh(notification)
    
    logger.info(f"Created notification {notification.id} for user {user_id}: {title}")
    
    return notification


def create_transaction_notification(
    db: Session,
    user_id: str,
    transaction_type: str,  # 'deposit', 'withdraw', 'transfer_in', 'transfer_out'
    amount: float,
    note: Optional[str] = None
) -> Optional[Notification]:
    """
    Create a transaction notification.
    
    Checks user's notification settings before creating notification.
    """
    # Check if user has transaction notifications enabled
    settings = db.query(NotificationSettings).filter(
        NotificationSettings.user_id == user_id
    ).first()
    
    if settings and not settings.enable_transaction_notifications:
        logger.debug(f"Transaction notifications disabled for user {user_id}")
        return None
    
    # Determine title and message based on transaction type
    if transaction_type == 'deposit':
        title = "Nạp tiền thành công"
        message = f"Bạn đã nạp {amount:,.0f}₫ vào ví"
    elif transaction_type == 'withdraw':
        title = "Rút tiền thành công"
        message = f"Bạn đã rút {amount:,.0f}₫ từ ví"
    elif transaction_type == 'transfer_in':
        title = "Nhận tiền"
        message = f"Bạn đã nhận {amount:,.0f}₫"
    elif transaction_type == 'transfer_out':
        title = "Chuyển tiền thành công"
        message = f"Bạn đã chuyển {amount:,.0f}₫"
    else:
        title = "Giao dịch mới"
        message = f"Giao dịch {amount:,.0f}₫ đã được thực hiện"
    
    if note:
        message += f": {note}"
    
    # Create notification
    notification = create_notification(
        db=db,
        user_id=user_id,
        title=title,
        message=message,
        notification_type="TRANSACTION",
        data={
            "transaction_type": transaction_type,
            "amount": amount,
            "note": note
        }
    )
    
    # Send push notification via FCM in background (non-blocking)
    # This prevents push notification delays from blocking the API response
    if settings and settings.device_token:
        notification_data = {
            "type": "TRANSACTION",
            "transaction_type": transaction_type,
            "amount": str(amount),
            "notification_id": notification.id,
        }
        if note:
            notification_data["note"] = note
        
        # Send push notification in background thread to avoid blocking
        def send_notification_background():
            try:
                send_push_notification(
                    device_token=settings.device_token,
                    title=title,
                    body=message,
                    data=notification_data
                )
            except Exception as e:
                # Don't fail notification creation if push fails
                logger.error(f"Failed to send push notification for user {user_id}: {e}")
        
        # Start background thread
        thread = threading.Thread(target=send_notification_background, daemon=True)
        thread.start()
    else:
        logger.debug(f"No device token found for user {user_id}, skipping push notification")
    
    return notification

