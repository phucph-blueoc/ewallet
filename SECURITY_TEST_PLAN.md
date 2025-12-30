# Security Test Plan - E-Wallet Application

## Tổng Quan

Tài liệu này mô tả kế hoạch kiểm thử bảo mật cho ứng dụng E-Wallet, bao gồm cả backend API và mobile app.

## Mục Tiêu

- Đảm bảo các tính năng bảo mật hoạt động đúng như thiết kế
- Phát hiện các lỗ hổng bảo mật tiềm ẩn
- Xác minh tuân thủ các tiêu chuẩn bảo mật
- Đảm bảo dữ liệu người dùng được bảo vệ đúng cách

## Phạm Vi Kiểm Thử

### Backend API Security Tests

#### 1. SQL Injection Protection
- **Mục tiêu**: Đảm bảo ứng dụng không bị tấn công SQL injection
- **Test Cases**:
  - SQL injection trong email field
  - SQL injection trong password field
  - SQL injection trong registration endpoint
  - Xác minh không có lỗi database bị expose

#### 2. Rate Limiting
- **Mục tiêu**: Đảm bảo rate limiting hoạt động đúng
- **Test Cases**:
  - Rate limiting cho authentication endpoints
  - Rate limiting cho các endpoint khác
  - Format của response khi rate limit bị vượt quá

#### 3. Password Security
- **Mục tiêu**: Đảm bảo password được hash đúng cách
- **Test Cases**:
  - Password không được lưu plain text
  - Password hashing sử dụng salt (bcrypt)
  - Password verification hoạt động đúng
  - Hash length đúng chuẩn

#### 4. JWT Token Validation
- **Mục tiêu**: Đảm bảo JWT tokens được xử lý an toàn
- **Test Cases**:
  - Token creation với claims đúng
  - Token expiration hoạt động
  - Invalid token bị reject
  - Expired token bị reject
  - Token với wrong secret bị reject
  - Refresh token khác access token

#### 5. Data Encryption
- **Mục tiêu**: Đảm bảo encryption/decryption hoạt động đúng
- **Test Cases**:
  - Encryption và decryption đúng
  - Mỗi lần encrypt tạo output khác nhau (IV)
  - Decryption với wrong key thất bại
  - Xử lý empty strings đúng cách

#### 6. Authentication & Authorization
- **Mục tiêu**: Đảm bảo authentication và authorization hoạt động đúng
- **Test Cases**:
  - Login với invalid credentials thất bại
  - Unverified users không thể login
  - Protected endpoints yêu cầu authentication
  - Password change yêu cầu current password
  - Users không thể truy cập data của users khác

#### 7. Input Validation
- **Mục tiêu**: Đảm bảo input validation bảo vệ khỏi các tấn công
- **Test Cases**:
  - XSS protection
  - Path traversal protection
  - Input sanitization

### Mobile App Security Tests

#### 1. Secure Storage
- **Mục tiêu**: Đảm bảo sensitive data được lưu trong secure storage
- **Test Cases**:
  - Tokens được lưu trong FlutterSecureStorage
  - Tokens không được lưu trong SharedPreferences
  - Tokens được xóa khi logout
  - Xử lý null values đúng cách

#### 2. Biometric Authentication
- **Mục tiêu**: Đảm bảo biometric authentication hoạt động đúng
- **Test Cases**:
  - Kiểm tra biometric availability
  - Get available biometric types
  - Authenticate với biometrics
  - Xử lý authentication failure
  - Xử lý khi biometric không available

#### 3. Auto Logout / Session Management
- **Mục tiêu**: Đảm bảo session management hoạt động đúng
- **Test Cases**:
  - Track last activity timestamp
  - Detect inactivity timeout
  - Không logout nếu trong timeout period
  - Clear authentication state khi logout

#### 4. Token Management
- **Mục tiêu**: Đảm bảo token management an toàn
- **Test Cases**:
  - Access token retrieval
  - Refresh token retrieval
  - Xử lý missing tokens
  - Tokens được lưu riêng biệt

## Công Cụ và Framework

### Backend
- **Framework**: pytest
- **HTTP Client**: httpx (via FastAPI TestClient)
- **Database**: SQLite in-memory cho testing
- **Mocking**: pytest fixtures

### Mobile
- **Framework**: flutter_test
- **Mocking**: mockito
- **Storage**: FlutterSecureStorage (mocked)
- **Biometrics**: local_auth (mocked)

## Cách Chạy Tests

### Backend Tests

```bash
# Cài đặt dependencies
pip install -r requirements.txt

# Chạy tất cả security tests
pytest backend/tests/test_security.py -v

# Chạy một test class cụ thể
pytest backend/tests/test_security.py::TestSQLInjectionProtection -v

# Chạy một test cụ thể
pytest backend/tests/test_security.py::TestSQLInjectionProtection::test_sql_injection_in_email_field -v

# Chạy với coverage
pytest backend/tests/test_security.py --cov=app --cov-report=html
```

