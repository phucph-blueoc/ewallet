# 🔐 Tổng Hợp Các Kỹ Thuật Bảo Mật Trong E-Wallet App

Tài liệu này tổng hợp tất cả các kỹ thuật bảo mật được sử dụng trong ứng dụng E-Wallet, chỉ ra vị trí code trong project.

---

## 📋 Mục Lục

1. [Xác Thực & Phân Quyền](#1-xác-thực--phân-quyền)
   - [JWT Tokens](#11-jwt-tokens)
   - [OAuth2 Password Bearer](#12-oauth2-password-bearer)
   - [Password Hashing (bcrypt)](#13-password-hashing-bcrypt)
   - [OTP Verification (TOTP)](#14-otp-verification-totp)
   - [Transaction PIN](#15-transaction-pin)
   - [Biometric Authentication](#16-biometric-authentication)

2. [Mã Hóa Dữ Liệu](#2-mã-hóa-dữ-liệu)
   - [AES-256 Encryption (Fernet)](#21-aes-256-encryption-fernet)
   - [Encryption Key Management](#22-encryption-key-management)

3. [Bảo Mật Backend API](#3-bảo-mật-backend-api)
   - [Rate Limiting](#31-rate-limiting)
   - [SQL Injection Protection](#32-sql-injection-protection)
   - [Input Validation](#33-input-validation)

4. [Bảo Mật Mobile App](#4-bảo-mật-mobile-app)
   - [Secure Storage](#41-secure-storage)
   - [Auto Logout (Inactivity Wrapper)](#42-auto-logout-inactivity-wrapper)
   - [Certificate Pinning](#43-certificate-pinning)
   - [Root/Jailbreak Detection](#44-rootjailbreak-detection)
   - [Secure Keyboard/TextField](#45-secure-keyboardtextfield)

---

## 1. Xác Thực & Phân Quyền

### 1.1. JWT Tokens

**Định nghĩa:** `backend/app/core/security.py`
- Function: `create_access_token()` (dòng 37)
- Function: `create_refresh_token()` (dòng 47)
- Function: `get_current_user()` (dòng 65)

**Mô tả:** 
- Access Token: Thời hạn 30 phút (config trong `backend/app/core/config.py` dòng 17)
- Refresh Token: Thời hạn 7 ngày (config trong `backend/app/core/config.py` dòng 18)

**Sử dụng:**
- `create_access_token()` và `create_refresh_token()` được gọi trong:
  - `backend/app/api/v1/endpoints/auth.py` dòng 200-201 (login endpoint)

- `get_current_user()` được sử dụng làm dependency trong tất cả các endpoint cần authentication:
  - `backend/app/api/v1/endpoints/auth.py` (dòng 289, 339, 380)
  - `backend/app/api/v1/endpoints/wallets.py` (dòng 34, 43, 142, 240, 298, 428, 486, 557)
  - `backend/app/api/v1/endpoints/budgets.py` (dòng 111, 165, 191, 239, 279, 307)
  - `backend/app/api/v1/endpoints/bank_cards.py` (dòng 34, 113, 151, 193, 243, 270, 360)
  - `backend/app/api/v1/endpoints/bills.py` (dòng 32, 45, 94, 189, 217, 265, 303, 323)
  - `backend/app/api/v1/endpoints/contacts.py` (dòng 26, 69, 97, 126, 178, 209)
  - `backend/app/api/v1/endpoints/savings_goals.py` (dòng 26, 56, 79, 105, 149, 181, 254)
  - `backend/app/api/v1/endpoints/notifications.py` (dòng 40, 63, 86, 103, 128, 146, 171, 184)
  - `backend/app/api/v1/endpoints/alerts.py` (dòng 40, 63, 80, 105, 123, 148, 161)
  - `backend/app/api/v1/endpoints/devices.py` (dòng 23, 43, 101, 132)
  - `backend/app/api/v1/endpoints/analytics.py` (dòng 77, 198)
  - `backend/app/api/v1/endpoints/security.py` (dòng 23)

---

### 1.2. OAuth2 Password Bearer

**Định nghĩa:** `backend/app/core/security.py`
- Variable: `oauth2_scheme` (dòng 63)

**Mô tả:** Được sử dụng bởi FastAPI để xử lý OAuth2 authentication flow.

**Sử dụng:**
- Được sử dụng trong `get_current_user()` dependency (dòng 65 trong `backend/app/core/security.py`)
- Token URL được cấu hình trong `backend/app/core/config.py` (dòng 7)

---

### 1.3. Password Hashing (bcrypt)

**Định nghĩa:** `backend/app/core/security.py`
- Function: `get_password_hash()` (dòng 32)
- Function: `verify_password()` (dòng 27)
- Helper function: `_truncate_password()` (dòng 15)

**Mô tả:** 
- Sử dụng bcrypt với cost factor mặc định (12)
- Xử lý đặc biệt cho password dài hơn 72 bytes (truncate)

**Sử dụng:**

- `get_password_hash()` được gọi trong:
  - `backend/app/api/v1/endpoints/auth.py`:
    - Dòng 50: Khi đăng ký user mới
    - Dòng 317: Khi đổi password
    - Dòng 358: Khi set transaction PIN
  - `backend/generate_dummy_data.py` dòng 82: Tạo dummy users

- `verify_password()` được gọi trong:
  - `backend/app/api/v1/endpoints/auth.py`:
    - Dòng 137: Verify password khi login
    - Dòng 299: Verify current password khi đổi password
    - Dòng 306: Kiểm tra new password khác current password
    - Dòng 348: Verify current password khi set transaction PIN
    - Dòng 393: Verify transaction PIN
  - `backend/app/api/v1/endpoints/wallets.py`:
    - Dòng 77: Verify transaction PIN khi deposit
    - Dòng 175: Verify transaction PIN khi withdraw
    - Dòng 255: Verify transaction PIN khi request transfer OTP
    - Dòng 330: Verify transaction PIN khi transfer
    - Dòng 523: Verify transaction PIN khi deposit from card
    - Dòng 595: Verify transaction PIN khi withdraw to card
  - `backend/app/api/v1/endpoints/bills.py`:
    - Dòng 107: Verify transaction PIN khi pay bill

---

### 1.4. OTP Verification (TOTP)

**Định nghĩa:** `backend/app/services/otp.py`
- Class: `OTPService`
- Method: `generate_secret()`
- Method: `generate_otp()`
- Method: `verify_otp()`
- Method: `get_totp()`

**Mô tả:**
- Sử dụng pyotp với TOTP (Time-based One-Time Password)
- Interval: 300 giây (5 phút)
- OTP hết hạn sau 15 phút (config trong `backend/app/core/config.py` dòng 39)

**Sử dụng:**

- `backend/app/api/v1/endpoints/auth.py`:
  - Dòng 46-47: Generate OTP khi đăng ký (`/register`)
  - Dòng 232: Verify OTP khi xác thực email (`/verify-otp`)
  - Dòng 258-259: Generate OTP mới khi resend (`/resend-otp`)

- `backend/app/api/v1/endpoints/wallets.py`:
  - Dòng 247: Generate OTP khi request transfer OTP (`/transfer/request-otp`)
  - Dòng 347: Verify OTP khi transfer (`/transfer`)

---

### 1.5. Transaction PIN

**Model:** `backend/app/models/user.py`
- Column: `transaction_pin_hash` (dòng 18)

**Định nghĩa API:**
- `backend/app/api/v1/endpoints/auth.py`:
  - Endpoint: `/transaction-pin/set` (dòng 334)
  - Endpoint: `/transaction-pin/verify` (dòng 375)

**Mô tả:**
- Transaction PIN được hash bằng bcrypt (sử dụng `get_password_hash()`)
- PIN được verify bằng `verify_password()` trước mọi giao dịch quan trọng

**Sử dụng:**

Transaction PIN được verify trong:
- `backend/app/api/v1/endpoints/auth.py`:
  - Dòng 393: Verify PIN endpoint
- `backend/app/api/v1/endpoints/wallets.py`:
  - Dòng 77: Deposit từ bank card
  - Dòng 175: Withdraw
  - Dòng 255: Request transfer OTP
  - Dòng 330: Transfer
  - Dòng 523: Deposit from card
  - Dòng 595: Withdraw to card
- `backend/app/api/v1/endpoints/bills.py`:
  - Dòng 107: Pay bill

---

### 1.6. Biometric Authentication

**Định nghĩa:** `mobile/lib/services/biometric_service.dart`
- Class: `BiometricService`
- Method: `isAvailable()`
- Method: `getAvailableBiometrics()`
- Method: `authenticate()`
- Method: `getBiometricTypeName()`

**Sử dụng:**

- `mobile/lib/screens/auth/biometric_auth_screen.dart`:
  - Dòng 15, 28, 34, 40, 51: Sử dụng để xác thực khi mở app

- `mobile/lib/screens/settings/settings_screen.dart`:
  - Dòng 19, 36, 37, 48, 84: Sử dụng trong settings để bật/tắt biometric

- `mobile/lib/screens/wallet/transfer_screen.dart`:
  - Dòng 31, 56, 62, 65, 139: Xác thực biometric trước khi chuyển tiền

- `mobile/lib/screens/splash_screen.dart`:
  - Dòng 43-44: Kiểm tra biometric availability khi khởi động app

---

## 2. Mã Hóa Dữ Liệu

### 2.1. AES-256 Encryption (Fernet)

**Định nghĩa:** `backend/app/core/encryption.py`
- Class: `EncryptionService`
- Method: `encrypt()` (dòng 28)
- Method: `decrypt()` (dòng 34)
- Global instance: `encryption_service` (dòng 45)

**Mô tả:**
- Sử dụng Fernet (AES-128 với CBC mode)
- Mã hóa dữ liệu nhạy cảm trước khi lưu vào database

**Sử dụng:**

**Transaction Notes:**
- `backend/app/api/v1/endpoints/wallets.py`:
  - Dòng 105: Mã hóa note khi deposit
  - Dòng 203: Mã hóa note khi withdraw
  - Dòng 368: Mã hóa note khi transfer
  - Dòng 448: Giải mã note khi get transactions
- `backend/app/api/v1/endpoints/budgets.py`:
  - Dòng 92: Giải mã note để phân loại transaction
- `backend/app/api/v1/endpoints/analytics.py`:
  - Dòng 136: Giải mã note để phân tích spending
- `backend/app/api/v1/endpoints/bills.py`:
  - Dòng 129: Mã hóa note khi pay bill
- `backend/generate_dummy_data.py`:
  - Dòng 158, 177, 206: Mã hóa note khi tạo dummy transactions
- `backend/create_bill_dummy_data.py`:
  - Dòng 153: Mã hóa note khi tạo bill transactions

**Bank Card Data:**
- `backend/app/api/v1/endpoints/bank_cards.py`:
  - Dòng 49: Mã hóa card number khi create
  - Dòng 50: Mã hóa expiry date khi create
  - Dòng 51: Mã hóa CVV khi create
  - Dòng 125-126: Giải mã card number và expiry date khi get card
  - Dòng 168-169: Giải mã khi update card
  - Dòng 219-220: Giải mã khi verify card
  - Dòng 336-337: Giải mã khi deposit from card
  - Dòng 397: Giải mã card number khi withdraw to card

---

### 2.2. Encryption Key Management

**Định nghĩa:**
- Config: `backend/app/core/config.py` (dòng 21: `ENCRYPTION_KEY`)
- Key generation: `backend/setup.py` (function `generate_encryption_key()` dòng 15)

**Mô tả:**
- Encryption key được lưu trong environment variables (file `.env`)
- Key được generate bằng `Fernet.generate_key()` trong setup script

**Sử dụng:**
- Key được load tự động trong `EncryptionService.__init__()` (`backend/app/core/encryption.py` dòng 14)

---

## 3. Bảo Mật Backend API

### 3.1. Rate Limiting

**Định nghĩa:** `backend/app/core/rate_limit.py`
- Instance: `limiter` (dòng 6)
- Constants:
  - `AUTH_RATE_LIMIT = "5/minute"` (dòng 13)
  - `WALLET_OPERATION_LIMIT = "30/minute"` (dòng 14)
  - `GENERAL_LIMIT = "60/minute"` (dòng 15)

**Cấu hình:**
- Enable/disable: `backend/app/core/config.py` dòng 49 (`RATE_LIMIT_ENABLED`)
- Default limit: `backend/app/core/config.py` dòng 50 (`RATE_LIMIT_PER_MINUTE`)

**Sử dụng:**

**Auth endpoints (5 requests/phút):**
- `backend/app/api/v1/endpoints/auth.py`:
  - Dòng 32: `/register`
  - Dòng 126: `/login`
  - Dòng 210: `/verify-otp`
  - Dòng 242: `/resend-otp`
  - Dòng 285: `/change-password`
  - Dòng 335: `/transaction-pin/set`
  - Dòng 376: `/transaction-pin/verify`

**Wallet operations (30 requests/phút):**
- `backend/app/api/v1/endpoints/wallets.py`:
  - Dòng 39: `/deposit`
  - Dòng 138: `/withdraw`
  - Dòng 236: `/transfer/request-otp`
  - Dòng 294: `/transfer`
  - Dòng 482: `/deposit-from-card`
  - Dòng 553: `/withdraw-to-card`
- `backend/app/api/v1/endpoints/bills.py`:
  - Dòng 90: `/pay`
- `backend/app/api/v1/endpoints/bank_cards.py`:
  - Dòng 265: `/verify`

**General endpoints (60 requests/phút):**
- Tất cả các GET endpoints và các operations khác trong:
  - `backend/app/api/v1/endpoints/wallets.py` (dòng 33, 425)
  - `backend/app/api/v1/endpoints/budgets.py` (dòng 107, 159, 187, 234, 275, 303)
  - `backend/app/api/v1/endpoints/bank_cards.py` (dòng 30, 110, 147, 188, 239, 356)
  - `backend/app/api/v1/endpoints/bills.py` (dòng 29, 41, 186, 213, 260, 299, 320)
  - `backend/app/api/v1/endpoints/contacts.py` (dòng 22, 65, 93, 121, 174, 205)
  - `backend/app/api/v1/endpoints/savings_goals.py` (dòng 22, 52, 75, 100, 145, 176, 249)
  - `backend/app/api/v1/endpoints/notifications.py` (dòng 36, 58, 83, 99, 125, 142, 168, 180)
  - `backend/app/api/v1/endpoints/alerts.py` (dòng 35, 60, 76, 102, 119, 145, 157)
  - `backend/app/api/v1/endpoints/devices.py` (dòng 20, 39, 96, 128)
  - `backend/app/api/v1/endpoints/analytics.py` (dòng 70, 194)
  - `backend/app/api/v1/endpoints/security.py` (dòng 17)

---

### 3.2. SQL Injection Protection

**Mô tả:** Sử dụng SQLAlchemy ORM để tự động parameterize queries, chống SQL injection.

**Sử dụng:**
- Tất cả các database queries trong project đều sử dụng SQLAlchemy ORM, không có raw SQL queries
- Ví dụ trong:
  - `backend/app/api/v1/endpoints/auth.py`: `db.query(User).filter(User.email == email).first()`
  - `backend/app/api/v1/endpoints/wallets.py`: `db.query(Wallet).filter(Wallet.user_id == current_user.id).first()`
  - `backend/app/api/v1/endpoints/transactions.py`: `db.query(Transaction).filter(...)`
  - Tất cả các endpoints khác đều sử dụng pattern tương tự

---

### 3.3. Input Validation

**Định nghĩa:** `backend/app/schemas/`
- Pydantic models trong các file schema:
  - `backend/app/schemas/user.py`
  - `backend/app/schemas/wallet.py`
  - `backend/app/schemas/bank_card.py`
  - `backend/app/schemas/bill.py`
  - `backend/app/schemas/budget.py`
  - `backend/app/schemas/contact.py`
  - Và các schema khác

**Mô tả:**
- Tất cả input từ client đều được validate bởi Pydantic schemas
- FastAPI tự động validate và trả về 422 nếu input không hợp lệ

**Sử dụng:**
- Tất cả các endpoint POST/PUT đều sử dụng Pydantic schemas làm request models
- Ví dụ:
  - `backend/app/api/v1/endpoints/auth.py`: `UserCreate`, `OTPVerify`, `ChangePassword`, `TransactionPinRequest`
  - `backend/app/api/v1/endpoints/wallets.py`: `DepositRequest`, `WithdrawRequest`, `TransferRequest`
  - `backend/app/api/v1/endpoints/bank_cards.py`: `BankCardCreate`, `BankCardUpdate`
  - Và tất cả các endpoints khác

---

## 4. Bảo Mật Mobile App

### 4.1. Secure Storage

**Định nghĩa:** `mobile/lib/services/api_service.dart`
- Instance: `_storage = const FlutterSecureStorage()` (dòng 12)

**Mô tả:**
- Sử dụng `flutter_secure_storage` package
- Lưu JWT tokens vào Keychain (iOS) / Keystore (Android)

**Sử dụng:**
- `mobile/lib/services/api_service.dart`:
  - Dòng 102-103: Lưu access_token và refresh_token sau khi login
  - Dòng 112-113: Xóa tokens khi logout
  - Dòng 117: Đọc access_token để sử dụng trong API calls
  - Dòng 120-126: Sử dụng trong `_getHeaders()` để thêm Authorization header

---

### 4.2. Auto Logout (Inactivity Wrapper)

**Định nghĩa:** `mobile/lib/widgets/inactivity_wrapper.dart`
- Class: `InactivityWrapper` (dòng 8)
- State class: `_InactivityWrapperState` (dòng 22)
- Method: `_resetTimer()` (dòng 50)
- Method: `_onInactivityTimeout()` (dòng 55)

**Mô tả:**
- Tự động đăng xuất sau 10 phút không hoạt động
- Theo dõi tất cả user interactions (tap, scroll, pointer events)

**Sử dụng:**
- `mobile/lib/screens/wallet/wallet_home_screen.dart`:
  - Dòng 57: Wrap toàn bộ wallet home screen với `InactivityWrapper`

---

### 4.3. Certificate Pinning

**Định nghĩa:** `mobile/lib/services/certificate_pinning_service.dart`
- Class: `CertificatePinningService`
- Method: `createPinnedDio()` (dòng 16)
- Method: `_verifyCertificate()` (dòng 34)
- Method: `getCertificateFingerprint()` (dòng 57)

**Mô tả:**
- Verify SHA-256 fingerprint của server certificate
- Chống MITM (Man-in-the-Middle) attacks

**Sử dụng:**
- Service đã được định nghĩa nhưng chưa được tích hợp vào API calls
- Có thể sử dụng bằng cách gọi `CertificatePinningService.createPinnedDio()` thay vì `http` client thông thường

---

### 4.4. Root/Jailbreak Detection

**Định nghĩa:** `mobile/lib/services/security_service.dart`
- Class: `SecurityService` (dòng 4)
- Method: `isDeviceCompromised()` (dòng 10)
- Method: `getSecurityStatus()` (dòng 41)

**Mô tả:**
- Phát hiện thiết bị Android đã root hoặc iOS đã jailbreak
- Sử dụng package `root_detector`

**Sử dụng:**
- Có thể được sử dụng trong:
  - `mobile/lib/screens/security/security_check_screen.dart`
  - `mobile/lib/screens/settings/security_settings_screen.dart`
  - Các màn hình khác cần kiểm tra security status

---

### 4.5. Secure Keyboard/TextField

**Định nghĩa:** `mobile/lib/widgets/secure_text_field.dart`
- Class: `SecureTextField` (dòng 8)
- State class: `_SecureTextFieldState` (dòng 36)

**Mô tả:**
- TextField với các tính năng bảo mật:
  - Chặn text selection (`enableInteractiveSelection: false`)
  - Chỉ cho phép nhập số (`FilteringTextInputFormatter.digitsOnly`)
  - Tắt suggestions và autocorrect
  - Dark keyboard appearance

**Sử dụng:**
- Được sử dụng trong các màn hình cần nhập PIN hoặc password:
  - `mobile/lib/screens/settings/transaction_pin_screen.dart`
  - `mobile/lib/screens/auth/login_screen.dart`
  - Các màn hình khác cần input nhạy cảm

---

## 📊 Tổng Kết

### Bảo Mật Backend (Python/FastAPI)
1. ✅ JWT Tokens → `backend/app/core/security.py`
2. ✅ Password Hashing (bcrypt) → `backend/app/core/security.py`
3. ✅ OTP Verification (TOTP) → `backend/app/services/otp.py`
4. ✅ Transaction PIN → `backend/app/api/v1/endpoints/auth.py`
5. ✅ AES-256 Encryption → `backend/app/core/encryption.py`
6. ✅ Rate Limiting → `backend/app/core/rate_limit.py`
7. ✅ SQL Injection Protection → SQLAlchemy ORM (tất cả endpoints)
8. ✅ Input Validation → Pydantic schemas (`backend/app/schemas/`)

### Bảo Mật Mobile (Flutter)
1. ✅ Secure Storage → `mobile/lib/services/api_service.dart`
2. ✅ Auto Logout → `mobile/lib/widgets/inactivity_wrapper.dart`
3. ✅ Certificate Pinning → `mobile/lib/services/certificate_pinning_service.dart`
4. ✅ Root/Jailbreak Detection → `mobile/lib/services/security_service.dart`
5. ✅ Secure Keyboard/TextField → `mobile/lib/widgets/secure_text_field.dart`
6. ✅ Biometric Authentication → `mobile/lib/services/biometric_service.dart`

### Dữ Liệu Được Mã Hóa
- ✅ Transaction notes → `encryption_service.encrypt()` trong wallet/bills endpoints
- ✅ Bank card numbers → `encryption_service.encrypt()` trong bank_cards endpoints
- ✅ Bank card expiry dates → `encryption_service.encrypt()` trong bank_cards endpoints
- ✅ Bank card CVV → `encryption_service.encrypt()` trong bank_cards endpoints
- ✅ Passwords → `get_password_hash()` (bcrypt) trong auth endpoints
- ✅ Transaction PINs → `get_password_hash()` (bcrypt) trong auth endpoints

---

*Tài liệu này được tạo tự động dựa trên codebase thực tế của E-Wallet App.*
