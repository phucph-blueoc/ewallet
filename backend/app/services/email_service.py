from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import smtplib
from typing import Optional, Callable
import requests
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from app.core.config import settings


class MicrosoftGraphEmailService:
    """Email service using Microsoft Graph API."""
    
    def __init__(self):
        self.client_id = settings.MICROSOFT_CLIENT_ID
        self.client_secret = settings.MICROSOFT_CLIENT_SECRET
        self.tenant_id = settings.MICROSOFT_TENANT_ID
        self.mail_from = settings.MICROSOFT_MAIL_FROM
        self._token_cache = None
        
    def is_configured(self) -> bool:
        """Check if Microsoft Graph is configured."""
        return all([
            self.client_id,
            self.client_secret,
            self.tenant_id,
            self.mail_from
        ])
    
    def _get_access_token(self) -> Optional[str]:
        """Get access token using client credentials flow via direct HTTP request."""
        if not self.is_configured():
            print(f"[Microsoft Graph] Not configured, skipping token acquisition")
            return None
        
        # Use direct HTTP request instead of MSAL to avoid hanging issues
        token_url = f"https://login.microsoftonline.com/{self.tenant_id}/oauth2/v2.0/token"
        
        data = {
            'client_id': self.client_id,
            'scope': 'https://graph.microsoft.com/.default',
            'client_secret': self.client_secret,
            'grant_type': 'client_credentials'
        }
        
        headers = {
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        
        print(f"[Microsoft Graph] Acquiring access token via direct HTTP request...")
        try:
            # Reduced timeout to 5 seconds for faster fallback to SMTP
            response = requests.post(token_url, data=data, headers=headers, timeout=5)
            
            if response.status_code == 200:
                result = response.json()
                access_token = result.get('access_token')
                if access_token:
                    print(f"[Microsoft Graph] ✓ Access token obtained successfully")
                    return access_token
                else:
                    print(f"[Microsoft Graph] ✗ No access token in response")
                    return None
            else:
                error_data = response.json() if response.text else {}
                error = error_data.get('error', 'Unknown')
                error_desc = error_data.get('error_description', response.text or 'No description')
                print(f"[Microsoft Graph] ✗ Failed to get access token")
                print(f"[Microsoft Graph] Status: {response.status_code}")
                print(f"[Microsoft Graph] Error: {error} - {error_desc}")
                return None
                
        except requests.exceptions.Timeout:
            print(f"[Microsoft Graph] ✗ Token request timed out")
            return None
        except Exception as e:
            print(f"[Microsoft Graph] ✗ Exception during token acquisition: {e}")
            import traceback
            traceback.print_exc()
            return None
    
    def send_email(self, to_email: str, subject: str, html_content: str) -> bool:
        """Send email via Microsoft Graph API."""
        print(f"[Microsoft Graph] Getting access token...")
        access_token = self._get_access_token()
        if not access_token:
            print(f"[Microsoft Graph] ✗ Failed to get access token")
            return False
        print(f"[Microsoft Graph] ✓ Access token obtained")
        
        endpoint = f"https://graph.microsoft.com/v1.0/users/{self.mail_from}/sendMail"
        print(f"[Microsoft Graph] Sending email to {to_email} via {endpoint}...")
        
        email_msg = {
            "message": {
                "subject": subject,
                "body": {
                    "contentType": "HTML",
                    "content": html_content
                },
                "toRecipients": [
                    {
                        "emailAddress": {
                            "address": to_email
                        }
                    }
                ],
                "from": {
                    "emailAddress": {
                        "address": self.mail_from
                    }
                }
            },
            "saveToSentItems": "true"
        }
        
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        print(f"[Microsoft Graph] Request headers prepared (token: {access_token[:20]}...)")
        
        try:
            # Reduced timeout to 5 seconds for faster fallback to SMTP
            print(f"[Microsoft Graph] Making POST request...")
            response = requests.post(endpoint, json=email_msg, headers=headers, timeout=5)
            print(f"[Microsoft Graph] Response status: {response.status_code}")
            
            if response.status_code == 202:
                print(f"[Microsoft Graph] ✓ Email sent successfully (202 Accepted)")
                return True
            else:
                print(f"[Microsoft Graph] ✗ API error: {response.status_code}")
                print(f"[Microsoft Graph] Response body: {response.text}")
                try:
                    error_json = response.json()
                    print(f"[Microsoft Graph] Error details: {error_json}")
                except:
                    pass
                return False
        except requests.exceptions.Timeout:
            print(f"[Microsoft Graph] ✗ Timeout - request took longer than 5 seconds, will fallback to SMTP")
            return False
        except requests.exceptions.RequestException as e:
            print(f"[Microsoft Graph] ✗ Request error: {str(e)}")
            import traceback
            traceback.print_exc()
            return False
        except Exception as e:
            print(f"[Microsoft Graph] ✗ Unexpected error: {str(e)}")
            import traceback
            traceback.print_exc()
            return False


class SMTPEmailService:
    """Email service using SMTP."""
    
    def __init__(self):
        self.smtp_host = settings.SMTP_HOST
        self.smtp_port = settings.SMTP_PORT
        self.smtp_user = settings.SMTP_USER
        self.smtp_password = settings.SMTP_PASSWORD
        self.smtp_from = settings.SMTP_FROM or settings.SMTP_USER
        self.smtp_from_name = settings.SMTP_FROM_NAME
    
    def is_configured(self) -> bool:
        """Check if SMTP is configured."""
        return bool(self.smtp_user and self.smtp_password)
        
    def _create_connection(self):
        """Create and return an SMTP connection with timeout."""
        print(f"[SMTP] Connecting to {self.smtp_host}:{self.smtp_port}...")
        server = smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=10)
        print(f"[SMTP] Starting TLS...")
        server.starttls()
        print(f"[SMTP] Logging in as {self.smtp_user}...")
        server.login(self.smtp_user, self.smtp_password)
        print(f"[SMTP] ✓ Connection established successfully")
        return server
    
    def send_email(self, to_email: str, subject: str, html_content: str) -> bool:
        """Send an email via SMTP."""
        try:
            print(f"[SMTP] Preparing email message...")
            message = MIMEMultipart("alternative")
            message["Subject"] = subject
            message["From"] = f"{self.smtp_from_name} <{self.smtp_from}>"
            message["To"] = to_email
            
            html_part = MIMEText(html_content, "html")
            message.attach(html_part)
            
            server = self._create_connection()
            print(f"[SMTP] Sending email to {to_email}...")
            server.send_message(message)
            server.quit()
            print(f"[SMTP] ✓ Email sent successfully to {to_email}")
            
            return True
        except smtplib.SMTPException as e:
            print(f"[SMTP] ✗ SMTP error sending email to {to_email}: {str(e)}")
            return False
        except Exception as e:
            print(f"[SMTP] ✗ Failed to send email via SMTP to {to_email}: {str(e)}")
            import traceback
            traceback.print_exc()
            return False


