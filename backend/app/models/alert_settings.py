import uuid
from sqlalchemy import Column, String, ForeignKey, Boolean, Float, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class AlertSettings(Base):
    __tablename__ = "alert_settings"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    
    # Alert thresholds
    large_transaction_threshold = Column(Float, nullable=True)  # Alert if transaction > this amount
    low_balance_threshold = Column(Float, nullable=True)  # Alert if balance < this amount
    budget_warning_percentage = Column(Float, default=80.0)  # Alert if budget usage > 80%
    
    # Alert toggles
    enable_large_transaction_alert = Column(Boolean, default=True)
    enable_low_balance_alert = Column(Boolean, default=True)
    enable_budget_alert = Column(Boolean, default=True)
    enable_new_device_alert = Column(Boolean, default=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", backref="alert_settings", uselist=False)

