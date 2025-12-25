from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # Application
    PROJECT_NAME: str = "E-Wallet API"
    API_V1_STR: str = "/api/v1"
    
    # Database (PostgreSQL or SQLite)
    # PostgreSQL: postgresql://user:password@localhost:5432/dbname
    # SQLite: sqlite:///./sql_app.db
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/ewallet"
    
    # Security - JWT
    SECRET_KEY: str = "your-super-secret-key-change-this-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # Security - Encryption
    ENCRYPTION_KEY: str = "your-encryption-key-change-this-in-production"
    
    # Email Service - SMTP (legacy)
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    SMTP_FROM: Optional[str] = None
    SMTP_FROM_NAME: str = "E-Wallet Support"
    
    # Email Service - Microsoft Graph API
    MICROSOFT_CLIENT_ID: Optional[str] = None
    MICROSOFT_CLIENT_SECRET: Optional[str] = None
    MICROSOFT_TENANT_ID: Optional[str] = None
    MICROSOFT_MAIL_FROM: Optional[str] = None  # The email address to send from
    
    # OTP Settings
    OTP_INTERVAL: int = 300  # 5 minutes in seconds (TOTP interval)
    OTP_EXPIRY_MINUTES: int = 15  # 15 minutes expiry (increased from 5 to handle slow email delivery)
    
    # Transfer Settings
    LARGE_TRANSFER_THRESHOLD: float = 1000000.0  # Require OTP for transfers >= 1,000,000₫
    
    # Deposit/Withdraw Limits
    MAX_DEPOSIT_AMOUNT: float = 100000000.0  # Max 100,000,000₫ (100 triệu) per deposit
    MAX_WITHDRAW_AMOUNT: float = 100000000.0  # Max 100,000,000₫ (100 triệu) per withdraw
    
    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_PER_MINUTE: int = 60

    class Config:
        case_sensitive = True
        env_file = ".env"

settings = Settings()
