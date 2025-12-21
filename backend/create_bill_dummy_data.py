"""
Script to create dummy bill data for a specific user.

Usage:
    python create_bill_dummy_data.py
"""

import sys
import random
from datetime import datetime, timedelta

# Add parent directory to path to import app modules
sys.path.insert(0, '.')

from app.core.database import SessionLocal
from app.models import User, BillProvider, SavedBill, BillTransaction, Transaction, Wallet
from app.core.encryption import encryption_service

# Sample customer codes for different providers
CUSTOMER_CODES = {
    'EVN': ['EVN001234567', 'EVN001234568', 'EVN001234569', 'EVN001234570', 'EVN001234571'],
    'SAVACO': ['SAV001234567', 'SAV001234568', 'SAV001234569', 'SAV001234570'],
    'FPT': ['FPT001234567', 'FPT001234568', 'FPT001234569', 'FPT001234570'],
    'VIETTEL': ['VT001234567', 'VT001234568', 'VT001234569', 'VT001234570'],
    'VINAPHONE': ['VP001234567', 'VP001234568', 'VP001234569'],
    'MOBIFONE': ['MF001234567', 'MF001234568', 'MF001234569'],
}

# Sample aliases for saved bills
BILL_ALIASES = [
    'Hóa đơn nhà',
    'Hóa đơn điện',
    'Hóa đơn nước',
    'Hóa đơn internet',
    'Hóa đơn điện thoại',
    'Nhà riêng',
    'Căn hộ',
    'Văn phòng',
    'Cửa hàng',
    'Nhà trọ',
    'Chung cư',
    'Biệt thự',
]


def find_user_by_email(db, email: str):
    """Find user by email."""
    user = db.query(User).filter(User.email == email).first()
    return user


def get_bill_providers(db):
    """Get all active bill providers."""
    providers = db.query(BillProvider).filter(BillProvider.is_active == True).all()
    return {p.code: p for p in providers}


def create_saved_bills(db, user: User, providers: dict, num_bills: int = 5):
    """Create saved bills for the user."""
    print(f"\n📝 Creating {num_bills} saved bills...")
    
    saved_bills = []
    provider_codes = list(providers.keys())
    
    for i in range(num_bills):
        # Select random provider
        provider_code = random.choice(provider_codes)
        provider = providers[provider_code]
        
        # Get customer code for this provider
        customer_codes = CUSTOMER_CODES.get(provider_code, [f'{provider_code}001234567'])
        customer_code = random.choice(customer_codes)
        
        # Check if already exists
        existing = db.query(SavedBill).filter(
            SavedBill.user_id == user.id,
            SavedBill.provider_id == provider.id,
            SavedBill.customer_code == customer_code
        ).first()
        
        if existing:
            print(f"  ⚠️  Saved bill already exists: {provider.name} - {customer_code}")
            saved_bills.append(existing)
            continue
        
        # Create saved bill
        alias = random.choice(BILL_ALIASES) if i < len(BILL_ALIASES) else None
        customer_name = f"Khách hàng {customer_code[-4:]}"
        
        saved_bill = SavedBill(
            user_id=user.id,
            provider_id=provider.id,
            customer_code=customer_code,
            customer_name=customer_name,
            alias=alias
        )
        
        db.add(saved_bill)
        saved_bills.append(saved_bill)
        print(f"  ✓ Created saved bill: {provider.name} - {customer_code} ({alias or 'No alias'})")
    
    db.commit()
    return saved_bills


