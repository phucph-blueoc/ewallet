"""
Firebase Cloud Messaging (FCM) service for sending push notifications.
"""
import logging
import os
from typing import Optional, Dict, Any, List
from firebase_admin import messaging, credentials, initialize_app, get_app, App

logger = logging.getLogger(__name__)

_firebase_app: Optional[App] = None


def initialize_firebase() -> Optional[App]:
    """
    Initialize Firebase Admin SDK.
    
    Looks for Firebase service account key in:
    1. Environment variable FIREBASE_CREDENTIALS (path to JSON file)
    2. Default path: backend/firebase-service-account-key.json
    
    Returns:
        Firebase App instance or None if initialization fails
    """
    global _firebase_app
    
    if _firebase_app is not None:
        return _firebase_app
    
    try:
        # Try to get existing app
        _firebase_app = get_app()
        logger.info("Firebase app already initialized")
        return _firebase_app
    except ValueError:
        # App doesn't exist, need to initialize
        pass
    
    # Find service account key file
    cred_path = os.getenv("FIREBASE_CREDENTIALS")
    if not cred_path:
        # Default path
        current_dir = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
        cred_path = os.path.join(current_dir, "firebase-service-account-key.json")
    
    if not os.path.exists(cred_path):
        logger.warning(
            f"Firebase service account key not found at {cred_path}. "
            "Push notifications will be disabled. "
            "Set FIREBASE_CREDENTIALS environment variable or place key file at default path."
        )
        return None
    
    try:
        cred = credentials.Certificate(cred_path)
        _firebase_app = initialize_app(cred)
        logger.info(f"Firebase initialized successfully from {cred_path}")
        return _firebase_app
    except Exception as e:
        logger.error(f"Failed to initialize Firebase: {e}")
        return None


def send_push_notification(
    device_token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None
) -> bool:
    """
    Send push notification to a device via FCM.
    
    Args:
        device_token: FCM device token
        title: Notification title
        body: Notification body/message
        data: Optional data payload (dict of string key-value pairs)
    
    Returns:
        True if sent successfully, False otherwise
    """
    if not device_token:
        logger.warning("Device token is empty, cannot send notification")
        return False
    
    # Initialize Firebase if not already done
    app = initialize_firebase()
    if app is None:
        logger.warning("Firebase not initialized, cannot send push notification")
        return False
    
    try:
        # Build the message
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={k: str(v) for k, v in (data or {}).items()},  # FCM data must be strings
            token=device_token,
        )
        
        # Send the message
        response = messaging.send(message)
        logger.info(f"Successfully sent push notification: {response}")
        return True
        
    except messaging.UnregisteredError:
        logger.warning(f"Device token {device_token[:20]}... is not registered (app uninstalled)")
        return False
    except Exception as e:
        logger.error(f"Failed to send push notification: {e}")
        return False


def send_multicast_notification(
    device_tokens: List[str],
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None
) -> Dict[str, Any]:
    """
    Send push notification to multiple devices.
    
    Args:
        device_tokens: List of FCM device tokens
        title: Notification title
        body: Notification body/message
        data: Optional data payload
    
    Returns:
        Dict with 'success_count' and 'failure_count'
    """
    if not device_tokens:
        return {"success_count": 0, "failure_count": 0}
    
    app = initialize_firebase()
    if app is None:
        logger.warning("Firebase not initialized, cannot send push notification")
        return {"success_count": 0, "failure_count": len(device_tokens)}
    
    try:
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={k: str(v) for k, v in (data or {}).items()},
            tokens=device_tokens,
        )
        
        response = messaging.send_multicast(message)
        logger.info(
            f"Sent multicast notification: {response.success_count} success, "
            f"{response.failure_count} failures"
        )
        
        return {
            "success_count": response.success_count,
            "failure_count": response.failure_count,
        }
    except Exception as e:
        logger.error(f"Failed to send multicast notification: {e}")
        return {"success_count": 0, "failure_count": len(device_tokens)}

