import uuid
from sqlalchemy import Column, String, ForeignKey, DateTime, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class UserDevice(Base):
    __tablename__ = "user_devices"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    device_token = Column(String, nullable=True)  # For push notifications
    device_name = Column(String, nullable=False)  # e.g., "iPhone 14 Pro", "Samsung Galaxy S23"
    device_type = Column(String, nullable=False)  # IOS, ANDROID, WEB
    ip_address = Column(String, nullable=True)  # IPv4 or IPv6
    user_agent = Column(String, nullable=True)  # Browser/App user agent
    last_login = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    is_active = Column(Boolean, default=True)

    user = relationship("User", backref="devices")

