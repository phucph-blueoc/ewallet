"""
Test script to verify FCM setup and send a test notification.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))

from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models import NotificationSettings, User
from app.services.fcm_service import send_push_notification, initialize_firebase

def test_fcm_setup():
    """Test FCM initialization and send a test notification."""
    print("=" * 60)
    print("Testing FCM Setup")
    print("=" * 60)
    
    # Initialize Firebase
    print("\n1. Initializing Firebase...")
    app = initialize_firebase()
    if app is None:
        print("❌ Firebase initialization failed!")
        print("   Make sure firebase-service-account-key.json exists in backend/")
        return False
    print("✅ Firebase initialized successfully")
    
    # Get database session
    db: Session = SessionLocal()
    
    try:
        # Find a user with device token
        print("\n2. Checking for users with device tokens...")
        settings = db.query(NotificationSettings).filter(
            NotificationSettings.device_token.isnot(None),
            NotificationSettings.device_token != ""
        ).first()
        
        if not settings:
            print("❌ No users with device tokens found!")
            print("   Please register a device token via Flutter app first:")
            print("   - Login to the app")
            print("   - The app should automatically register the device token")
            return False
        
        user = db.query(User).filter(User.id == settings.user_id).first()
        print(f"✅ Found user: {user.email if user else 'Unknown'}")
        print(f"   Device token: {settings.device_token[:30]}...")
        print(f"   Device type: {settings.device_type}")
        
        # Send test notification
        print("\n3. Sending test notification...")
        success = send_push_notification(
            device_token=settings.device_token,
            title="Test Notification",
            body="Đây là thông báo test từ backend. Nếu bạn nhận được, FCM đã hoạt động!",
            data={"type": "TEST", "test": "true"}
        )
        
        if success:
            print("✅ Test notification sent successfully!")
            print("   Check your device for the notification")
            return True
        else:
            print("❌ Failed to send test notification")
            print("   Check backend logs for error details")
            return False
            
    finally:
        db.close()

if __name__ == "__main__":
    test_fcm_setup()


