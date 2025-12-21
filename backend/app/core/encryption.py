from cryptography.fernet import Fernet
import base64
from app.core.config import settings

class EncryptionService:
    def __init__(self, key: str = None):
        """
        Initialize encryption service with a Fernet key.
        
        Args:
            key: Base64-encoded Fernet key. If None, loads from settings.
        """
        if key is None:
            key = settings.ENCRYPTION_KEY
            
        # Validate and convert key
        try:
            if isinstance(key, str):
                key = key.encode()
            # Test if it's a valid Fernet key
            self.fernet = Fernet(key)
        except Exception as e:
            raise ValueError(
                f"Invalid ENCRYPTION_KEY. Generate a valid key with: "
                f"python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'"
            ) from e

    def encrypt(self, data: str) -> str:
        """Encrypt a string and return base64-encoded result."""
        if not data:
            return None
        return self.fernet.encrypt(data.encode()).decode()

    def decrypt(self, token: str) -> str:
        """Decrypt a base64-encoded encrypted string."""
        if not token:
            return None
        try:
            return self.fernet.decrypt(token.encode()).decode()
        except Exception as e:
            # Log the error in production
            raise ValueError("Failed to decrypt data. The encryption key may have changed.") from e

# Global instance
encryption_service = EncryptionService()
