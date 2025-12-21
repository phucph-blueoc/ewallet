import uuid
from sqlalchemy import Column, String, ForeignKey, Float, DateTime
from sqlalchemy.sql import func
from app.core.database import Base

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    sender_id = Column(String, ForeignKey("users.id"), nullable=True) # Nullable for deposit
    receiver_id = Column(String, ForeignKey("users.id"), nullable=True) # Nullable for withdraw
    amount = Column(Float, nullable=False)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    encrypted_note = Column(String, nullable=True)
