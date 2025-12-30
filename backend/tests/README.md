# Backend Security Tests

## Tổng Quan

Thư mục này chứa các security test cases cho E-Wallet backend API.

## Cài Đặt

```bash
# Cài đặt dependencies
pip install -r requirements.txt
```

## Chạy Tests

### Chạy tất cả security tests
```bash
pytest tests/test_security.py -v
```

### Chạy một test class cụ thể
```bash
pytest tests/test_security.py::TestSQLInjectionProtection -v
```

### Chạy một test cụ thể
```bash
pytest tests/test_security.py::TestSQLInjectionProtection::test_sql_injection_in_email_field -v
```

### Chạy với coverage
```bash
pytest tests/test_security.py --cov=app --cov-report=html
```

## Test Classes

### TestSQLInjectionProtection
Kiểm tra bảo vệ khỏi SQL injection attacks:
- SQL injection trong email field
- SQL injection trong password field
- SQL injection trong registration endpoint

### TestRateLimiting
Kiểm tra rate limiting:
- Rate limiting cho authentication endpoints
- Format của rate limit responses

### TestPasswordHashing
Kiểm tra password security:
- Password không được lưu plain text
- Password hashing với salt
- Password verification

### TestJWTTokenValidation
Kiểm tra JWT token security:
- Token creation và validation
- Token expiration
- Invalid token rejection
- Refresh token handling

### TestEncryption
Kiểm tra data encryption:
- Encryption/decryption
- Key management
- Error handling

### TestAuthentication
Kiểm tra authentication:
- Login với invalid credentials
- Unverified user handling
- Protected endpoints
- Password change

### TestAuthorization
Kiểm tra authorization:
- User data isolation
- Access control

### TestInputValidation
Kiểm tra input validation:
- XSS protection
- Path traversal protection

## Cấu Trúc

- `conftest.py`: Pytest configuration và shared fixtures
- `test_security.py`: Security test cases

## Lưu Ý

- Tests sử dụng SQLite in-memory database để đảm bảo isolation
- Mỗi test tạo database mới và cleanup sau khi test xong
- Tests không cần database thật, có thể chạy độc lập

