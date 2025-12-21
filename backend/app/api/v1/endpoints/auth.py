from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from datetime import datetime, timedelta

from app.core.database import get_db
from app.core.security import create_access_token, create_refresh_token, get_password_hash, verify_password, SECRET_KEY, ALGORITHM
from app.core.rate_limit import limiter, AUTH_RATE_LIMIT
from app.core.config import settings
from app.models import User, Wallet, UserDevice, SecurityHistory
from app.schemas import (
    UserCreate,
    UserResponse,
    Token,
    UserLogin,
    OTPVerify,
    ResendOTP,
    ChangePassword,
    TransactionPinRequest,
    TransactionPinVerify,
)
from app.core.security import get_current_user
from app.services.otp import otp_service
from app.services.email_service import email_service, send_otp_email_async

router = APIRouter()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/v1/auth/login")

@router.post("/register", response_model=UserResponse)
@limiter.limit(AUTH_RATE_LIMIT)
async def register(request: Request, user: UserCreate, db: Session = Depends(get_db)):
    """
    Register a new user account.
    
    - Generates OTP and sends it via email for verification
    - User account is created but marked as unverified
    - Must verify OTP before being able to login
    """
    db_user = db.query(User).filter(User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Generate OTP secret
    otp_secret = otp_service.generate_secret()
    otp_code = otp_service.generate_otp(otp_secret)
    
    # Create user (unverified initially)
    hashed_password = get_password_hash(user.password)
    db_user = User(
        email=user.email,
        hashed_password=hashed_password,
        full_name=user.full_name,
        otp_secret=otp_secret,
        otp_created_at=datetime.utcnow(),
        is_verified=False
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    # Create Wallet for user
    db_wallet = Wallet(user_id=db_user.id)
    db.add(db_wallet)
    db.commit()
    
    # Print OTP to console IMMEDIATELY (before attempting email)
    # This ensures user can always see OTP even if email is slow/fails
    print(f"\n{'='*60}")
    print(f"OTP for user registration:")
    print(f"  Email: {user.email}")
    print(f"  OTP Code: {otp_code}")
    print(f"  Valid for: {settings.OTP_EXPIRY_MINUTES} minutes")
    print(f"{'='*60}\n")
    
    # Send OTP via email in background (truly fire-and-forget, non-blocking)
    send_otp_email_async(
        to_email=user.email,
        otp_code=otp_code,
        user_name=user.full_name
    )
    
    return db_user

def _detect_device_type(user_agent: str) -> str:
    """Detect device type from user agent string."""
    user_agent_lower = user_agent.lower()
    if 'iphone' in user_agent_lower or 'ipad' in user_agent_lower or 'ipod' in user_agent_lower:
        return 'IOS'
    elif 'android' in user_agent_lower:
        return 'ANDROID'
    else:
        return 'WEB'

def _get_device_name(user_agent: str, device_type: str) -> str:
    """Extract device name from user agent."""
    user_agent_lower = user_agent.lower()
    if device_type == 'IOS':
        if 'iphone' in user_agent_lower:
            # Try to extract iPhone model
            if 'iphone os 17' in user_agent_lower or 'iphone os 18' in user_agent_lower:
                return 'iPhone'
            return 'iPhone'
        elif 'ipad' in user_agent_lower:
            return 'iPad'
        return 'iOS Device'
    elif device_type == 'ANDROID':
        # Try to extract Android device name
        if 'samsung' in user_agent_lower:
            return 'Samsung Device'
        elif 'xiaomi' in user_agent_lower:
            return 'Xiaomi Device'
        return 'Android Device'
    else:
        # Extract browser name
        if 'chrome' in user_agent_lower:
            return 'Chrome Browser'
        elif 'firefox' in user_agent_lower:
            return 'Firefox Browser'
        elif 'safari' in user_agent_lower:
            return 'Safari Browser'
        return 'Web Browser'

@router.post("/login", response_model=Token)
@limiter.limit(AUTH_RATE_LIMIT)
async def login(request: Request, form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """
    Login with email and password.
    
    - User must have verified their email via OTP before logging in
    - Automatically creates/updates device record
    - Creates security history entry
    - Returns JWT access token and refresh token on success
    """
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Check if user has verified their email
    if not user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Email not verified. Please verify your email with the OTP sent during registration.",
        )
    
    # Get device information from request
    user_agent = request.headers.get("user-agent", "Unknown")
    ip_address = request.client.host if request.client else None
    
    # Detect device type and name
    device_type = _detect_device_type(user_agent)
    device_name = _get_device_name(user_agent, device_type)
    
    # Create or update device record
    # Try to find existing device by IP and user_agent (simple matching)
    existing_device = db.query(UserDevice).filter(
        UserDevice.user_id == user.id,
        UserDevice.ip_address == ip_address,
        UserDevice.user_agent == user_agent,
        UserDevice.is_active == True
    ).first()
    
    if existing_device:
        # Update last login time
        existing_device.last_login = datetime.utcnow()
        device_id = existing_device.id
    else:
        # Create new device record
        new_device = UserDevice(
            user_id=user.id,
            device_name=device_name,
            device_type=device_type,
            ip_address=ip_address,
            user_agent=user_agent,
            last_login=datetime.utcnow()
        )
        db.add(new_device)
        db.flush()  # Flush to get the ID
        device_id = new_device.id
    
    # Create security history entry
    security_history = SecurityHistory(
        user_id=user.id,
        action_type='LOGIN',
        description=f'Đăng nhập từ {device_name}',
        ip_address=ip_address,
        user_agent=user_agent,
        device_id=device_id
    )
    db.add(security_history)
    
    # Commit all changes
    db.commit()
    
    access_token = create_access_token(subject=user.email)
    refresh_token = create_refresh_token(subject=user.email)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }

@router.post("/verify-otp")
@limiter.limit(AUTH_RATE_LIMIT)
async def verify_otp(request: Request, otp_data: OTPVerify, db: Session = Depends(get_db)):
    """
    Verify OTP code and activate user account.
    
    - Checks if OTP is valid and not expired
    - Marks user as verified upon successful verification
    """
    user = db.query(User).filter(User.email == otp_data.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if user.is_verified:
        return {"message": "Email already verified"}
    
    # Check if OTP has expired
    if user.otp_created_at:
        expiry_time = user.otp_created_at + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
        if datetime.utcnow() > expiry_time:
            raise HTTPException(status_code=400, detail="OTP has expired. Please request a new one.")
    
    # Verify OTP
    if not otp_service.verify_otp(user.otp_secret, otp_data.otp_code):
        raise HTTPException(status_code=400, detail="Invalid OTP")
    
    # Mark user as verified
    user.is_verified = True
    db.commit()
        
    return {"message": "Email verified successfully. You can now login."}

@router.post("/resend-otp")
@limiter.limit(AUTH_RATE_LIMIT)
async def resend_otp(request: Request, data: ResendOTP, db: Session = Depends(get_db)):
    """
    Resend OTP to user's email.
    
    - Generates a new OTP and sends it via email
    - Useful if previous OTP expired or was not received
    """
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if user.is_verified:
        raise HTTPException(status_code=400, detail="Email already verified")
    
    # Generate new OTP
    otp_secret = otp_service.generate_secret()
    otp_code = otp_service.generate_otp(otp_secret)
    
    # Update user's OTP secret and timestamp
    user.otp_secret = otp_secret
    user.otp_created_at = datetime.utcnow()
    db.commit()
    
    # Print OTP to console IMMEDIATELY (before attempting email)
    # This ensures user can always see OTP even if email is slow/fails
    print(f"\n{'='*60}")
    print(f"OTP for email verification (RESEND):")
    print(f"  Email: {data.email}")
    print(f"  OTP Code: {otp_code}")
    print(f"  Valid for: {settings.OTP_EXPIRY_MINUTES} minutes")
    print(f"{'='*60}\n")
    
    # Send OTP via email in background (truly fire-and-forget, non-blocking)
    send_otp_email_async(
        to_email=data.email,
        otp_code=otp_code,
        user_name=user.full_name
    )
    
    return {"message": "OTP sent to your email (or check console/logs)"}

@router.post("/change-password")
@limiter.limit(AUTH_RATE_LIMIT)
async def change_password(
    request: Request,
    data: ChangePassword,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Change user password.
    
    - Requires current password verification
    - Updates password with new hashed password
    """
    # Verify current password
    if not verify_password(data.current_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    
    # Check if new password is same as current
    if verify_password(data.new_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from current password"
        )
    
    # Get device information from request
    user_agent = request.headers.get("user-agent", "Unknown")
    ip_address = request.client.host if request.client else None
    
    # Update password
    current_user.hashed_password = get_password_hash(data.new_password)
    
    # Create security history entry
    security_history = SecurityHistory(
        user_id=current_user.id,
        action_type='PASSWORD_CHANGE',
        description='Đổi mật khẩu',
        ip_address=ip_address,
        user_agent=user_agent
    )
    db.add(security_history)
    
    db.commit()
    
    return {"message": "Password changed successfully"}


@router.post("/transaction-pin/set")
@limiter.limit(AUTH_RATE_LIMIT)
async def set_transaction_pin(
    request: Request,
    data: TransactionPinRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Set or update the transaction PIN used to authorize transfers.
    
    - Requires the user's current password for verification
    - Stores the PIN as a hashed value (bcrypt)
    """
    if not verify_password(data.current_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    
    # Get device information from request
    user_agent = request.headers.get("user-agent", "Unknown")
    ip_address = request.client.host if request.client else None
    
    current_user.transaction_pin_hash = get_password_hash(data.transaction_pin)
    
    # Create security history entry
    security_history = SecurityHistory(
        user_id=current_user.id,
        action_type='PIN_CHANGE',
        description='Đổi mã PIN giao dịch',
        ip_address=ip_address,
        user_agent=user_agent
    )
    db.add(security_history)
    
    db.commit()
    
    return {"message": "Transaction PIN updated successfully"}


@router.post("/transaction-pin/verify")
@limiter.limit(AUTH_RATE_LIMIT)
async def verify_transaction_pin(
    request: Request,
    data: TransactionPinVerify,
    current_user: User = Depends(get_current_user),
):
    """
    Verify the transaction PIN without performing any action.
    
    Useful for flows that need to confirm the PIN before proceeding.
    """
    if not current_user.transaction_pin_hash:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transaction PIN not set. Please set it in settings."
        )
    
    if not verify_password(data.transaction_pin, current_user.transaction_pin_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid transaction PIN"
        )
    
    return {"message": "Transaction PIN verified"}
