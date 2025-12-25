#!/usr/bin/env python3
"""
Setup script for E-Wallet backend.
Generates secure encryption keys and creates .env file.
"""

from cryptography.fernet import Fernet
import secrets
import os

def generate_secret_key(length=32):
    """Generate a secure random secret key."""
    return secrets.token_hex(length)

def generate_encryption_key():
    """Generate a Fernet encryption key."""
    return Fernet.generate_key().decode()

def create_env_file():
    """Create .env file with generated keys."""
    
    if os.path.exists('.env'):
        response = input('.env file already exists. Overwrite? (y/N): ')
        if response.lower() != 'y':
            print('Aborted. Keeping existing .env file.')
            return
    
    secret_key = generate_secret_key()
    encryption_key = generate_encryption_key()
    
    env_content = f"""# E-Wallet Backend Environment Variables
# Generated on: {os.popen('date').read().strip()}

# Application Settings
PROJECT_NAME=E-Wallet API
API_V1_STR=/api/v1

# Database
DATABASE_URL=sqlite:///./sql_app.db
# For PostgreSQL: postgresql://user:password@localhost/dbname

# Security - JWT
SECRET_KEY={secret_key}
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# Security - Encryption
ENCRYPTION_KEY={encryption_key}

# Email Service (SMTP) - Configure these for production
# SMTP_HOST=smtp.gmail.com
# SMTP_PORT=587
# SMTP_USER=your-email@gmail.com
# SMTP_PASSWORD=your-app-password
# SMTP_FROM=your-email@gmail.com
# SMTP_FROM_NAME=E-Wallet Support

# OTP Settings
OTP_INTERVAL=300
OTP_EXPIRY_MINUTES=15  # Increased from 5 to handle slow email delivery

# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_PER_MINUTE=60
"""
    
    with open('.env', 'w') as f:
        f.write(env_content)
    
    print('✅ .env file created successfully!')
    print(f'✅ Generated SECRET_KEY: {secret_key[:20]}...')
    print(f'✅ Generated ENCRYPTION_KEY: {encryption_key[:20]}...')
    print('\n⚠️  IMPORTANT: Keep these keys secure and never commit .env to version control!')
    print('\n📧 To enable email functionality, edit .env and configure SMTP settings.')

def main():
    print('🚀 E-Wallet Backend Setup')
    print('=' * 50)
    create_env_file()
    print('\n📝 Next steps:')
    print('1. Install dependencies: pip install -r requirements.txt')
    print('2. Run migrations: alembic upgrade head')
    print('3. Start server: uvicorn app.main:app --reload')
    print('4. Visit http://localhost:8000/docs for API documentation')

if __name__ == '__main__':
    main()
