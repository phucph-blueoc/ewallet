from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from typing import List
from datetime import datetime, timedelta
import uuid

from app.core.database import get_db
from app.core.security import get_current_user, verify_password
from app.core.encryption import encryption_service
from app.core.rate_limit import limiter, WALLET_OPERATION_LIMIT, GENERAL_LIMIT
from app.core.config import settings
from app.models import User, Wallet, Transaction, BankCard
from app.schemas import WalletResponse, DepositRequest, WithdrawRequest, TransferRequest, TransferOTPRequest, TransactionResponse, DepositFromCardRequest, WithdrawToCardRequest
from app.services.otp import otp_service
from app.services.email_service import email_service, send_email_async
from app.services.notification_service import create_transaction_notification

router = APIRouter()

def get_user_wallet(user: User, db: Session) -> Wallet:
    """Get or create wallet for a user."""
    wallet = db.query(Wallet).filter(Wallet.user_id == user.id).first()
    if not wallet:
        # Should not happen if registered correctly, but for safety
        wallet = Wallet(user_id=user.id)
        db.add(wallet)
        db.commit()
        db.refresh(wallet)
    return wallet

@router.get("/me", response_model=WalletResponse)
@limiter.limit(GENERAL_LIMIT)
async def get_my_wallet(request: Request, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Get current user's wallet information."""
    return get_user_wallet(current_user, db)

@router.post("/deposit", response_model=WalletResponse)
@limiter.limit(WALLET_OPERATION_LIMIT)
async def deposit(
    request: Request,
    deposit_request: DepositRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Deposit funds into wallet from various sources.
    
    - Validates deposit amount is positive
    - Validates source (bank card, e-wallet, or manual)
    - Creates transaction record with encrypted note
    - Updates wallet balance
    """
    try:
        wallet = get_user_wallet(current_user, db)
        
        # Validate amount
        if deposit_request.amount <= 0:
            raise HTTPException(status_code=400, detail="Số tiền nạp phải lớn hơn 0")
        
        from app.core.config import settings
        if deposit_request.amount > settings.MAX_DEPOSIT_AMOUNT:
            raise HTTPException(
                status_code=400, 
                detail=f"Số tiền nạp vượt quá giới hạn ({settings.MAX_DEPOSIT_AMOUNT:,.0f}₫)"
            )
        
        # Handle different source types
        note = "Nạp tiền"
        if deposit_request.source_type == "bank_card":
            if not deposit_request.source_id:
                raise HTTPException(status_code=400, detail="Vui lòng chọn thẻ ngân hàng")
            if not deposit_request.transaction_pin:
                raise HTTPException(status_code=400, detail="Vui lòng nhập mã PIN giao dịch")
            
            # Verify PIN
            if not verify_password(deposit_request.transaction_pin, current_user.transaction_pin_hash):
                raise HTTPException(status_code=400, detail="Mã PIN giao dịch không đúng")
            
            # Check if card exists and is verified
            bank_card = db.query(BankCard).filter(
                BankCard.id == deposit_request.source_id,
                BankCard.user_id == current_user.id,
                BankCard.is_verified == True
            ).first()
            
            if not bank_card:
                raise HTTPException(status_code=404, detail="Thẻ ngân hàng không tồn tại hoặc chưa được xác thực")
            
            note = f"Nạp tiền từ thẻ {bank_card.bank_name} •••• {bank_card.card_number_encrypted[-4:]}"
            
        elif deposit_request.source_type == "momo":
            note = "Nạp tiền từ MoMo"
        elif deposit_request.source_type == "zalopay":
            note = "Nạp tiền từ ZaloPay"
        else:  # manual
            note = "Nạp tiền thủ công"
        
        wallet.balance += deposit_request.amount
        
        transaction = Transaction(
            sender_id=None,  # System deposit
            receiver_id=current_user.id,
            amount=deposit_request.amount,
            encrypted_note=encryption_service.encrypt(note)
        )
        
        db.add(transaction)
        db.commit()
        db.refresh(wallet)
        
        # Create notification for deposit
        try:
            create_transaction_notification(
                db=db,
                user_id=current_user.id,
                transaction_type='deposit',
                amount=deposit_request.amount,
                note=note
            )
        except Exception as e:
            # Don't fail the deposit if notification fails
            import logging
            logging.getLogger(__name__).error(f"Failed to create deposit notification: {e}")
        
        return wallet
        
    except HTTPException:
        raise
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Lỗi cơ sở dữ liệu")
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Đã xảy ra lỗi không mong muốn")

@router.post("/withdraw", response_model=WalletResponse)
@limiter.limit(WALLET_OPERATION_LIMIT)
async def withdraw(
    request: Request,
    withdraw_request: WithdrawRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Withdraw funds from wallet to various destinations.
    
    - Validates withdrawal amount is positive and available
    - Validates destination (bank card, e-wallet, or manual)
    - Creates transaction record with encrypted note
    - Updates wallet balance
    """
    try:
        wallet = get_user_wallet(current_user, db)
        
        # Validate amount
        if withdraw_request.amount <= 0:
            raise HTTPException(status_code=400, detail="Số tiền rút phải lớn hơn 0")
        
        if wallet.balance < withdraw_request.amount:
            raise HTTPException(
                status_code=400,
                detail=f"Số dư không đủ. Số dư khả dụng: {wallet.balance:,.0f}₫"
            )
        
        # Handle different destination types
        note = "Rút tiền"
        if withdraw_request.destination_type == "bank_card":
            if not withdraw_request.destination_id:
                raise HTTPException(status_code=400, detail="Vui lòng chọn thẻ ngân hàng")
            if not withdraw_request.transaction_pin:
                raise HTTPException(status_code=400, detail="Vui lòng nhập mã PIN giao dịch")
            
            # Verify PIN
            if not verify_password(withdraw_request.transaction_pin, current_user.transaction_pin_hash):
                raise HTTPException(status_code=400, detail="Mã PIN giao dịch không đúng")
            
            # Check if card exists and is verified
            bank_card = db.query(BankCard).filter(
                BankCard.id == withdraw_request.destination_id,
                BankCard.user_id == current_user.id,
                BankCard.is_verified == True
            ).first()
            
            if not bank_card:
                raise HTTPException(status_code=404, detail="Thẻ ngân hàng không tồn tại hoặc chưa được xác thực")
            
            note = f"Rút tiền về thẻ {bank_card.bank_name} •••• {bank_card.card_number_encrypted[-4:]}"
            
        elif withdraw_request.destination_type == "momo":
            note = "Rút tiền về MoMo"
        elif withdraw_request.destination_type == "zalopay":
            note = "Rút tiền về ZaloPay"
        else:  # manual
            note = "Rút tiền thủ công"
        
        wallet.balance -= withdraw_request.amount
        
        transaction = Transaction(
            sender_id=current_user.id,
            receiver_id=None,  # System withdraw
            amount=withdraw_request.amount,
            encrypted_note=encryption_service.encrypt(note)
        )
        
        db.add(transaction)
        db.commit()
        db.refresh(wallet)
        
        # Create notification for withdrawal
        try:
            create_transaction_notification(
                db=db,
                user_id=current_user.id,
                transaction_type='withdraw',
                amount=withdraw_request.amount,
                note=note
            )
        except Exception as e:
            # Don't fail the withdrawal if notification fails
            import logging
            logging.getLogger(__name__).error(f"Failed to create withdraw notification: {e}")
        
        return wallet
        
    except HTTPException:
        raise
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Lỗi cơ sở dữ liệu")
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Đã xảy ra lỗi không mong muốn")

@router.post("/transfer/request-otp")
@limiter.limit(WALLET_OPERATION_LIMIT)
async def request_transfer_otp(
    request: Request,
    otp_request: TransferOTPRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Request OTP for large transfer.
    
    - Requires valid transaction PIN before sending OTP
    - Sends OTP via email for all transfers
    """
    if not current_user.transaction_pin_hash:
        raise HTTPException(
            status_code=400,
            detail="Transaction PIN not set. Please set it in settings."
        )
    
    if not verify_password(otp_request.transaction_pin, current_user.transaction_pin_hash):
        raise HTTPException(status_code=400, detail="Invalid transaction PIN")
    
    # Generate new OTP
    otp_secret = otp_service.generate_secret()
    otp_code = otp_service.generate_otp(otp_secret)
    
    # Update user's OTP secret and timestamp
    current_user.otp_secret = otp_secret
    current_user.otp_created_at = datetime.utcnow()
    db.commit()
    
    # Print OTP to console IMMEDIATELY (before attempting email)
    # This ensures user can always see OTP even if email is slow/fails
    print(f"\n{'='*60}")
    print(f"OTP for transfer verification:")
    print(f"  Email: {current_user.email}")
    print(f"  OTP Code: {otp_code}")
    print(f"  Amount: {otp_request.amount:,.0f}₫")
    print(f"  To: {otp_request.receiver_email}")
    print(f"  Valid for: {settings.OTP_EXPIRY_MINUTES} minutes")
    print(f"{'='*60}\n")
    
    # Send OTP via email in background (truly fire-and-forget, non-blocking)
    send_email_async(
        to_email=current_user.email,
        subject="E-Wallet - Transfer Verification Code",
        html_content=f"""
        <h2>Transfer Verification Required</h2>
        <p>You are attempting to transfer <strong>{otp_request.amount:,.0f}₫</strong> to <strong>{otp_request.receiver_email}</strong>.</p>
        <p>Your verification code is: <strong style="font-size: 24px; color: #4CAF50;">{otp_code}</strong></p>
        <p>This code will expire in {settings.OTP_EXPIRY_MINUTES} minutes.</p>
        <p><em>If you did not initiate this transfer, please secure your account immediately.</em></p>
        """
    )
    
    return {"message": "OTP sent to your email (or check console/logs)", "otp_required": True}

@router.post("/transfer", response_model=TransactionResponse)
@limiter.limit(WALLET_OPERATION_LIMIT)
async def transfer(
    request: Request,
    transfer_request: TransferRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Transfer funds to another user.
    
    - Validates transfer amount is positive and available
    - Requires transaction PIN and OTP verification for all transfers
    - Finds receiver by email
    - Creates transaction record with encrypted note
    - Updates both sender and receiver wallet balances atomically
    """
    try:
        sender_wallet = get_user_wallet(current_user, db)
        
        # Validate amount
        if transfer_request.amount <= 0:
            raise HTTPException(status_code=400, detail="Transfer amount must be positive")
        
        if sender_wallet.balance < transfer_request.amount:
            raise HTTPException(
                status_code=400,
                detail=f"Insufficient funds. Available balance: {sender_wallet.balance}"
            )
        
        # Verify transaction PIN
        if not current_user.transaction_pin_hash:
            raise HTTPException(
                status_code=400,
                detail="Transaction PIN not set. Please set it in settings."
            )
        
        if not verify_password(transfer_request.transaction_pin, current_user.transaction_pin_hash):
            raise HTTPException(status_code=400, detail="Invalid transaction PIN")
        
        # Require and verify OTP for all transfers
        if not transfer_request.otp_code:
            raise HTTPException(
                status_code=400,
                detail="OTP required for transfers. Please request OTP first."
            )
        
        if not current_user.otp_created_at or not current_user.otp_secret:
            raise HTTPException(status_code=400, detail="No OTP request found. Please request OTP again.")
        
        expiry_time = current_user.otp_created_at + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
        if datetime.utcnow() > expiry_time:
            raise HTTPException(status_code=400, detail="OTP has expired. Please request a new one.")
        
        if not otp_service.verify_otp(current_user.otp_secret, transfer_request.otp_code):
            raise HTTPException(status_code=400, detail="Invalid OTP")
        
        # Find receiver
        receiver = db.query(User).filter(User.email == transfer_request.receiver_email).first()
        if not receiver:
            raise HTTPException(status_code=404, detail="Receiver not found")
        
        if receiver.id == current_user.id:
            raise HTTPException(status_code=400, detail="Cannot transfer to yourself")
        
        if not receiver.is_verified:
            raise HTTPException(status_code=400, detail="Receiver's email is not verified")
            
        receiver_wallet = get_user_wallet(receiver, db)
        
        # Atomic transaction
        sender_wallet.balance -= transfer_request.amount
        receiver_wallet.balance += transfer_request.amount
        
        note = transfer_request.note or "Transfer"
        encrypted_note = encryption_service.encrypt(note)
        
        transaction = Transaction(
            sender_id=current_user.id,
            receiver_id=receiver.id,
            amount=transfer_request.amount,
            encrypted_note=encrypted_note
        )
        
        db.add(transaction)
        db.commit()
        db.refresh(transaction)
        
        # Create notifications for both sender and receiver
        try:
            # Notification for sender (transfer_out)
            create_transaction_notification(
                db=db,
                user_id=current_user.id,
                transaction_type='transfer_out',
                amount=transfer_request.amount,
                note=f"Chuyển đến {transfer_request.receiver_email}"
            )
            
            # Notification for receiver (transfer_in)
            create_transaction_notification(
                db=db,
                user_id=receiver.id,
                transaction_type='transfer_in',
                amount=transfer_request.amount,
                note=f"Nhận từ {current_user.email}"
            )
        except Exception as e:
            # Don't fail the transfer if notification fails
            import logging
            logging.getLogger(__name__).error(f"Failed to create transfer notifications: {e}")
        
        return TransactionResponse(
            id=transaction.id,
            sender_id=transaction.sender_id,
            receiver_id=transaction.receiver_id,
            amount=transaction.amount,
            timestamp=transaction.timestamp,
            note=note,  # Return decrypted note to sender
            type="transfer_out"
        )
        
    except HTTPException:
        raise
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error occurred")
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="An unexpected error occurred")

@router.get("/transactions", response_model=List[TransactionResponse])
@limiter.limit(GENERAL_LIMIT)
async def get_transactions(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get transaction history for current user.
    
    - Returns all transactions where user is sender or receiver
    - Decrypts transaction notes
    - Orders by timestamp (most recent first)
    """
    try:
        # Get transactions where user is sender or receiver
        transactions = db.query(Transaction).filter(
            (Transaction.sender_id == current_user.id) | (Transaction.receiver_id == current_user.id)
        ).order_by(Transaction.timestamp.desc()).all()
        
        result = []
        for tx in transactions:
            # Safely decrypt note
            try:
                note = encryption_service.decrypt(tx.encrypted_note)
            except Exception as e:
                note = "Error decrypting note"
            
            # Determine transaction type
            tx_type = "unknown"
            if tx.sender_id == current_user.id and tx.receiver_id:
                tx_type = "transfer_out"
            elif tx.receiver_id == current_user.id and tx.sender_id:
                tx_type = "transfer_in"
            elif tx.receiver_id == current_user.id and not tx.sender_id:
                tx_type = "deposit"
            elif tx.sender_id == current_user.id and not tx.receiver_id:
                tx_type = "withdraw"
                
            result.append(TransactionResponse(
                id=tx.id,
                sender_id=tx.sender_id,
                receiver_id=tx.receiver_id,
                amount=tx.amount,
                timestamp=tx.timestamp,
                note=note,
                type=tx_type
            ))
            
        return result
        
    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error occurred")
    except Exception as e:
        raise HTTPException(status_code=500, detail="An unexpected error occurred")


@router.post("/deposit-from-card", response_model=WalletResponse)
@limiter.limit(WALLET_OPERATION_LIMIT)
async def deposit_from_card(
    request: Request,
    deposit_request: DepositFromCardRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Deposit funds from a linked bank card.
    
    - Validates card belongs to user and is verified
    - Validates transaction PIN
    - Creates deposit transaction
    - Updates wallet balance
    """
    # Get and validate card
    card = db.query(BankCard).filter(
        BankCard.id == deposit_request.card_id,
        BankCard.user_id == current_user.id
    ).first()
    
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bank card not found"
        )
    
    if not card.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Card must be verified before use"
        )
    
    # Verify transaction PIN
    if not current_user.transaction_pin_hash:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transaction PIN not set"
        )
    
    from app.core.security import verify_password
    if not verify_password(deposit_request.transaction_pin, current_user.transaction_pin_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid transaction PIN"
        )
    
    # Get wallet
    wallet = get_user_wallet(current_user, db)
    
    # Create transaction
    transaction = Transaction(
        id=str(uuid.uuid4()),
        sender_id=None,
        receiver_id=current_user.id,
        amount=deposit_request.amount,
        type="deposit",
        timestamp=datetime.utcnow()
    )
    
    # Update wallet balance
    wallet.balance += deposit_request.amount
    
    db.add(transaction)
    db.commit()
    db.refresh(wallet)
    
    return wallet


