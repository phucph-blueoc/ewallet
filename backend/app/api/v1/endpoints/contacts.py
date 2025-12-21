from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from sqlalchemy import func, or_
from typing import List
from datetime import datetime

from app.core.database import get_db
from app.core.security import get_current_user
from app.core.rate_limit import limiter, GENERAL_LIMIT
from app.models import User, Contact, Transaction
from app.schemas import (
    ContactCreate,
    ContactUpdate,
    ContactResponse,
    ContactStatsResponse,
)

router = APIRouter()


@router.post("", response_model=ContactResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(GENERAL_LIMIT)
async def create_contact(
    request: Request,
    contact: ContactCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a new contact.
    
    - Validates email is not already in user's contacts
    - Creates contact record
    """
    # Check if contact with same email already exists for this user
    existing_contact = db.query(Contact).filter(
        Contact.user_id == current_user.id,
        Contact.email == contact.email
    ).first()
    
    if existing_contact:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contact with this email already exists"
        )
    
    # Create new contact
    db_contact = Contact(
        user_id=current_user.id,
        name=contact.name,
        email=contact.email,
        phone=contact.phone,
        avatar_url=contact.avatar_url,
        notes=contact.notes
    )
    
    db.add(db_contact)
    db.commit()
    db.refresh(db_contact)
    
    return db_contact


@router.get("", response_model=List[ContactResponse])
@limiter.limit(GENERAL_LIMIT)
async def get_contacts(
    request: Request,
    search: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all contacts for current user.
    
    - Returns list of contacts
    - Optional search by name, email, or phone
    """
    query = db.query(Contact).filter(Contact.user_id == current_user.id)
    
    if search:
        search_filter = or_(
            Contact.name.ilike(f"%{search}%"),
            Contact.email.ilike(f"%{search}%"),
            Contact.phone.ilike(f"%{search}%")
        )
        query = query.filter(search_filter)
    
    contacts = query.order_by(Contact.name.asc()).all()
    return contacts


@router.get("/{contact_id}", response_model=ContactResponse)
@limiter.limit(GENERAL_LIMIT)
async def get_contact(
    request: Request,
    contact_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get a specific contact by ID.
    
    - Returns contact details
    - Only returns contacts belonging to current user
    """
    contact = db.query(Contact).filter(
        Contact.id == contact_id,
        Contact.user_id == current_user.id
    ).first()
    
    if not contact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact not found"
        )
    
    return contact


@router.put("/{contact_id}", response_model=ContactResponse)
@limiter.limit(GENERAL_LIMIT)
async def update_contact(
    request: Request,
    contact_id: str,
    contact_update: ContactUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update a contact.
    
    - Updates only provided fields
    - Validates email uniqueness if email is being updated
    """
    contact = db.query(Contact).filter(
        Contact.id == contact_id,
        Contact.user_id == current_user.id
    ).first()
    
    if not contact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact not found"
        )
    
    # Check email uniqueness if email is being updated
    if contact_update.email and contact_update.email != contact.email:
        existing_contact = db.query(Contact).filter(
            Contact.user_id == current_user.id,
            Contact.email == contact_update.email,
            Contact.id != contact_id
        ).first()
        
        if existing_contact:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Contact with this email already exists"
            )
    
    # Update fields
    update_data = contact_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(contact, field, value)
    
    contact.updated_at = datetime.utcnow()
    
    db.commit()
    db.refresh(contact)
    
    return contact


@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(GENERAL_LIMIT)
async def delete_contact(
    request: Request,
    contact_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete a contact.
    
    - Removes contact from user's contact list
    - Does not affect transaction history
    """
    contact = db.query(Contact).filter(
        Contact.id == contact_id,
        Contact.user_id == current_user.id
    ).first()
    
    if not contact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact not found"
        )
    
    db.delete(contact)
    db.commit()
    
    return None


@router.get("/{contact_id}/stats", response_model=ContactStatsResponse)
@limiter.limit(GENERAL_LIMIT)
async def get_contact_stats(
    request: Request,
    contact_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get transaction statistics for a contact.
    
    - Returns total transactions, amounts sent/received
    - Only includes transactions with this contact
    """
    # Verify contact belongs to user
    contact = db.query(Contact).filter(
        Contact.id == contact_id,
        Contact.user_id == current_user.id
    ).first()
    
    if not contact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contact not found"
        )
    
    # Get receiver user by email
    receiver_user = db.query(User).filter(User.email == contact.email).first()
    
    if not receiver_user:
        # No transactions if receiver doesn't exist
        return ContactStatsResponse(
            contact_id=contact_id,
            contact_name=contact.name,
            total_transactions=0,
            total_amount_sent=0.0,
            total_amount_received=0.0,
            last_transaction_date=None
        )
    
    # Get all transactions with this contact
    transactions = db.query(Transaction).filter(
        or_(
            (Transaction.sender_id == current_user.id) & (Transaction.receiver_id == receiver_user.id),
            (Transaction.sender_id == receiver_user.id) & (Transaction.receiver_id == current_user.id)
        )
    ).all()
    
    total_transactions = len(transactions)
    total_amount_sent = sum(
        t.amount for t in transactions 
        if t.sender_id == current_user.id
    )
    total_amount_received = sum(
        t.amount for t in transactions 
        if t.receiver_id == current_user.id
    )
    
    last_transaction = max(transactions, key=lambda t: t.timestamp) if transactions else None
    
    return ContactStatsResponse(
        contact_id=contact_id,
        contact_name=contact.name,
        total_transactions=total_transactions,
        total_amount_sent=total_amount_sent,
        total_amount_received=total_amount_received,
        last_transaction_date=last_transaction.timestamp if last_transaction else None
    )

