import uuid
from sqlalchemy import Boolean, Column, String, DateTime
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    full_name = Column(String)
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)  # Email verification status
    otp_secret = Column(String, nullable=True)
    otp_created_at = Column(DateTime, nullable=True)  # Track when OTP was created
    # Hashed transaction PIN used to authorize transfers
    transaction_pin_hash = Column(String, nullable=True)