class EmailService:
    """Unified email service that uses Microsoft Graph or SMTP."""
    
    def __init__(self):
        self.microsoft_service = MicrosoftGraphEmailService()
        self.smtp_service = SMTPEmailService()
        
    def send_email(self, to_email: str, subject: str, html_content: str) -> bool:
        """
        Send an email using the configured service.
        Tries Microsoft Graph first, then SMTP.
        """
        start_time = time.time()
        
        # Try Microsoft Graph first
        if self.microsoft_service.is_configured():
            print(f"[EmailService] Attempting to send email via Microsoft Graph to {to_email}...")
            result = self.microsoft_service.send_email(to_email, subject, html_content)
            elapsed = time.time() - start_time
            if result:
                print(f"[EmailService] ✓ Email sent successfully via Microsoft Graph (took {elapsed:.2f}s)")
                return True
            print(f"[EmailService] ✗ Microsoft Graph failed after {elapsed:.2f}s, falling back to SMTP...")
        
        # Try SMTP
        if self.smtp_service.is_configured():
            smtp_start = time.time()
            print(f"[EmailService] Attempting to send email via SMTP to {to_email}...")
            result = self.smtp_service.send_email(to_email, subject, html_content)
            smtp_elapsed = time.time() - smtp_start
            if result:
                total_elapsed = time.time() - start_time
                print(f"[EmailService] ✓ Email sent successfully via SMTP (SMTP took {smtp_elapsed:.2f}s, total {total_elapsed:.2f}s)")
                return True
            print(f"[EmailService] ✗ SMTP failed after {smtp_elapsed:.2f}s")
        
        total_elapsed = time.time() - start_time
        print(f"[EmailService] ✗ No email service configured or all services failed (total time: {total_elapsed:.2f}s)")
        return False
    
    def send_otp_email(self, to_email: str, otp_code: str, user_name: str = None, subject: str = None) -> bool:
        """
        Send OTP verification email.
        
        Args:
            to_email: Recipient email address
            otp_code: The OTP code to send
            user_name: Optional user name for personalization
            
        Returns:
            True if email sent successfully, False otherwise
        """
        if not subject:
            subject = "E-Wallet - Email Verification Code"
        
        greeting = f"Hello {user_name}," if user_name else "Hello,"
        
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{
                    font-family: Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                }}
                .container {{
                    max-width: 600px;
                    margin: 0 auto;
                    padding: 20px;
                }}
                .header {{
                    background-color: #4CAF50;
                    color: white;
                    padding: 20px;
                    text-align: center;
                    border-radius: 5px 5px 0 0;
                }}
                .content {{
                    background-color: #f9f9f9;
                    padding: 30px;
                    border-radius: 0 0 5px 5px;
                }}
                .otp-code {{
                    background-color: #fff;
                    border: 2px dashed #4CAF50;
                    padding: 20px;
                    text-align: center;
                    font-size: 32px;
                    font-weight: bold;
                    letter-spacing: 5px;
                    margin: 20px 0;
                    color: #4CAF50;
                }}
                .warning {{
                    background-color: #fff3cd;
                    border-left: 4px solid #ffc107;
                    padding: 10px;
                    margin: 20px 0;
                }}
                .footer {{
                    text-align: center;
                    margin-top: 20px;
                    font-size: 12px;
                    color: #666;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>E-Wallet Verification</h1>
                </div>
                <div class="content">
                    <p>{greeting}</p>
                    <p>Thank you for registering with E-Wallet! To complete your registration, please use the following verification code:</p>
                    
                    <div class="otp-code">
                        {otp_code}
                    </div>
                    
                    <div class="warning">
                        <strong>⚠️ Important:</strong> This code will expire in {settings.OTP_EXPIRY_MINUTES} minutes. Do not share this code with anyone.
                    </div>
                    
                    <p>If you didn't request this code, please ignore this email or contact our support team.</p>
                    
                    <p>Best regards,<br>The E-Wallet Team</p>
                </div>
                <div class="footer">
                    <p>This is an automated message, please do not reply to this email.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        return self.send_email(to_email, subject, html_content)


# Global instance
email_service = EmailService()

# Thread pool for background email sending (shared across the application)
_email_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="email")


def send_email_async(
    to_email: str,
    subject: str,
    html_content: str,
    callback: Optional[Callable[[bool], None]] = None
) -> None:
    """
    Send email asynchronously in background thread.
    
    Args:
        to_email: Recipient email address
        subject: Email subject
        html_content: HTML content of the email
        callback: Optional callback function that receives success status (bool)
    
    Returns:
        None (fire-and-forget, returns immediately)
    """
    def _send_sync():
        try:
            print(f"[Background Email] Starting email send to {to_email}...")
            success = email_service.send_email(to_email, subject, html_content)
            if success:
                print(f"[Background Email] ✓ Email sent successfully to {to_email}")
            else:
                print(f"[Background Email] ✗ Failed to send email to {to_email}")
            if callback:
                callback(success)
        except Exception as e:
            print(f"[Background Email] ✗ Error sending email to {to_email}: {e}")
            import traceback
            traceback.print_exc()
            if callback:
                callback(False)
    
    _email_executor.submit(_send_sync)


def send_otp_email_async(
    to_email: str,
    otp_code: str,
    user_name: Optional[str] = None,
    subject: Optional[str] = None,
    callback: Optional[Callable[[bool], None]] = None
) -> None:
    """
    Send OTP email asynchronously in background thread.
    
    Args:
        to_email: Recipient email address
        otp_code: The OTP code to send
        user_name: Optional user name for personalization
        subject: Optional email subject
        callback: Optional callback function that receives success status (bool)
    
    Returns:
        None (fire-and-forget, returns immediately)
    """
    def _send_sync():
        try:
            print(f"[Background Email] Starting OTP email send to {to_email}...")
            success = email_service.send_otp_email(
                to_email=to_email,
                otp_code=otp_code,
                user_name=user_name,
                subject=subject
            )
            if success:
                print(f"[Background Email] ✓ OTP email sent successfully to {to_email}")
            else:
                print(f"[Background Email] ✗ Failed to send OTP email to {to_email}")
            if callback:
                callback(success)
        except Exception as e:
            print(f"[Background Email] ✗ Error sending OTP email to {to_email}: {e}")
            import traceback
            traceback.print_exc()
            if callback:
                callback(False)
    
    _email_executor.submit(_send_sync)
