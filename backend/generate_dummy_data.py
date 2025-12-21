"""
Script to generate dummy data for E-Wallet application.

This script creates:
- Multiple users with wallets
- Various transactions (deposit, withdraw, transfer) with different timestamps
- Encrypted transaction notes
- Realistic Vietnamese names and email addresses

Usage:
    python generate_dummy_data.py
"""

import sys
import random
from datetime import datetime, timedelta
from typing import List

# Add parent directory to path to import app modules
sys.path.insert(0, '.')

from app.core.database import SessionLocal, engine
from app.models import User, Wallet, Transaction
from app.core.security import get_password_hash
from app.core.encryption import encryption_service

# Vietnamese names for realistic dummy data
VIETNAMESE_FIRST_NAMES = [
    "An", "Bình", "Cường", "Dũng", "Hùng", "Khang", "Long", "Minh", "Nam", "Phong",
    "Quang", "Sơn", "Thành", "Tuấn", "Việt", "Anh", "Bảo", "Đức", "Giang", "Hoàng"
]

VIETNAMESE_LAST_NAMES = [
    "Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Huỳnh", "Phan", "Vũ", "Võ", "Đặng",
    "Bùi", "Đỗ", "Hồ", "Ngô", "Dương", "Lý", "Đào", "Đinh", "Tôn", "Lưu"
]

# Transaction notes in Vietnamese
DEPOSIT_NOTES = [
    "Nạp tiền vào ví",
    "Nạp tiền từ ngân hàng",
    "Nạp tiền từ thẻ ATM",
    "Nạp tiền từ Momo",
    "Nạp tiền từ ZaloPay",
    "Chuyển tiền từ tài khoản ngân hàng"
]

WITHDRAW_NOTES = [
    "Rút tiền về ngân hàng",
    "Rút tiền về thẻ ATM",
    "Rút tiền về ví điện tử khác",
    "Rút tiền tiêu dùng"
]

TRANSFER_NOTES = [
    "Chuyển tiền mua hàng",
    "Chuyển tiền thanh toán hóa đơn",
    "Chuyển tiền cho bạn bè",
    "Chuyển tiền trả nợ",
    "Chuyển tiền mừng sinh nhật",
    "Chuyển tiền tiền ăn trưa",
    "Chuyển tiền chia tiền taxi",
    "Chuyển tiền mua quà",
    "Chuyển tiền ủng hộ",
    "Chuyển tiền học phí"
]


def create_dummy_users(db, num_users: int = 15) -> List[User]:
    """Create dummy users with hashed passwords."""
    print(f"Creating {num_users} dummy users...")
    users = []
    
    for i in range(num_users):
        # Generate Vietnamese name
        first_name = random.choice(VIETNAMESE_FIRST_NAMES)
        last_name = random.choice(VIETNAMESE_LAST_NAMES)
        full_name = f"{last_name} {first_name}"
        email = f"user{i+1}_{first_name.lower()}_{last_name.lower()}@example.com"
        
        # Create user with verified status (skip OTP verification for dummy data)
        hashed_password = get_password_hash("password123")  # Same password for all dummy users
        
        user = User(
            email=email,
            hashed_password=hashed_password,
            full_name=full_name,
            is_active=True,
            is_verified=True,  # Mark as verified to allow login
            otp_secret=None,
            otp_created_at=None
        )
        
        db.add(user)
        db.flush()  # Flush to get user.id
        
        # Create wallet for user with random initial balance
        initial_balance = random.uniform(0, 5000000)  # 0 to 5,000,000 VND
        wallet = Wallet(
            user_id=user.id,
            balance=initial_balance,
            currency="VND"
        )
        db.add(wallet)
        
        users.append(user)
        print(f"  ✓ Created user: {full_name} ({email}) - Balance: {initial_balance:,.0f}₫")
    
    db.commit()
    return users


