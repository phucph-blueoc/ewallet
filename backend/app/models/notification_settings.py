import uuid
from sqlalchemy import Column, String, ForeignKey, Boolean, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class NotificationSettings(Base):
    __tablename__ = "notification_settings"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    
    # Push notification settings
    enable_transaction_notifications = Column(Boolean, default=True)
    enable_promotion_notifications = Column(Boolean, default=True)
    enable_security_notifications = Column(Boolean, default=True)
    enable_alert_notifications = Column(Boolean, default=True)
    
    # Device token for push notifications
    device_token = Column(String, nullable=True)
    device_type = Column(String, nullable=True)  # IOS, ANDROID, WEB
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", backref="notification_settings", uselist=False)