@router.post("/withdraw-to-card", response_model=WalletResponse)
@limiter.limit(WALLET_OPERATION_LIMIT)
async def withdraw_to_card(
    request: Request,
    withdraw_request: WithdrawToCardRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Withdraw funds to a linked bank card.
    
    - Validates card belongs to user and is verified
    - Validates transaction PIN
    - Checks sufficient balance
    - Creates withdrawal transaction
    - Updates wallet balance
    """
    # Get and validate card
    card = db.query(BankCard).filter(
        BankCard.id == withdraw_request.card_id,
        BankCard.user_id == current_user.id
    ).first()
    
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bank card not found"
        )
    
    if not card.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Card must be verified before use"
        )
    
    # Verify transaction PIN
    if not current_user.transaction_pin_hash:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transaction PIN not set"
        )
    
    from app.core.security import verify_password
    if not verify_password(withdraw_request.transaction_pin, current_user.transaction_pin_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid transaction PIN"
        )
    
    # Get wallet
    wallet = get_user_wallet(current_user, db)
    
    # Check balance
    if wallet.balance < withdraw_request.amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Insufficient funds"
        )
    
    # Create transaction
    transaction = Transaction(
        id=str(uuid.uuid4()),
        sender_id=current_user.id,
        receiver_id=None,
        amount=withdraw_request.amount,
        type="withdraw",
        timestamp=datetime.utcnow()
    )
    
    # Update wallet balance
    wallet.balance -= withdraw_request.amount
    
    db.add(transaction)
    db.commit()
    db.refresh(wallet)
    
    return wallet
