from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.core.security import get_current_user, verify_password
from app.core.encryption import encryption_service
from app.core.rate_limit import limiter, GENERAL_LIMIT, WALLET_OPERATION_LIMIT
from app.models import User, BankCard, Wallet, Transaction
from app.schemas import (
    BankCardCreate,
    BankCardUpdate,
    BankCardResponse,
    BankCardVerifyRequest,
)
from app.services.otp import otp_service
from app.services.email_service import send_otp_email_async
from datetime import datetime

router = APIRouter()


def mask_card_number(card_number: str) -> str:
    """Mask card number, showing only last 4 digits."""
    if len(card_number) <= 4:
        return "****"
    return "**** " * 3 + card_number[-4:]

@router.post("", response_model=BankCardResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(GENERAL_LIMIT)
async def create_bank_card(
    request: Request,
    card: BankCardCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Add a new bank card.
    
    - Encrypts sensitive card information (card number, expiry, CVV)
    - Creates card record (unverified initially)
    - Sends OTP to user's email for verification
    """
    # Clean card number (remove spaces/dashes)
    import re
    card_number = re.sub(r'[\s-]', '', card.card_number)
    
    # Encrypt sensitive data
    card_number_encrypted = encryption_service.encrypt(card_number)
    expiry_date_encrypted = encryption_service.encrypt(card.expiry_date)
    cvv_encrypted = encryption_service.encrypt(card.cvv)
    
    # Create bank card
    db_card = BankCard(
        user_id=current_user.id,
        card_number_encrypted=card_number_encrypted,
        card_holder_name=card.card_holder_name,
        expiry_date_encrypted=expiry_date_encrypted,
        cvv_encrypted=cvv_encrypted,
        bank_name=card.bank_name,
        card_type=card.card_type,
        is_verified=False
    )
    
    db.add(db_card)
    db.commit()
    db.refresh(db_card)
    
    # Generate and send OTP for verification
    otp_secret = otp_service.generate_secret()
    otp_code = otp_service.generate_otp(otp_secret)
    
    # Store OTP secret in user record for verification
    current_user.otp_secret = otp_secret
    current_user.otp_created_at = datetime.utcnow()
    db.commit()
    
    # Print OTP to console IMMEDIATELY (before attempting email)
    # This ensures user can always see OTP even if email is slow/fails
    print(f"\n{'='*60}")
    print(f"OTP for bank card verification:")
    print(f"  Email: {current_user.email}")
    print(f"  OTP Code: {otp_code}")
    print(f"  Card: {card.bank_name} - {mask_card_number(card_number)}")
    print(f"  Valid for: 5 minutes")
    print(f"{'='*60}\n")
    
    # Send OTP via email in background (truly fire-and-forget, non-blocking)
    send_otp_email_async(
        to_email=current_user.email,
        otp_code=otp_code,
        user_name=current_user.full_name
    )
    
    # Return response with masked card number
    return BankCardResponse(
        id=db_card.id,
        user_id=db_card.user_id,
        card_holder_name=db_card.card_holder_name,
        bank_name=db_card.bank_name,
        card_type=db_card.card_type,
        card_number_masked=mask_card_number(card_number),
        expiry_date_masked=card.expiry_date,
        is_verified=db_card.is_verified,
        created_at=db_card.created_at
    )


@router.get("", response_model=List[BankCardResponse])
@limiter.limit(GENERAL_LIMIT)
async def get_bank_cards(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all bank cards for current user."""
    cards = db.query(BankCard).filter(
        BankCard.user_id == current_user.id
    ).order_by(BankCard.created_at.desc()).all()
    
    result = []
    for card in cards:
        # Decrypt to get last 4 digits
        try:
            card_number = encryption_service.decrypt(card.card_number_encrypted)
            expiry_date = encryption_service.decrypt(card.expiry_date_encrypted)
        except:
            card_number = "****"
            expiry_date = "**/**"
        
        result.append(BankCardResponse(
            id=card.id,
            user_id=card.user_id,
            card_holder_name=card.card_holder_name,
            bank_name=card.bank_name,
            card_type=card.card_type,
            card_number_masked=mask_card_number(card_number),
            expiry_date_masked=expiry_date,
            is_verified=card.is_verified,
            created_at=card.created_at
        ))
    
    return result


@router.get("/{card_id}", response_model=BankCardResponse)
@limiter.limit(GENERAL_LIMIT)
async def get_bank_card(
    request: Request,
    card_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific bank card by ID."""
    card = db.query(BankCard).filter(
        BankCard.id == card_id,
        BankCard.user_id == current_user.id
    ).first()
    
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bank card not found"
        )
    
    # Decrypt to get last 4 digits
    try:
        card_number = encryption_service.decrypt(card.card_number_encrypted)
        expiry_date = encryption_service.decrypt(card.expiry_date_encrypted)
    except:
        card_number = "****"
        expiry_date = "**/**"
    
    return BankCardResponse(
        id=card.id,
        user_id=card.user_id,
        card_holder_name=card.card_holder_name,
        bank_name=card.bank_name,
        card_type=card.card_type,
        card_number_masked=mask_card_number(card_number),
        expiry_date_masked=expiry_date,
        is_verified=card.is_verified,
        created_at=card.created_at
    )


@router.put("/{card_id}", response_model=BankCardResponse)
@limiter.limit(GENERAL_LIMIT)
async def update_bank_card(
    request: Request,
    card_id: str,
    card_update: BankCardUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update bank card information."""
    card = db.query(BankCard).filter(
        BankCard.id == card_id,
        BankCard.user_id == current_user.id
    ).first()
    
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bank card not found"
        )
    
    # Update fields
    if card_update.card_holder_name is not None:
        card.card_holder_name = card_update.card_holder_name
    if card_update.bank_name is not None:
        card.bank_name = card_update.bank_name
    
    db.commit()
    db.refresh(card)
    
    # Decrypt to get last 4 digits
    try:
        card_number = encryption_service.decrypt(card.card_number_encrypted)
        expiry_date = encryption_service.decrypt(card.expiry_date_encrypted)
    except:
        card_number = "****"
        expiry_date = "**/**"
    
    return BankCardResponse(
        id=card.id,
        user_id=card.user_id,
        card_holder_name=card.card_holder_name,
        bank_name=card.bank_name,
        card_type=card.card_type,
        card_number_masked=mask_card_number(card_number),
        expiry_date_masked=expiry_date,
        is_verified=card.is_verified,
        created_at=card.created_at
    )


@router.delete("/{card_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(GENERAL_LIMIT)
async def delete_bank_card(
    request: Request,
    card_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a bank card."""
    card = db.query(BankCard).filter(
        BankCard.id == card_id,
        BankCard.user_id == current_user.id
    ).first()
    
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bank card not found"
        )
    
    db.delete(card)
    db.commit()
    
    return None


@router.post("/{card_id}/verify", response_model=BankCardResponse)
@limiter.limit(GENERAL_LIMIT)
async def verify_bank_card(
    request: Request,
    card_id: str,
    verify_request: BankCardVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Verify bank card with OTP.
    
    - Verifies OTP code
    - Marks card as verified
    """
    card = db.query(BankCard).filter(
        BankCard.id == card_id,
        BankCard.user_id == current_user.id
    ).first()
    
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bank card not found"
        )
    
    if card.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Card is already verified"
        )
    
    # Verify OTP code
    # OTP secret is stored in user.otp_secret when card was created
    if not current_user.otp_secret:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP không hợp lệ hoặc đã hết hạn. Vui lòng thêm lại thẻ."
        )
    
    # Verify OTP
    is_valid = otp_service.verify_otp(
        secret=current_user.otp_secret,
        otp=verify_request.otp_code
    )
    
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mã OTP không đúng. Vui lòng kiểm tra lại."
        )
    
    # Check if OTP is expired (5 minutes)
    if current_user.otp_created_at:
        from datetime import timedelta
        if datetime.utcnow() - current_user.otp_created_at > timedelta(minutes=5):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Mã OTP đã hết hạn. Vui lòng thêm lại thẻ để nhận mã mới."
            )
    
    # Mark card as verified
    card.is_verified = True
    
    # Clear OTP secret after successful verification
    current_user.otp_secret = None
    current_user.otp_created_at = None
    db.commit()
    db.refresh(card)
    
    # Decrypt to get last 4 digits
    try:
        card_number = encryption_service.decrypt(card.card_number_encrypted)
        expiry_date = encryption_service.decrypt(card.expiry_date_encrypted)
    except:
        card_number = "****"
        expiry_date = "**/**"
    
    return BankCardResponse(
        id=card.id,
        user_id=card.user_id,
        card_holder_name=card.card_holder_name,
        bank_name=card.bank_name,
        card_type=card.card_type,
        card_number_masked=mask_card_number(card_number),
        expiry_date_masked=expiry_date,
        is_verified=card.is_verified,
        created_at=card.created_at
    )


