import uuid
from sqlalchemy import Column, String, ForeignKey, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class SavedBill(Base):
    __tablename__ = "saved_bills"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    provider_id = Column(String, ForeignKey("bill_providers.id"), nullable=False)
    customer_code = Column(String, nullable=False)  # Mã khách hàng/số hợp đồng
    customer_name = Column(String, nullable=True)
    alias = Column(String, nullable=True)  # Tên gợi nhớ
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", backref="saved_bills")
    provider = relationship("BillProvider", backref="saved_bills")

