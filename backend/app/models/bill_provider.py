import uuid
from sqlalchemy import Column, String, Boolean
from app.core.database import Base

class BillProvider(Base):
    __tablename__ = "bill_providers"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    name = Column(String, nullable=False)  # EVN, SAVACO, FPT, Viettel...
    code = Column(String, nullable=False, unique=True)  # EVN, SAVACO, FPT, VIETTEL...
    logo_url = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)

