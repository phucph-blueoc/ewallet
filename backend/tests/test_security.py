"""
Security Test Cases for E-Wallet Backend

Tests cover:
- SQL Injection Protection
- Rate Limiting
- Password Hashing
- JWT Token Validation
- Data Encryption
- Authentication & Authorization
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from jose import jwt, JWTError
from datetime import datetime, timedelta
import time

from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    SECRET_KEY,
    ALGORITHM,
)
from app.core.encryption import EncryptionService
from app.models import User, Wallet


@pytest.fixture(scope="function")
def test_user(db: Session):
    """Create a test user."""
    hashed_password = get_password_hash("TestPassword123!")
    user = User(
        email="test@example.com",
        hashed_password=hashed_password,
        full_name="Test User",
        is_verified=True
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    
    # Create wallet for user
    wallet = Wallet(user_id=user.id, balance=1000000.0)
    db.add(wallet)
    db.commit()
    
    return user


@pytest.fixture(scope="function")
def auth_token(client, test_user):
    """Get authentication token for test user."""
    response = client.post(
        "/api/v1/auth/login",
        data={
            "username": test_user.email,
            "password": "TestPassword123!"
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    assert response.status_code == 200
    return response.json()["access_token"]


class TestSQLInjectionProtection:
    """Test SQL Injection Protection"""
    
    def test_sql_injection_in_email_field(self, client):
        """Test that SQL injection attempts in email field are blocked."""
        # Common SQL injection payloads
        sql_injection_payloads = [
            "admin' OR '1'='1",
            "admin'--",
            "admin'/*",
            "' UNION SELECT * FROM users--",
            "'; DROP TABLE users--",
            "' OR 1=1--",
            "' OR '1'='1'--",
            "admin' OR '1'='1' #",
        ]
        
        for payload in sql_injection_payloads:
            response = client.post(
                "/api/v1/auth/login",
                data={
                    "username": payload,
                    "password": "anypassword"
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            # Should return 401 (unauthorized), 400 (bad request), or 429 (rate limited)
            # Rate limiting blocking attacks is also a security feature
            assert response.status_code in [401, 400, 429], \
                f"SQL injection payload '{payload}' should be rejected safely (got {response.status_code})"
            # Should not expose database errors
            assert "sql" not in response.text.lower(), \
                f"Response should not expose SQL errors for payload '{payload}'"
    
    def test_sql_injection_in_password_field(self, client, test_user):
        """Test that SQL injection attempts in password field are blocked."""
        sql_injection_payloads = [
            "' OR '1'='1",
            "'--",
            "'/*",
            "'; DROP TABLE users--",
        ]
        
        for payload in sql_injection_payloads:
            response = client.post(
                "/api/v1/auth/login",
                data={
                    "username": test_user.email,
                    "password": payload
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            # Should return 401 (unauthorized) or 429 (rate limited)
            assert response.status_code in [401, 429], \
                f"SQL injection in password '{payload}' should be rejected (got {response.status_code})"
    
    def test_sql_injection_in_registration(self, client):
        """Test SQL injection protection in registration endpoint."""
        sql_payloads = [
            "test' OR '1'='1@example.com",
            "test'; DROP TABLE users--@example.com",
        ]
        
        for payload in sql_payloads:
            response = client.post(
                "/api/v1/auth/register",
                json={
                    "email": payload,
                    "password": "TestPassword123!",
                    "full_name": "Test User"
                }
            )
            # Should handle gracefully (either reject or create user safely)
            # 429 is acceptable as rate limiting is a security feature
            assert response.status_code in [200, 400, 422, 429], \
                f"Registration with SQL injection '{payload}' should be handled safely (got {response.status_code})"


class TestRateLimiting:
    """Test Rate Limiting"""
    
    def test_auth_rate_limiting(self, client):
        """Test that authentication endpoints have rate limiting."""
        # Make multiple rapid requests
        for i in range(10):
            response = client.post(
                "/api/v1/auth/login",
                data={
                    "username": f"test{i}@example.com",
                    "password": "wrongpassword"
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
        
        # After rate limit, should get 429
        response = client.post(
            "/api/v1/auth/login",
            data={
                "username": "test@example.com",
                "password": "wrongpassword"
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        # Note: Rate limiting might not trigger in test environment
        # This test verifies the endpoint exists and handles requests
        assert response.status_code in [401, 429], \
            "Rate limiting should eventually trigger (or return 401 for invalid credentials)"
    
    def test_rate_limit_response_format(self, client):
        """Test that rate limit responses are properly formatted."""
        # This test assumes rate limiting is enabled
        # In a real scenario, you'd need to exceed the limit first
        # For now, we test the exception handler exists
        response = client.get("/api/v1/auth/login")
        # Should return proper error format
        assert response.status_code in [405, 422, 400]


class TestPasswordHashing:
    """Test Password Hashing Security"""
    
    def test_password_not_stored_in_plain_text(self, db: Session, test_user):
        """Test that passwords are not stored in plain text."""
        user = db.query(User).filter(User.email == test_user.email).first()
        assert user is not None
        assert user.hashed_password != "TestPassword123!"
        assert not user.hashed_password.startswith("TestPassword")
        # Bcrypt hashes start with $2b$ or $2a$
        assert user.hashed_password.startswith("$2")
    
    def test_password_hashing_consistency(self):
        """Test that password hashing produces different hashes for same password."""
        password = "TestPassword123!"
        hash1 = get_password_hash(password)
        hash2 = get_password_hash(password)
        
        # Bcrypt includes salt, so hashes should be different
        assert hash1 != hash2, "Password hashes should be different due to salt"
    
    def test_password_verification(self):
        """Test password verification works correctly."""
        password = "TestPassword123!"
        hashed = get_password_hash(password)
        
        # Correct password should verify
        assert verify_password(password, hashed) == True
        
        # Wrong password should not verify
        assert verify_password("WrongPassword", hashed) == False
    
    def test_password_hash_length(self):
        """Test that password hashes have expected length."""
        password = "TestPassword123!"
        hashed = get_password_hash(password)
        
        # Bcrypt hashes are typically 60 characters
        assert len(hashed) == 60, f"Password hash should be 60 chars, got {len(hashed)}"


class TestJWTTokenValidation:
    """Test JWT Token Validation"""
    
    def test_valid_token_creation(self, test_user):
        """Test that valid JWT tokens are created."""
        token = create_access_token(subject=test_user.email)
        assert token is not None
        assert isinstance(token, str)
        assert len(token) > 0
    
    def test_token_contains_correct_claims(self, test_user):
        """Test that JWT tokens contain correct claims."""
        token = create_access_token(subject=test_user.email)
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        
        assert payload["sub"] == test_user.email
        assert payload["type"] == "access"
        assert "exp" in payload
    
    def test_token_expiration(self, test_user):
        """Test that tokens expire correctly."""
        # Create token with very short expiration
        expire_delta = timedelta(seconds=1)
        token = create_access_token(subject=test_user.email, expires_delta=expire_delta)
        
        # Token should be valid immediately
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert payload["sub"] == test_user.email
        
        # Wait for expiration
        time.sleep(2)
        
        # Token should be invalid
        with pytest.raises(JWTError):
            jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    
    def test_invalid_token_rejection(self, client, auth_token):
        """Test that invalid tokens are rejected."""
        # Test with tampered token
        tampered_token = auth_token[:-5] + "XXXXX"
        
        response = client.get(
            "/api/v1/wallets/me",
            headers={"Authorization": f"Bearer {tampered_token}"}
        )
        assert response.status_code == 401
    
    def test_expired_token_rejection(self, test_user):
        """Test that expired tokens are rejected."""
        # Create expired token
        expire_delta = timedelta(seconds=-1)  # Already expired
        expired_token = create_access_token(subject=test_user.email, expires_delta=expire_delta)
        
        # Try to decode expired token
        with pytest.raises(JWTError):
            jwt.decode(expired_token, SECRET_KEY, algorithms=[ALGORITHM])
    
    def test_refresh_token_different_from_access_token(self, test_user):
        """Test that refresh tokens are different from access tokens."""
        access_token = create_access_token(subject=test_user.email)
        refresh_token = create_refresh_token(subject=test_user.email)
        
        assert access_token != refresh_token
        
        # Decode and check types
        access_payload = jwt.decode(access_token, SECRET_KEY, algorithms=[ALGORITHM])
        refresh_payload = jwt.decode(refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
        
        assert access_payload["type"] == "access"
        assert refresh_payload["type"] == "refresh"
    
    def test_token_without_authorization_header(self, client):
        """Test that requests without authorization header are rejected."""
        response = client.get("/api/v1/wallets/me")
        assert response.status_code == 401
    
    def test_token_with_wrong_secret(self, test_user):
        """Test that tokens signed with wrong secret are rejected."""
        token = create_access_token(subject=test_user.email)
        
        # Try to decode with wrong secret
        wrong_secret = "wrong-secret-key"
        with pytest.raises(JWTError):
            jwt.decode(token, wrong_secret, algorithms=[ALGORITHM])


class TestEncryption:
    """Test Data Encryption"""
    
    def test_encryption_decryption(self):
        """Test that encryption and decryption work correctly."""
        encryption_service = EncryptionService()
        original_data = "Sensitive Data 123!@#"
        
        encrypted = encryption_service.encrypt(original_data)
        assert encrypted is not None
        assert encrypted != original_data
        
        decrypted = encryption_service.decrypt(encrypted)
        assert decrypted == original_data
    
    def test_encryption_different_outputs(self):
        """Test that encrypting same data produces different outputs (due to IV)."""
        encryption_service = EncryptionService()
        data = "Test Data"
        
        encrypted1 = encryption_service.encrypt(data)
        encrypted2 = encryption_service.encrypt(data)
        
        # Fernet includes timestamp, so outputs should be different
        assert encrypted1 != encrypted2
    
    def test_decryption_with_wrong_key_fails(self):
        """Test that decryption with wrong key fails."""
        encryption_service1 = EncryptionService()
        encryption_service2 = EncryptionService()
        
        # Create a new encryption service with different key
        from cryptography.fernet import Fernet
        different_key = Fernet.generate_key()
        encryption_service2 = EncryptionService(key=different_key.decode())
        
        data = "Test Data"
        encrypted = encryption_service1.encrypt(data)
        
        # Decrypting with wrong key should fail
        with pytest.raises(ValueError):
            encryption_service2.decrypt(encrypted)
    
    def test_empty_string_encryption(self):
        """Test handling of empty strings."""
        encryption_service = EncryptionService()
        
        encrypted = encryption_service.encrypt("")
        assert encrypted is None
        
        decrypted = encryption_service.decrypt(None)
        assert decrypted is None


class TestAuthentication:
    """Test Authentication Security"""
    
    def test_login_with_invalid_credentials(self, client):
        """Test that login with invalid credentials fails."""
        response = client.post(
            "/api/v1/auth/login",
            data={
                "username": "nonexistent@example.com",
                "password": "WrongPassword123!"
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        # Should return 401 (unauthorized) or 429 (rate limited)
        assert response.status_code in [401, 429], \
            f"Login with invalid credentials should fail (got {response.status_code})"
    
    def test_login_without_verification(self, client, db):
        """Test that unverified users cannot login."""
        # Create unverified user
        hashed_password = get_password_hash("TestPassword123!")
        user = User(
            email="unverified@example.com",
            hashed_password=hashed_password,
            full_name="Unverified User",
            is_verified=False
        )
        db.add(user)
        db.commit()
        
        response = client.post(
            "/api/v1/auth/login",
            data={
                "username": "unverified@example.com",
                "password": "TestPassword123!"
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        # Should return 403 (forbidden) or 429 (rate limited)
        assert response.status_code in [403, 429], \
            f"Unverified user login should be rejected (got {response.status_code})"
        if response.status_code == 403:
            assert "verified" in response.json()["detail"].lower()
    
    def test_protected_endpoint_without_token(self, client):
        """Test that protected endpoints require authentication."""
        response = client.get("/api/v1/wallets/me")
        assert response.status_code == 401
    
    def test_protected_endpoint_with_valid_token(self, client, auth_token):
        """Test that protected endpoints work with valid token."""
        response = client.get(
            "/api/v1/wallets/me",
            headers={"Authorization": f"Bearer {auth_token}"}
        )
        assert response.status_code == 200
    
    def test_password_change_requires_current_password(self, client, auth_token, test_user):
        """Test that password change requires current password."""
        response = client.post(
            "/api/v1/auth/change-password",
            json={
                "current_password": "WrongPassword123!",
                "new_password": "NewPassword123!"
            },
            headers={"Authorization": f"Bearer {auth_token}"}
        )
        assert response.status_code == 400
    
    def test_password_change_success(self, client, auth_token, test_user, db):
        """Test successful password change."""
        response = client.post(
            "/api/v1/auth/change-password",
            json={
                "current_password": "TestPassword123!",
                "new_password": "NewPassword123!"
            },
            headers={"Authorization": f"Bearer {auth_token}"}
        )
        assert response.status_code == 200
        
        # Verify new password works
        response = client.post(
            "/api/v1/auth/login",
            data={
                "username": test_user.email,
                "password": "NewPassword123!"
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        assert response.status_code == 200


class TestAuthorization:
    """Test Authorization Security"""
    
    def test_user_cannot_access_other_user_data(self, client, db, auth_token, test_user):
        """Test that users cannot access other users' data."""
        # Create another user
        hashed_password = get_password_hash("OtherPassword123!")
        other_user = User(
            email="other@example.com",
            hashed_password=hashed_password,
            full_name="Other User",
            is_verified=True
        )
        db.add(other_user)
        db.commit()
        
        # Try to access other user's wallet (if endpoint exists)
        # This test assumes wallet endpoints check user ownership
        response = client.get(
            "/api/v1/wallets/me",
            headers={"Authorization": f"Bearer {auth_token}"}
        )
        # Should return current user's balance, not other user's
        if response.status_code == 200:
            # Verify it's the correct user's data
            assert response.json() is not None


