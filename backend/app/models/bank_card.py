import uuid
from sqlalchemy import Column, String, ForeignKey, Boolean, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class BankCard(Base):
    __tablename__ = "bank_cards"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    card_number_encrypted = Column(String, nullable=False)
    card_holder_name = Column(String, nullable=False)
    expiry_date_encrypted = Column(String, nullable=False)
    cvv_encrypted = Column(String, nullable=False)
    bank_name = Column(String, nullable=False)
    card_type = Column(String, nullable=False)  # VISA, MASTERCARD, ATM
    is_verified = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", backref="bank_cards")

