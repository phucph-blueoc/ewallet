from slowapi import Limiter
from slowapi.util import get_remote_address
from app.core.config import settings

# Create rate limiter instance
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[f"{settings.RATE_LIMIT_PER_MINUTE}/minute"] if settings.RATE_LIMIT_ENABLED else [],
    enabled=settings.RATE_LIMIT_ENABLED
)

# Define specific rate limits for different endpoint types
AUTH_RATE_LIMIT = "5/minute"  # Strict limit for auth endpoints
WALLET_OPERATION_LIMIT = "30/minute"  # Moderate limit for wallet operations
GENERAL_LIMIT = "60/minute"  # General limit for other endpoints