def create_dummy_transactions(
    db, 
    users: List[User], 
    num_days: int = 30,
    transactions_per_day: int = 20
):
    """Create dummy transactions over the past N days."""
    print(f"\nCreating transactions for the past {num_days} days...")
    
    # Get all wallets
    wallets = {user.id: db.query(Wallet).filter(Wallet.user_id == user.id).first() for user in users}
    
    total_transactions = 0
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=num_days)
    
    # Create transactions for each day
    current_date = start_date
    while current_date <= end_date:
        # Random number of transactions per day
        num_tx_today = random.randint(5, transactions_per_day)
        
        for _ in range(num_tx_today):
            # Random time during the day
            random_hours = random.randint(0, 23)
            random_minutes = random.randint(0, 59)
            random_seconds = random.randint(0, 59)
            timestamp = current_date.replace(
                hour=random_hours,
                minute=random_minutes,
                second=random_seconds
            )
            
            # Random transaction type: 40% deposit, 30% withdraw, 30% transfer
            tx_type = random.choices(
                ['deposit', 'withdraw', 'transfer'],
                weights=[40, 30, 30]
            )[0]
            
            user = random.choice(users)
            wallet = wallets[user.id]
            
            if tx_type == 'deposit':
                amount = random.uniform(50000, 2000000)  # 50,000 to 2,000,000 VND
                note = random.choice(DEPOSIT_NOTES)
                encrypted_note = encryption_service.encrypt(note)
                
                transaction = Transaction(
                    sender_id=None,
                    receiver_id=user.id,
                    amount=amount,
                    timestamp=timestamp,
                    encrypted_note=encrypted_note
                )
                
                # Update wallet balance
                wallet.balance += amount
                
            elif tx_type == 'withdraw':
                # Only withdraw if balance is sufficient
                max_withdraw = min(wallet.balance, 1000000)  # Max 1,000,000 VND
                if max_withdraw > 0:
                    amount = random.uniform(50000, max_withdraw)
                    note = random.choice(WITHDRAW_NOTES)
                    encrypted_note = encryption_service.encrypt(note)
                    
                    transaction = Transaction(
                        sender_id=user.id,
                        receiver_id=None,
                        amount=amount,
                        timestamp=timestamp,
                        encrypted_note=encrypted_note
                    )
                    
                    # Update wallet balance
                    wallet.balance -= amount
                else:
                    continue  # Skip if no balance
                    
            else:  # transfer
                # Find another user to transfer to
                other_users = [u for u in users if u.id != user.id]
                if not other_users:
                    continue
                    
                receiver = random.choice(other_users)
                receiver_wallet = wallets[receiver.id]
                
                # Only transfer if balance is sufficient
                max_transfer = min(wallet.balance, 500000)  # Max 500,000 VND per transfer
                if max_transfer > 50000:  # At least 50,000 VND
                    amount = random.uniform(50000, max_transfer)
                    note = random.choice(TRANSFER_NOTES)
                    encrypted_note = encryption_service.encrypt(note)
                    
                    transaction = Transaction(
                        sender_id=user.id,
                        receiver_id=receiver.id,
                        amount=amount,
                        timestamp=timestamp,
                        encrypted_note=encrypted_note
                    )
                    
                    # Update both wallets
                    wallet.balance -= amount
                    receiver_wallet.balance += amount
                else:
                    continue  # Skip if insufficient balance
            
            db.add(transaction)
            total_transactions += 1
        
        # Move to next day
        current_date += timedelta(days=1)
    
    db.commit()
    print(f"  ✓ Created {total_transactions} transactions")
    
    # Print summary
    print("\n📊 Wallet Balance Summary:")
    for user in users:
        wallet = wallets[user.id]
        print(f"  {user.full_name}: {wallet.balance:,.0f}₫")


def main():
    """Main function to generate dummy data."""
    print("=" * 60)
    print("🚀 E-Wallet Dummy Data Generator")
    print("=" * 60)
    
    # Ask for confirmation
    response = input("\n⚠️  This will create/update dummy data in the database. Continue? (y/N): ")
    if response.lower() != 'y':
        print("❌ Cancelled.")
        return
    
    # Ask for number of users
    try:
        num_users = int(input("How many users to create? (default: 15): ") or "15")
    except ValueError:
        num_users = 15
    
    # Ask for number of days
    try:
        num_days = int(input("How many days of transaction history? (default: 30): ") or "30")
    except ValueError:
        num_days = 30
    
    # Create database session
    db = SessionLocal()
    
    try:
        # Check if users already exist
        existing_users = db.query(User).count()
        if existing_users > 0:
            response = input(f"\n⚠️  Found {existing_users} existing users. Delete all existing data? (y/N): ")
            if response.lower() == 'y':
                print("🗑️  Deleting existing data...")
                db.query(Transaction).delete()
                db.query(Wallet).delete()
                db.query(User).delete()
                db.commit()
                print("  ✓ Deleted existing data")
            else:
                print("ℹ️  Keeping existing data and adding new users...")
        
        # Create users
        users = create_dummy_users(db, num_users)
        
        # Create transactions
        create_dummy_transactions(db, users, num_days)
        
        print("\n" + "=" * 60)
        print("✅ Dummy data generation completed!")
        print("=" * 60)
        print(f"\n📝 Summary:")
        print(f"  - Users created: {len(users)}")
        print(f"  - All users have password: 'password123'")
        print(f"  - All users are verified and can login")
        print(f"  - Transaction history: {num_days} days")
        print(f"\n💡 You can now login with any user:")
        for user in users[:5]:  # Show first 5 users
            print(f"    Email: {user.email}, Password: password123")
        if len(users) > 5:
            print(f"    ... and {len(users) - 5} more users")
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

