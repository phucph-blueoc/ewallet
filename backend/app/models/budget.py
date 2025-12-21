import uuid
from sqlalchemy import Column, String, ForeignKey, Float, Integer, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class Budget(Base):
    __tablename__ = "budgets"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    category = Column(String, nullable=False)  # e.g., "FOOD", "SHOPPING", "BILLS", "TRANSPORT", "OTHER"
    amount = Column(Float, nullable=False)  # Budget amount
    period = Column(String, nullable=False, default="MONTH")  # MONTH, YEAR
    month = Column(Integer, nullable=True)  # 1-12 for monthly budgets
    year = Column(Integer, nullable=False)  # e.g., 2024
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", backref="budgets")

