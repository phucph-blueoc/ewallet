from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timedelta
import uuid

from app.core.database import get_db
from app.core.security import get_current_user, verify_password
from app.core.rate_limit import limiter, GENERAL_LIMIT, WALLET_OPERATION_LIMIT
from app.models import User, BillProvider, SavedBill, BillTransaction, Wallet, Transaction
from app.schemas import (
    BillProviderResponse,
    SavedBillCreate,
    SavedBillUpdate,
    SavedBillResponse,
    BillCheckRequest,
    BillCheckResponse,
    BillInfo,
    BillPayRequest,
    BillPayResponse,
    BillHistoryResponse,
)
from app.api.v1.endpoints.wallets import get_user_wallet

router = APIRouter()


@router.get("/providers", response_model=List[BillProviderResponse])
@limiter.limit(GENERAL_LIMIT)
async def get_bill_providers(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get list of active bill providers."""
    providers = db.query(BillProvider).filter(BillProvider.is_active == True).all()
    return providers


@router.post("/check", response_model=BillCheckResponse)
@limiter.limit(GENERAL_LIMIT)
async def check_bill(
    request: Request,
    check_request: BillCheckRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Check if there's an unpaid bill for the given customer code.
    
    In a real system, this would call the provider's API to check for bills.
    For demo purposes, we simulate checking bills.
    """
    provider = db.query(BillProvider).filter(BillProvider.id == check_request.provider_id).first()
    if not provider:
        raise HTTPException(status_code=404, detail="Bill provider not found")
    
    # Simulate bill checking - in real system, call provider API
    # For demo: randomly return a bill 70% of the time
    import random
    has_bill = random.random() < 0.7
    
    if has_bill:
        # Generate a random bill amount between 50k and 500k
        amount = random.randint(50000, 500000)
        bill_period = datetime.now().strftime("%m/%Y")
        
        bill_info = BillInfo(
            customer_code=check_request.customer_code,
            customer_name=f"Khách hàng {check_request.customer_code[-4:]}",
            amount=amount,
            bill_period=bill_period,
            due_date=datetime.now() + timedelta(days=15),
            description=f"Hóa đơn {provider.name} tháng {bill_period}"
        )
        
        return BillCheckResponse(
            has_bill=True,
            bill_info=bill_info,
            message=f"Tìm thấy hóa đơn chưa thanh toán"
        )
    else:
        return BillCheckResponse(
            has_bill=False,
            message="Không tìm thấy hóa đơn chưa thanh toán"
        )


@router.post("/pay", response_model=BillPayResponse)
@limiter.limit(WALLET_OPERATION_LIMIT)
async def pay_bill(
    request: Request,
    pay_request: BillPayRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Pay a bill.
    
    - Verifies transaction PIN
    - Checks wallet balance
    - Creates transaction record
    - Creates bill transaction record
    - Optionally saves bill for future payments
    """
    # Verify transaction PIN
    if not verify_password(pay_request.transaction_pin, current_user.transaction_pin_hash):
        raise HTTPException(status_code=400, detail="Mã PIN giao dịch không đúng")
    
    # Check provider exists
    provider = db.query(BillProvider).filter(BillProvider.id == pay_request.provider_id).first()
    if not provider:
        raise HTTPException(status_code=404, detail="Nhà cung cấp không tồn tại")
    
    # Get user wallet
    wallet = get_user_wallet(current_user, db)
    if wallet.balance < pay_request.amount:
        raise HTTPException(
            status_code=400, 
            detail=f"Số dư không đủ để thanh toán. Số dư hiện tại: {wallet.balance:,.0f}₫, Số tiền cần thanh toán: {pay_request.amount:,.0f}₫. Vui lòng nạp thêm tiền vào ví."
        )
    
    # Deduct from wallet
    wallet.balance -= pay_request.amount
    
    # Create transaction record
    note = f"Thanh toán hóa đơn {provider.name} - Mã KH: {pay_request.customer_code}"
    from app.core.encryption import encryption_service
    encrypted_note = encryption_service.encrypt(note)
    
    transaction = Transaction(
        sender_id=current_user.id,
        receiver_id=None,  # Bill payment has no receiver
        amount=pay_request.amount,
        encrypted_note=encrypted_note
    )
    db.add(transaction)
    db.flush()  # Get transaction ID
    
    # Create bill transaction record
    bill_period = datetime.now().strftime("%m/%Y")
    bill_transaction = BillTransaction(
        user_id=current_user.id,
        provider_id=pay_request.provider_id,
        customer_code=pay_request.customer_code,
        amount=pay_request.amount,
        bill_period=bill_period,
        transaction_id=transaction.id
    )
    db.add(bill_transaction)
    
    # Save bill if requested
    if pay_request.save_bill:
        # Check if already saved
        existing = db.query(SavedBill).filter(
            SavedBill.user_id == current_user.id,
            SavedBill.provider_id == pay_request.provider_id,
            SavedBill.customer_code == pay_request.customer_code
        ).first()
        
        if not existing:
            saved_bill = SavedBill(
                user_id=current_user.id,
                provider_id=pay_request.provider_id,
                customer_code=pay_request.customer_code,
                alias=pay_request.alias
            )
            db.add(saved_bill)
        elif pay_request.alias:
            existing.alias = pay_request.alias
    
    db.commit()
    db.refresh(bill_transaction)
    db.refresh(transaction)
    
    return BillPayResponse(
        bill_transaction_id=bill_transaction.id,
        transaction_id=transaction.id,
        amount=pay_request.amount,
        bill_period=bill_period,
        paid_at=bill_transaction.created_at
    )


@router.get("/saved", response_model=List[SavedBillResponse])
@limiter.limit(GENERAL_LIMIT)
async def get_saved_bills(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's saved bills."""
    saved_bills = db.query(SavedBill).filter(SavedBill.user_id == current_user.id).all()
    
    result = []
    for saved_bill in saved_bills:
        result.append(SavedBillResponse(
            id=saved_bill.id,
            user_id=saved_bill.user_id,
            provider_id=saved_bill.provider_id,
            provider_name=saved_bill.provider.name,
            customer_code=saved_bill.customer_code,
            customer_name=saved_bill.customer_name,
            alias=saved_bill.alias,
            created_at=saved_bill.created_at,
            updated_at=saved_bill.updated_at
        ))
    
    return result


@router.post("/saved", response_model=SavedBillResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(GENERAL_LIMIT)
async def create_saved_bill(
    request: Request,
    saved_bill: SavedBillCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Save a bill for future payments."""
    # Check if already exists
    existing = db.query(SavedBill).filter(
        SavedBill.user_id == current_user.id,
        SavedBill.provider_id == saved_bill.provider_id,
        SavedBill.customer_code == saved_bill.customer_code
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Hóa đơn đã được lưu")
    
    provider = db.query(BillProvider).filter(BillProvider.id == saved_bill.provider_id).first()
    if not provider:
        raise HTTPException(status_code=404, detail="Nhà cung cấp không tồn tại")
    
    new_saved_bill = SavedBill(
        user_id=current_user.id,
        provider_id=saved_bill.provider_id,
        customer_code=saved_bill.customer_code,
        customer_name=saved_bill.customer_name,
        alias=saved_bill.alias
    )
    db.add(new_saved_bill)
    db.commit()
    db.refresh(new_saved_bill)
    
    return SavedBillResponse(
        id=new_saved_bill.id,
        user_id=new_saved_bill.user_id,
        provider_id=new_saved_bill.provider_id,
        provider_name=provider.name,
        customer_code=new_saved_bill.customer_code,
        customer_name=new_saved_bill.customer_name,
        alias=new_saved_bill.alias,
        created_at=new_saved_bill.created_at,
        updated_at=new_saved_bill.updated_at
    )


@router.put("/saved/{saved_bill_id}", response_model=SavedBillResponse)
@limiter.limit(GENERAL_LIMIT)
async def update_saved_bill(
    request: Request,
    saved_bill_id: str,
    saved_bill_update: SavedBillUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update a saved bill."""
    saved_bill = db.query(SavedBill).filter(
        SavedBill.id == saved_bill_id,
        SavedBill.user_id == current_user.id
    ).first()
    
    if not saved_bill:
        raise HTTPException(status_code=404, detail="Hóa đơn đã lưu không tồn tại")
    
    if saved_bill_update.customer_name is not None:
        saved_bill.customer_name = saved_bill_update.customer_name
    if saved_bill_update.alias is not None:
        saved_bill.alias = saved_bill_update.alias
    
    db.commit()
    db.refresh(saved_bill)
    
    return SavedBillResponse(
        id=saved_bill.id,
        user_id=saved_bill.user_id,
        provider_id=saved_bill.provider_id,
        provider_name=saved_bill.provider.name,
        customer_code=saved_bill.customer_code,
        customer_name=saved_bill.customer_name,
        alias=saved_bill.alias,
        created_at=saved_bill.created_at,
        updated_at=saved_bill.updated_at
    )


@router.delete("/saved/{saved_bill_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(GENERAL_LIMIT)
async def delete_saved_bill(
    request: Request,
    saved_bill_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a saved bill."""
    saved_bill = db.query(SavedBill).filter(
        SavedBill.id == saved_bill_id,
        SavedBill.user_id == current_user.id
    ).first()
    
    if not saved_bill:
        raise HTTPException(status_code=404, detail="Hóa đơn đã lưu không tồn tại")
    
    db.delete(saved_bill)
    db.commit()


@router.get("/history", response_model=List[BillHistoryResponse])
@limiter.limit(GENERAL_LIMIT)
async def get_bill_history(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get bill payment history."""
    bill_transactions = db.query(BillTransaction).filter(
        BillTransaction.user_id == current_user.id
    ).order_by(BillTransaction.created_at.desc()).limit(50).all()
    
    result = []
    for bt in bill_transactions:
        result.append(BillHistoryResponse(
            id=bt.id,
            provider_id=bt.provider_id,
            provider_name=bt.provider.name,
            customer_code=bt.customer_code,
            amount=float(bt.amount),
            bill_period=bt.bill_period,
            transaction_id=bt.transaction_id,
            created_at=bt.created_at
        ))
    
    return result

