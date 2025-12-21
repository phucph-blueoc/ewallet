from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from fastapi.responses import JSONResponse

from app.core.config import settings
from app.core.rate_limit import limiter
from app.api.v1.api import api_router

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="E-Wallet API with secure authentication, wallet operations, and transaction management",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Add rate limiting
app.state.limiter = limiter

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return JSONResponse(
        status_code=429,
        content={"detail": "Rate limit exceeded. Please try again later."}
    )

if settings.RATE_LIMIT_ENABLED:
    app.add_middleware(SlowAPIMiddleware)

# Include API router
app.include_router(api_router, prefix=settings.API_V1_STR)

# Set CORS - In production, specify allowed origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: Set specific origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "Welcome to E-Wallet API", "docs": "/docs"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "version": "1.0.0"}
