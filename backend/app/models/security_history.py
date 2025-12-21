import uuid
from sqlalchemy import Column, String, ForeignKey, DateTime, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class SecurityHistory(Base):
    __tablename__ = "security_history"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    action_type = Column(String, nullable=False)  # LOGIN, LOGOUT, PASSWORD_CHANGE, PIN_CHANGE, 2FA_ENABLE, 2FA_DISABLE, SETTINGS_CHANGE
    description = Column(Text, nullable=True)  # Human-readable description
    ip_address = Column(String, nullable=True)
    user_agent = Column(String, nullable=True)
    device_id = Column(String, ForeignKey("user_devices.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    user = relationship("User", backref="security_history")
    device = relationship("UserDevice", backref="security_events")