@router.post("/{card_id}/resend-otp")
@limiter.limit(GENERAL_LIMIT)
async def resend_card_verification_otp(
    request: Request,
    card_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Resend OTP for bank card verification.
    
    - Generates new OTP
    - Sends OTP to user's email
    """
    card = db.query(BankCard).filter(
        BankCard.id == card_id,
        BankCard.user_id == current_user.id
    ).first()
    
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Thẻ ngân hàng không tồn tại"
        )
    
    if card.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Thẻ đã được xác thực rồi"
        )
    
    # Generate new OTP
    otp_secret = otp_service.generate_secret()
    otp_code = otp_service.generate_otp(otp_secret)
    
    # Store OTP secret in user record
    current_user.otp_secret = otp_secret
    current_user.otp_created_at = datetime.utcnow()
    db.commit()
    
    # Decrypt to get card number for display
    try:
        card_number = encryption_service.decrypt(card.card_number_encrypted)
    except:
        card_number = "****"
    
    # Print OTP to console IMMEDIATELY (before attempting email)
    # This ensures user can always see OTP even if email is slow/fails
    print(f"\n{'='*60}")
    print(f"OTP for bank card verification (RESEND):")
    print(f"  Email: {current_user.email}")
    print(f"  OTP Code: {otp_code}")
    print(f"  Card: {card.bank_name} - {mask_card_number(card_number)}")
    print(f"  Valid for: 5 minutes")
    print(f"{'='*60}\n")
    
    # Send OTP via email in background (truly fire-and-forget, non-blocking)
    send_otp_email_async(
        to_email=current_user.email,
        otp_code=otp_code,
        user_name=current_user.full_name
    )
    
    return {
        "message": "Mã OTP đã được gửi đến email của bạn (hoặc kiểm tra console/logs)",
        "email": current_user.email
    }