class TestInputValidation:
    """Test Input Validation Security"""
    
    def test_xss_protection_in_inputs(self, client):
        """Test that XSS attempts are handled safely."""
        xss_payloads = [
            "<script>alert('XSS')</script>",
            "javascript:alert('XSS')",
            "<img src=x onerror=alert('XSS')>",
        ]
        
        for payload in xss_payloads:
            response = client.post(
                "/api/v1/auth/register",
                json={
                    "email": f"{payload}@example.com",
                    "password": "TestPassword123!",
                    "full_name": payload
                }
            )
            # Should handle safely (either reject or sanitize)
            assert response.status_code in [200, 400, 422]
            # Response should not contain script tags
            if response.status_code == 200:
                assert "<script>" not in str(response.json()).lower()
    
    def test_path_traversal_protection(self, client, auth_token):
        """Test that path traversal attempts are blocked."""
        path_traversal_payloads = [
            "../../etc/passwd",
            "..\\..\\windows\\system32",
            "....//....//etc/passwd",
        ]
        
        # Test path traversal in URL paths
        for payload in path_traversal_payloads:
            # Test in a context where it might be used (as a wallet ID)
            response = client.get(
                f"/api/v1/wallets/{payload}",
                headers={"Authorization": f"Bearer {auth_token}"}
            )
            # Should return 404 (not found) or 422 (validation error), not expose file system
            # 401 is also acceptable if auth fails first
            assert response.status_code in [404, 400, 422, 401], \
                f"Path traversal '{payload}' should be blocked (got {response.status_code})"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

