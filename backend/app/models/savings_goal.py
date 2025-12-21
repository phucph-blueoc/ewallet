import uuid
from sqlalchemy import Column, String, ForeignKey, Float, DateTime, Date, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class SavingsGoal(Base):
    __tablename__ = "savings_goals"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String, nullable=False)  # Goal name, e.g., "Vacation", "New Car"
    target_amount = Column(Float, nullable=False)  # Target amount to save
    current_amount = Column(Float, default=0.0)  # Current saved amount
    deadline = Column(Date, nullable=True)  # Optional deadline
    auto_deposit_amount = Column(Float, nullable=True)  # Auto deposit amount per month
    is_completed = Column(Boolean, default=False)  # Whether goal is completed
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", backref="savings_goals")

