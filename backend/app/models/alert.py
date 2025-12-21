import uuid
from sqlalchemy import Column, String, ForeignKey, Boolean, DateTime, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class Alert(Base):
    __tablename__ = "alerts"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    type = Column(String, nullable=False)  # LARGE_TRANSACTION, LOW_BALANCE, BUDGET_WARNING, NEW_DEVICE
    title = Column(String, nullable=False)
    message = Column(Text, nullable=False)
    severity = Column(String, default="INFO")  # INFO, WARNING, CRITICAL
    is_read = Column(Boolean, default=False)
    data = Column(Text, nullable=True)  # JSON data for additional info
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", backref="alerts")