def create_bill_transactions(db, user: User, providers: dict, num_transactions: int = 10):
    """Create bill payment transactions for the user."""
    print(f"\n💳 Creating {num_transactions} bill payment transactions...")
    
    # Get user wallet
    wallet = db.query(Wallet).filter(Wallet.user_id == user.id).first()
    if not wallet:
        print("  ❌ User wallet not found!")
        return []
    
    provider_codes = list(providers.keys())
    bill_transactions = []
    
    # Create transactions over the past 6 months
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=180)
    
    created_count = 0
    skipped_count = 0
    
    for i in range(num_transactions):
        # Random date within the past 6 months
        days_ago = random.randint(0, 180)
        transaction_date = end_date - timedelta(days=days_ago)
        
        # Select random provider
        provider_code = random.choice(provider_codes)
        provider = providers[provider_code]
        
        # Get customer code
        customer_codes = CUSTOMER_CODES.get(provider_code, [f'{provider_code}001234567'])
        customer_code = random.choice(customer_codes)
        
        # Random amount between 50k and 500k
        amount = random.uniform(50000, 500000)
        
        # Check if wallet has enough balance
        if wallet.balance < amount:
            skipped_count += 1
            print(f"  ⚠️  Skipped bill transaction: {provider.name} - {amount:,.0f}₫ (Không đủ số dư: {wallet.balance:,.0f}₫)")
            continue
        
        # Bill period (month/year)
        bill_period = transaction_date.strftime("%m/%Y")
        
        # Create transaction record
        note = f"Thanh toán hóa đơn {provider.name} - Mã KH: {customer_code}"
        encrypted_note = encryption_service.encrypt(note)
        
        transaction = Transaction(
            sender_id=user.id,
            receiver_id=None,  # Bill payment has no receiver
            amount=amount,
            timestamp=transaction_date,
            encrypted_note=encrypted_note
        )
        
        db.add(transaction)
        db.flush()  # Get transaction.id
        
        # Create bill transaction record
        bill_transaction = BillTransaction(
            user_id=user.id,
            provider_id=provider.id,
            customer_code=customer_code,
            amount=amount,
            bill_period=bill_period,
            transaction_id=transaction.id
        )
        
        db.add(bill_transaction)
        bill_transactions.append(bill_transaction)
        
        # Update wallet balance (deduct)
        wallet.balance -= amount
        created_count += 1
        
        print(f"  ✓ Created bill transaction: {provider.name} - {amount:,.0f}₫ - {bill_period}")
    
    if skipped_count > 0:
        print(f"\n  ⚠️  Skipped {skipped_count} transactions due to insufficient balance")
    
    db.commit()
    print(f"\n  💰 Updated wallet balance: {wallet.balance:,.0f}₫")
    
    return bill_transactions


def main():
    """Main function."""
    print("=" * 60)
    print("📄 Bill Dummy Data Generator")
    print("=" * 60)
    
    email = "phuc.phamhong@blueoc.tech"
    
    # Create database session
    db = SessionLocal()
    
    try:
        # Find user
        print(f"\n🔍 Looking for user: {email}")
        user = find_user_by_email(db, email)
        
        if not user:
            print(f"  ❌ User not found: {email}")
            print("\nAvailable users:")
            users = db.query(User).all()
            for u in users[:10]:
                print(f"    - {u.email} ({u.full_name})")
            if len(users) > 10:
                print(f"    ... and {len(users) - 10} more users")
            return
        
        print(f"  ✓ Found user: {user.full_name} ({user.email})")
        
        # Get bill providers
        print("\n🔍 Loading bill providers...")
        providers = get_bill_providers(db)
        if not providers:
            print("  ❌ No bill providers found! Please run migrations first.")
            return
        
        print(f"  ✓ Found {len(providers)} providers:")
        for code, provider in providers.items():
            print(f"    - {provider.name} ({code})")
        
        # Auto-confirm (can be changed to ask for confirmation if needed)
        print("\n" + "=" * 60)
        print("⚠️  Creating dummy bill data...")
        
        # Create saved bills
        num_saved_bills = 8  # Tăng số lượng hóa đơn đã lưu
        saved_bills = create_saved_bills(db, user, providers, num_saved_bills)
        
        # Create bill transactions
        num_transactions = 15  # Tăng số lượng giao dịch thanh toán
        bill_transactions = create_bill_transactions(db, user, providers, num_transactions)
        
        # Summary
        print("\n" + "=" * 60)
        print("✅ Bill dummy data creation completed!")
        print("=" * 60)
        print(f"\n📝 Summary:")
        print(f"  - User: {user.full_name} ({user.email})")
        print(f"  - Saved bills created: {len(saved_bills)}")
        print(f"  - Bill transactions created: {len(bill_transactions)}")
        print(f"\n💡 You can now view bills in the app!")
        print()
        
    except Exception as e:
        db.rollback()
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()


if __name__ == "__main__":
    main()