### Mobile Tests

```bash
cd mobile

# Generate mocks (chạy lần đầu)
flutter pub run build_runner build

# Chạy security tests
flutter test test/security_test.dart

# Chạy tất cả tests
flutter test
```

## Test Results và Reporting

### Kết Quả Mong Đợi

Tất cả tests phải pass để đảm bảo:
- ✅ Không có SQL injection vulnerabilities
- ✅ Rate limiting hoạt động đúng
- ✅ Passwords được hash đúng cách
- ✅ JWT tokens được validate đúng
- ✅ Encryption/decryption hoạt động đúng
- ✅ Authentication và authorization hoạt động đúng
- ✅ Secure storage được sử dụng đúng cách
- ✅ Biometric authentication hoạt động đúng
- ✅ Session management hoạt động đúng

### Reporting

Sau khi chạy tests, kết quả sẽ được báo cáo trong:
- Console output với test results
- Coverage reports (nếu có)
- Test logs

## Penetration Testing

### OWASP Mobile Top 10 Testing

Các test cases sau đây nên được thực hiện trong penetration testing:

1. **M1: Improper Platform Usage**
   - Test certificate pinning
   - Test secure storage usage
   - Test keychain/keystore usage

2. **M2: Insecure Data Storage**
   - Test sensitive data không được lưu plain text
   - Test secure storage implementation
   - Test data encryption

3. **M3: Insecure Communication**
   - Test HTTPS enforcement
   - Test certificate pinning
   - Test TLS configuration

4. **M4: Insecure Authentication**
   - Test biometric authentication
   - Test session management
   - Test token expiration

5. **M5: Insufficient Cryptography**
   - Test encryption algorithms
   - Test key management
   - Test random number generation

6. **M6: Insecure Authorization**
   - Test authorization checks
   - Test privilege escalation
   - Test access control

7. **M7: Client Code Quality**
   - Test code obfuscation
   - Test root/jailbreak detection
   - Test anti-tampering

8. **M8: Code Tampering**
   - Test app integrity checks
   - Test signature verification
   - Test debug detection

9. **M9: Reverse Engineering**
   - Test code obfuscation
   - Test string encryption
   - Test anti-debugging

10. **M10: Extraneous Functionality**
    - Test debug endpoints
    - Test test code removal
    - Test logging sensitive data

## Security Audit Checklist

### Static Code Analysis
- [ ] SonarQube scan
- [ ] CodeQL analysis
- [ ] Bandit (Python security linter)
- [ ] Flutter analyze với security rules

### Dependency Scanning
- [ ] pip-audit (Python dependencies)
- [ ] flutter pub outdated
- [ ] Snyk scan
- [ ] OWASP Dependency Check

### Security Code Review
- [ ] Authentication flow review
- [ ] Authorization logic review
- [ ] Encryption implementation review
- [ ] Input validation review
- [ ] Error handling review

### Third-Party Security Audit
- [ ] External security audit (recommended)
- [ ] Bug bounty program (optional)
- [ ] Security certification (optional)

## Security Incident Response Plan

### Phân Loại Sự Cố

1. **Critical**: Data breach, authentication bypass
2. **High**: SQL injection, XSS vulnerabilities
3. **Medium**: Rate limiting bypass, information disclosure
4. **Low**: Minor security improvements

### Quy Trình Xử Lý

1. **Phát Hiện**: Ghi nhận và phân loại sự cố
2. **Đánh Giá**: Xác định mức độ nghiêm trọng
3. **Khắc Phục**: Fix vulnerability hoặc mitigate risk
4. **Kiểm Thử**: Verify fix với security tests
5. **Triển Khai**: Deploy fix
6. **Báo Cáo**: Document incident và resolution

### Liên Hệ

- Security Team: [Contact Info]
- Emergency Contact: [Contact Info]

## Tài Liệu Tham Khảo

- [OWASP Mobile Top 10](https://owasp.org/www-project-mobile-top-10/)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

## Lịch Kiểm Thử

### Hàng Ngày
- Automated security tests trong CI/CD pipeline

### Hàng Tuần
- Review security test results
- Update test cases nếu cần

### Hàng Tháng
- Penetration testing
- Security audit review
- Dependency vulnerability scan

### Hàng Quý
- Comprehensive security audit
- Third-party security review
- Security training và awareness

## Kết Luận

Security test plan này cung cấp framework toàn diện để đảm bảo ứng dụng E-Wallet được bảo vệ khỏi các mối đe dọa bảo mật phổ biến. Việc thực hiện đều đặn các test cases này sẽ giúp duy trì mức độ bảo mật cao cho ứng dụng.

