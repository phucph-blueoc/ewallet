import pyotp
from datetime import datetime, timedelta

class OTPService:
    def generate_secret(self) -> str:
        return pyotp.random_base32()

    def get_totp(self, secret: str):
        return pyotp.TOTP(secret, interval=300) # 5 minutes validity

    def verify_otp(self, secret: str, otp: str) -> bool:
        totp = self.get_totp(secret)
        return totp.verify(otp)

    def generate_otp(self, secret: str) -> str:
        totp = self.get_totp(secret)
        return totp.now()

otp_service = OTPService()
