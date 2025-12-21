import uuid
from sqlalchemy import Column, String, ForeignKey, Numeric, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class BillTransaction(Base):
    __tablename__ = "bill_transactions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    provider_id = Column(String, ForeignKey("bill_providers.id"), nullable=False)
    customer_code = Column(String, nullable=False)
    amount = Column(Numeric(15, 2), nullable=False)
    bill_period = Column(String, nullable=True)  # Tháng/Năm (e.g., "12/2024")
    transaction_id = Column(String, ForeignKey("transactions.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", backref="bill_transactions")
    provider = relationship("BillProvider", backref="bill_transactions")
    transaction = relationship("Transaction", backref="bill_transaction")

