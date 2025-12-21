"""
Script to check notification setup status.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))

from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models import NotificationSettings, User, Notification

def check_notification_setup():
    """Check notification setup status."""
    print("=" * 60)
    print("Notification Setup Check")
    print("=" * 60)
    
    db: Session = SessionLocal()
    
    try:
        # Check all users
        print("\n1. Checking users...")
        users = db.query(User).all()
        print(f"   Total users: {len(users)}")
        
        for user in users:
            print(f"   - {user.email} (ID: {user.id[:8]}...)")
        
        # Check notification settings
        print("\n2. Checking notification settings...")
        all_settings = db.query(NotificationSettings).all()
        print(f"   Total notification settings: {len(all_settings)}")
        
        for settings in all_settings:
            user = db.query(User).filter(User.id == settings.user_id).first()
            has_token = settings.device_token is not None and settings.device_token != ""
            print(f"   - User: {user.email if user else 'Unknown'}")
            print(f"     Device token: {'✅ Yes' if has_token else '❌ No'}")
            if has_token:
                print(f"     Token: {settings.device_token[:30]}...")
                print(f"     Device type: {settings.device_type}")
            print(f"     Transaction notifications: {settings.enable_transaction_notifications}")
        
        # Check notifications
        print("\n3. Checking notifications...")
        all_notifications = db.query(Notification).all()
        print(f"   Total notifications: {len(all_notifications)}")
        
        if all_notifications:
            print("\n   Recent notifications:")
            for notif in all_notifications[-5:]:  # Last 5
                user = db.query(User).filter(User.id == notif.user_id).first()
                print(f"   - {notif.title}")
                print(f"     User: {user.email if user else 'Unknown'}")
                print(f"     Type: {notif.type}")
                print(f"     Created: {notif.created_at}")
                print(f"     Read: {notif.is_read}")
        
        # Summary
        print("\n" + "=" * 60)
        print("Summary")
        print("=" * 60)
        settings_with_tokens = db.query(NotificationSettings).filter(
            NotificationSettings.device_token.isnot(None),
            NotificationSettings.device_token != ""
        ).count()
        print(f"Users with device tokens: {settings_with_tokens}/{len(users)}")
        
        if settings_with_tokens == 0:
            print("\n⚠️  No device tokens found!")
            print("   To fix this:")
            print("   1. Open Flutter app")
            print("   2. Logout (if logged in)")
            print("   3. Login again")
            print("   4. The app should automatically register the device token")
        else:
            print("\n✅ Device tokens are registered!")
            print("   Push notifications should work when you make transactions.")
            
    finally:
        db.close()

if __name__ == "__main__":
    check_notification_setup()


