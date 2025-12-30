# 🔐 Giải Thích Chi Tiết Các Kỹ Thuật Bảo Mật Và Cách Áp Dụng

Tài liệu này giải thích chi tiết từng kỹ thuật bảo mật được sử dụng trong E-Wallet App, bao gồm nguyên lý hoạt động, tầm quan trọng, và cách triển khai cụ thể.

---

## 📋 Mục Lục

1. [JWT Tokens - JSON Web Tokens](#1-jwt-tokens---json-web-tokens)
2. [OAuth2 Password Bearer](#2-oauth2-password-bearer)
3. [Password Hashing với bcrypt](#3-password-hashing-với-bcrypt)
4. [OTP Verification (TOTP)](#4-otp-verification-totp)
5. [Transaction PIN](#5-transaction-pin)
6. [Biometric Authentication](#6-biometric-authentication)
7. [AES-256 Encryption (Fernet)](#7-aes-256-encryption-fernet)
8. [Rate Limiting](#8-rate-limiting)
9. [SQL Injection Protection](#9-sql-injection-protection)
10. [Input Validation với Pydantic](#10-input-validation-với-pydantic)
11. [Secure Storage (Keychain/Keystore)](#11-secure-storage-keychainkeystore)
12. [Auto Logout (Inactivity Wrapper)](#12-auto-logout-inactivity-wrapper)
13. [Root/Jailbreak Detection](#13-rootjailbreak-detection)

---

## 1. JWT Tokens - JSON Web Tokens

### 🔍 Kỹ Thuật Là Gì?

JWT (JSON Web Token) là một chuẩn mở (RFC 7519) để truyền thông tin an toàn giữa các bên dưới dạng JSON object. Token được ký số để đảm bảo tính toàn vẹn.

### 💡 Tại Sao Quan Trọng?

1. **Stateless Authentication**: Server không cần lưu session, giảm tải cho database
2. **Scalability**: Dễ dàng scale horizontally vì không cần chia sẻ session state
3. **Security**: Token được ký số, khó giả mạo
4. **Portability**: Token có thể được sử dụng trên nhiều domain/API khác nhau

### ⚙️ Cách Hoạt Động

JWT gồm 3 phần, ngăn cách bởi dấu chấm (`.`):
```
Header.Payload.Signature
```

1. **Header**: Chứa thuật toán mã hóa (ví dụ: HS256)
2. **Payload**: Chứa claims (thông tin như user email, expiration time)
3. **Signature**: Được tạo bằng cách mã hóa Header + Payload với secret key

### 📍 Áp Dụng Trong Dự Án

**File**: `backend/app/core/security.py`

**Tạo Access Token (30 phút)**:
```python
def create_access_token(subject: Union[str, Any], expires_delta: timedelta = None) -> str:
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)  # 30 phút
    
    to_encode = {"sub": str(subject), "exp": expire, "type": "access"}
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt
```

**Tạo Refresh Token (7 ngày)**:
```python
def create_refresh_token(subject: Union[str, Any], expires_delta: timedelta = None) -> str:
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)  # 7 ngày
    
    to_encode = {"sub": str(subject), "exp": expire, "type": "refresh"}
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt
```

**Verify Token và Lấy User**:
```python
def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")  # Lấy email từ payload
        user = db.query(User).filter(User.email == email).first()
        return user
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

**Luồng Hoạt Động**:

1. **Login**: User đăng nhập → Server tạo Access Token (30 phút) + Refresh Token (7 ngày) → Trả về cho client
2. **API Request**: Client gửi Access Token trong header `Authorization: Bearer <token>` → Server verify token → Xử lý request
3. **Token Expired**: Access token hết hạn → Client dùng Refresh Token để lấy Access Token mới
4. **Refresh Token Expired**: User phải login lại

**Sử Dụng Trong Endpoints**:
- Tất cả protected endpoints sử dụng `Depends(get_current_user)` để verify token
- Ví dụ: `backend/app/api/v1/endpoints/wallets.py` dòng 34, 43, 142...

---

## 2. OAuth2 Password Bearer

### 🔍 Kỹ Thuật Là Gì?

OAuth2 Password Bearer là một flow trong OAuth2, cho phép client gửi username/password trực tiếp để nhận access token.

### 💡 Tại Sao Quan Trọng?

1. **Standard Protocol**: Tuân theo chuẩn OAuth2 được công nhận rộng rãi
2. **Security**: Token được truyền trong header, không trong URL
3. **FastAPI Integration**: Tích hợp sẵn với FastAPI security system

### ⚙️ Cách Hoạt Động

1. Client gửi username/password đến `/auth/login` endpoint
2. Server xác thực credentials và trả về access token
3. Client lưu token và gửi trong header `Authorization: Bearer <token>` cho các request sau

### 📍 Áp Dụng Trong Dự Án

**File**: `backend/app/core/security.py`

```python
oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/auth/login")
```

**Sử dụng**:
- FastAPI tự động extract token từ `Authorization` header
- Token được truyền vào `get_current_user()` dependency
- Không cần code thủ công để parse header

**Endpoint Login** (`backend/app/api/v1/endpoints/auth.py`):
```python
@router.post("/login", response_model=Token)
async def login(
    request: Request, 
    form_data: OAuth2PasswordRequestForm = Depends(),  # FastAPI tự động parse form
    db: Session = Depends(get_db)
):
    # Verify password
    user = db.query(User).filter(User.email == form_data.username).first()
    if not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Incorrect credentials")
    
    # Create tokens
    access_token = create_access_token(subject=user.email)
    refresh_token = create_refresh_token(subject=user.email)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }
```

---

## 3. Password Hashing với bcrypt

### 🔍 Kỹ Thuật Là Gì?

bcrypt là thuật toán hash mật khẩu một chiều (one-way hashing), sử dụng Blowfish cipher với salt tự động và cost factor có thể điều chỉnh.

### 💡 Tại Sao Quan Trọng?

1. **Không thể reverse**: Hash là one-way, không thể khôi phục password gốc
2. **Salt tự động**: Mỗi password có salt riêng, chống rainbow table attacks
3. **Cost factor**: Có thể tăng độ khó tính toán, chống brute force
4. **Industry Standard**: Được sử dụng rộng rãi và đã được kiểm chứng

### ⚙️ Cách Hoạt Động

1. **Hash**: Password → bcrypt → Hash string (chứa salt + hash)
2. **Verify**: Plain password + Hash string → bcrypt verify → True/False

**Cấu trúc bcrypt hash**:
```
$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5LS2j1uF5q5Ku
  │  │  │                    └─ Hash (31 chars)
  │  │  └─ Salt (22 chars)
  │  └─ Cost factor (12 = 2^12 iterations)
  └─ Algorithm version (2b)
```

### 📍 Áp Dụng Trong Dự Án

**File**: `backend/app/core/security.py`

**Hash Password**:
```python
def get_password_hash(password: str) -> str:
    truncated_password = _truncate_password(password)  # Xử lý password > 72 bytes
    return pwd_context.hash(truncated_password)
```

**Verify Password**:
```python
def verify_password(plain_password: str, hashed_password: str) -> bool:
    truncated_password = _truncate_password(plain_password)
    return pwd_context.verify(truncated_password, hashed_password)
```

**Xử lý đặc biệt**:
- bcrypt chỉ hỗ trợ password tối đa 72 bytes
- Function `_truncate_password()` xử lý password dài hơn 72 bytes để tránh lỗi

**Sử Dụng**:

1. **Khi đăng ký** (`backend/app/api/v1/endpoints/auth.py` dòng 50):
```python
hashed_password = get_password_hash(user.password)
db_user = User(email=user.email, hashed_password=hashed_password)
```

2. **Khi login** (dòng 137):
```python
if not verify_password(form_data.password, user.hashed_password):
    raise HTTPException(status_code=401, detail="Incorrect password")
```

3. **Khi đổi password** (dòng 317):
```python
current_user.hashed_password = get_password_hash(data.new_password)
```

**Lưu ý**:
- Password **KHÔNG BAO GIỜ** được lưu plain text trong database
- Chỉ lưu hash string
- Khi verify, so sánh hash của password nhập vào với hash đã lưu

---

## 4. OTP Verification (TOTP)

### 🔍 Kỹ Thuật Là Gì?

TOTP (Time-based One-Time Password) là thuật toán tạo mã OTP dựa trên thời gian, theo chuẩn RFC 6238. OTP thay đổi theo chuẩn thời gian (mỗi 30-300 giây).

### 💡 Tại Sao Quan Trọng?

1. **Two-Factor Authentication**: Tăng cường bảo mật bằng layer xác thực thứ 2
2. **Time-based**: OTP tự động hết hạn sau một khoảng thời gian
3. **Không cần shared secret**: Server và client không cần sync qua network
4. **Standard**: Tuân theo chuẩn RFC, có thể tích hợp với Google Authenticator

### ⚙️ Cách Hoạt Động

1. **Generate Secret**: Server tạo random secret (base32 encoded)
2. **Generate OTP**: 
   - Current time / interval → Time counter
   - HMAC-SHA1(secret, time_counter) → Hash
   - Extract 6 digits từ hash → OTP
3. **Verify**: Server tính OTP với cùng secret và time → So sánh với OTP user nhập
4. **Time Window**: Cho phép sai lệch ±1 time step để xử lý clock drift

### 📍 Áp Dụng Trong Dự Án

**File**: `backend/app/services/otp.py`

```python
class OTPService:
    def generate_secret(self) -> str:
        return pyotp.random_base32()  # Tạo secret ngẫu nhiên
    
    def get_totp(self, secret: str):
        return pyotp.TOTP(secret, interval=300)  # Interval 5 phút (300 giây)
    
    def verify_otp(self, secret: str, otp: str) -> bool:
        totp = self.get_totp(secret)
        return totp.verify(otp)  # Verify với time window
    
    def generate_otp(self, secret: str) -> str:
        totp = self.get_totp(secret)
        return totp.now()  # Tạo OTP hiện tại
```

**Luồng Hoạt Động**:

**1. Đăng ký** (`backend/app/api/v1/endpoints/auth.py` dòng 46-47):
```python
# Tạo OTP secret và code
otp_secret = otp_service.generate_secret()
otp_code = otp_service.generate_otp(otp_secret)

# Lưu secret vào database
db_user = User(otp_secret=otp_secret, otp_created_at=datetime.utcnow())

# Gửi OTP qua email
send_otp_email_async(to_email=user.email, otp_code=otp_code)
```

**2. Verify OTP** (dòng 232):
```python
# Verify OTP và check expiry
if datetime.utcnow() > user.otp_created_at + timedelta(minutes=15):
    raise HTTPException(status_code=400, detail="OTP expired")

if not otp_service.verify_otp(user.otp_secret, otp_data.otp_code):
    raise HTTPException(status_code=400, detail="Invalid OTP")

# Mark user as verified
user.is_verified = True
```

**3. Chuyển tiền** (`backend/app/api/v1/endpoints/wallets.py`):
- Request OTP (dòng 247): Tạo OTP mới cho giao dịch
- Verify OTP (dòng 347): Verify trước khi thực hiện transfer

**Đặc Điểm**:
- **Interval**: 300 giây (5 phút) - OTP hợp lệ trong 5 phút
- **Expiry**: 15 phút - Secret hết hạn sau 15 phút nếu không dùng
- **6 digits**: OTP có 6 chữ số

---

## 5. Transaction PIN

### 🔍 Kỹ Thuật Là Gì?

Transaction PIN là mã PIN 6 chữ số được sử dụng để xác thực các giao dịch tài chính quan trọng. PIN được hash bằng bcrypt giống như password.

### 💡 Tại Sao Quan Trọng?

1. **Bảo Vệ Giao Dịch**: Tăng cường bảo mật cho các thao tác nhạy cảm
2. **Hai Lớp Xác Thực**: Kết hợp với OTP tạo ra 2FA cho giao dịch
3. **User-Friendly**: Dễ nhớ và nhập hơn password dài
4. **Separation of Concerns**: Tách biệt authentication (login) và authorization (transaction)

### ⚙️ Cách Hoạt Động

1. User set PIN khi đăng ký hoặc trong settings
2. PIN được hash bằng bcrypt và lưu trong database
3. Khi thực hiện giao dịch, user nhập PIN
4. Server verify PIN bằng `verify_password()` (cùng logic với password)
5. Nếu đúng, giao dịch được thực hiện

### 📍 Áp Dụng Trong Dự Án

**Model**: `backend/app/models/user.py`
```python
class User(Base):
    transaction_pin_hash = Column(String, nullable=True)  # Lưu PIN hash
```

**Set PIN** (`backend/app/api/v1/endpoints/auth.py` dòng 334):
```python
@router.post("/transaction-pin/set")
async def set_transaction_pin(
    data: TransactionPinRequest,
    current_user: User = Depends(get_current_user),
):
    # Verify current password trước
    if not verify_password(data.current_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Current password incorrect")
    
    # Hash và lưu PIN
    current_user.transaction_pin_hash = get_password_hash(data.transaction_pin)
    db.commit()
```

**Verify PIN** (dòng 375):
```python
@router.post("/transaction-pin/verify")
async def verify_transaction_pin(
    data: TransactionPinVerify,
    current_user: User = Depends(get_current_user),
):
    if not verify_password(data.transaction_pin, current_user.transaction_pin_hash):
        raise HTTPException(status_code=400, detail="Invalid PIN")
```

**Sử Dụng Trong Giao Dịch**:

1. **Transfer** (`backend/app/api/v1/endpoints/wallets.py` dòng 330):
```python
# Verify PIN trước khi transfer
if not verify_password(transfer_request.transaction_pin, current_user.transaction_pin_hash):
    raise HTTPException(status_code=400, detail="Invalid transaction PIN")

# Sau đó verify OTP
if not otp_service.verify_otp(current_user.otp_secret, transfer_request.otp_code):
    raise HTTPException(status_code=400, detail="Invalid OTP")

# Thực hiện transfer
```

2. **Deposit/Withdraw** (dòng 77, 175): Tương tự verify PIN
3. **Pay Bill** (`backend/app/api/v1/endpoints/bills.py` dòng 107): Verify PIN

**Luồng Giao Dịch An Toàn**:
1. User nhập transaction PIN
2. Verify PIN (layer 1)
3. Request OTP
4. User nhập OTP
5. Verify OTP (layer 2)
6. Thực hiện giao dịch

---

## 6. Biometric Authentication

### 🔍 Kỹ Thuật Là Gì?

Xác thực sinh trắc học sử dụng đặc điểm sinh học của người dùng như vân tay, khuôn mặt để xác thực.

### 💡 Tại Sao Quan Trọng?

1. **User Experience**: Nhanh chóng, tiện lợi, không cần nhập password
2. **Bảo Mật Cao**: Khó giả mạo hơn password/PIN
3. **Mobile Native**: Tận dụng tính năng sẵn có của thiết bị
4. **Accessibility**: Dễ sử dụng cho mọi người

### ⚙️ Cách Hoạt Động

1. App kiểm tra thiết bị có hỗ trợ biometric không
2. Gọi native API (iOS: LocalAuthentication, Android: BiometricPrompt)
3. Hệ điều hành hiển thị dialog xác thực
4. User xác thực bằng fingerprint/face
5. OS trả về kết quả (success/failure) cho app
6. App xử lý kết quả

### 📍 Áp Dụng Trong Dự Án

**File**: `mobile/lib/services/biometric_service.dart`

```dart
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  // Kiểm tra thiết bị hỗ trợ biometric
  Future<bool> isAvailable() async {
    final canCheckBiometrics = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    return canCheckBiometrics || isDeviceSupported;
  }
  
  // Lấy danh sách loại biometric hỗ trợ
  Future<List<BiometricType>> getAvailableBiometrics() async {
    return await _localAuth.getAvailableBiometrics();
  }
  
  // Xác thực
  Future<bool> authenticate({
    String reason = 'Please authenticate to access your wallet',
  }) async {
    return await _localAuth.authenticate(
      localizedReason: reason,
      options: AuthenticationOptions(
        useErrorDialogs: true,
        stickyAuth: true,
        biometricOnly: false,  // Cho phép fallback về device password
      ),
    );
  }
}
```

**Sử Dụng**:

1. **App Unlock** (`mobile/lib/screens/auth/biometric_auth_screen.dart`):
```dart
Future<void> _authenticate() async {
  final isAvailable = await _biometricService.isAvailable();
  if (!isAvailable) {
    // Fallback về password login
    return;
  }
  
  final didAuthenticate = await _biometricService.authenticate(
    reason: 'Xác thực để truy cập ví',
  );
  
  if (didAuthenticate) {
    // Navigate to home
  }
}
```

2. **Transfer** (`mobile/lib/screens/wallet/transfer_screen.dart`):
- Xác thực biometric trước khi cho phép chuyển tiền

3. **Settings** (`mobile/lib/screens/settings/settings_screen.dart`):
- Bật/tắt biometric authentication
- Hiển thị loại biometric có sẵn

**Hỗ Trợ**:
- iOS: Face ID, Touch ID
- Android: Fingerprint, Face Recognition

---

## 7. AES-256 Encryption (Fernet)

### 🔍 Kỹ Thuật Là Gì?

Fernet là một symmetric encryption scheme dựa trên AES-128 trong CBC mode với HMAC authentication, được cung cấp bởi Python `cryptography` library.

### 💡 Tại Sao Quan Trọng?

1. **Bảo Vệ Dữ Liệu Nhạy Cảm**: Mã hóa dữ liệu trước khi lưu database
2. **Symmetric Encryption**: Nhanh hơn asymmetric, phù hợp cho large data
3. **Authenticated Encryption**: Đảm bảo cả confidentiality và integrity
4. **Industry Standard**: AES là chuẩn mã hóa được sử dụng rộng rãi

### ⚙️ Cách Hoạt Động

1. **Key Generation**: Tạo 32-byte key (256 bits) → Base64 encode
2. **Encryption**:
   - Generate random IV (Initialization Vector)
   - Encrypt data với AES-128-CBC
   - Sign với HMAC-SHA256
   - Combine → Base64 encode → Ciphertext
3. **Decryption**:
   - Base64 decode ciphertext
   - Verify HMAC signature
   - Decrypt với AES-128-CBC
   - Return plaintext

**Fernet Token Format**:
```
Version (1 byte) | Timestamp (8 bytes) | IV (16 bytes) | Ciphertext | HMAC (32 bytes)
```

### 📍 Áp Dụng Trong Dự Án

**File**: `backend/app/core/encryption.py`

```python
class EncryptionService:
    def __init__(self, key: str = None):
        if key is None:
            key = settings.ENCRYPTION_KEY  # Load từ environment variable
        
        self.fernet = Fernet(key.encode())  # Initialize Fernet với key
    
    def encrypt(self, data: str) -> str:
        if not data:
            return None
        return self.fernet.encrypt(data.encode()).decode()  # Encrypt → Base64
    
    def decrypt(self, token: str) -> str:
        if not token:
            return None
        return self.fernet.decrypt(token.encode()).decode()  # Decrypt
```

**Key Management**:
- Key được lưu trong environment variable (`.env`)
- Generate key: `python -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'`
- Setup script: `backend/setup.py` tự động generate key

**Sử Dụng**:

**1. Transaction Notes** (`backend/app/api/v1/endpoints/wallets.py`):

**Khi lưu** (dòng 368):
```python
note = transfer_request.note or "Transfer"
encrypted_note = encryption_service.encrypt(note)  # Mã hóa note

transaction = Transaction(
    encrypted_note=encrypted_note  # Lưu encrypted note
)
```

**Khi đọc** (dòng 448):
```python
for tx in transactions:
    note = encryption_service.decrypt(tx.encrypted_note)  # Giải mã note
    result.append(TransactionResponse(note=note))
```

**2. Bank Card Data** (`backend/app/api/v1/endpoints/bank_cards.py`):

**Khi lưu** (dòng 49-51):
```python
card_number_encrypted = encryption_service.encrypt(card.card_number)
expiry_date_encrypted = encryption_service.encrypt(card.expiry_date)
cvv_encrypted = encryption_service.encrypt(card.cvv)

bank_card = BankCard(
    card_number_encrypted=card_number_encrypted,
    expiry_date_encrypted=expiry_date_encrypted,
    cvv_encrypted=cvv_encrypted,
)
```

**Khi đọc** (dòng 125-126):
```python
card_number = encryption_service.decrypt(card.card_number_encrypted)
expiry_date = encryption_service.decrypt(card.expiry_date_encrypted)
# CVV thường không được trả về sau khi lưu lần đầu
```

**Dữ Liệu Được Mã Hóa**:
- ✅ Transaction notes
- ✅ Bank card numbers
- ✅ Bank card expiry dates
- ✅ Bank card CVV

**Lưu Ý Bảo Mật**:
- Key phải được bảo vệ cẩn thận (environment variable, không commit vào git)
- Nếu key bị mất/thay đổi, dữ liệu đã mã hóa không thể giải mã được
- Key rotation cần quy trình cẩn thận để không mất dữ liệu

---

## 8. Rate Limiting

### 🔍 Kỹ Thuật Là Gì?

Rate Limiting là kỹ thuật giới hạn số lượng requests từ một client trong một khoảng thời gian nhất định.

### 💡 Tại Sao Quan Trọng?

1. **Chống Brute Force**: Ngăn attacker thử nhiều password/OTP
2. **Chống DDoS**: Giảm tải server khi có quá nhiều requests
3. **Bảo Vệ Tài Nguyên**: Đảm bảo server không bị quá tải
4. **Fair Usage**: Đảm bảo tất cả users có trải nghiệm tốt

### ⚙️ Cách Hoạt Động

1. Track số lượng requests từ mỗi IP address
2. Khi request đến, kiểm tra số requests đã thực hiện trong time window
3. Nếu vượt quá limit → Trả về 429 Too Many Requests
4. Reset counter sau time window

### 📍 Áp Dụng Trong Dự Án

**File**: `backend/app/core/rate_limit.py`

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

# Tạo limiter với key là IP address
limiter = Limiter(
    key_func=get_remote_address,  # Key = IP address của client
    default_limits=[f"{settings.RATE_LIMIT_PER_MINUTE}/minute"],
    enabled=settings.RATE_LIMIT_ENABLED
)

# Định nghĩa limits cho từng loại endpoint
AUTH_RATE_LIMIT = "5/minute"  # Auth endpoints: 5 requests/phút
WALLET_OPERATION_LIMIT = "30/minute"  # Wallet operations: 30 requests/phút
GENERAL_LIMIT = "60/minute"  # General endpoints: 60 requests/phút
```

**Sử Dụng**:

**Auth Endpoints** (5 requests/phút) - `backend/app/api/v1/endpoints/auth.py`:
```python
@router.post("/login")
@limiter.limit(AUTH_RATE_LIMIT)  # 5 requests/phút
async def login(...):
    # ...

@router.post("/register")
@limiter.limit(AUTH_RATE_LIMIT)  # 5 requests/phút
async def register(...):
    # ...
```

**Wallet Operations** (30 requests/phút) - `backend/app/api/v1/endpoints/wallets.py`:
```python
@router.post("/transfer")
@limiter.limit(WALLET_OPERATION_LIMIT)  # 30 requests/phút
async def transfer(...):
    # ...

@router.post("/deposit")
@limiter.limit(WALLET_OPERATION_LIMIT)  # 30 requests/phút
async def deposit(...):
    # ...
```

**General Endpoints** (60 requests/phút):
- GET endpoints
- Các operations ít nhạy cảm hơn

**Response Khi Vượt Limit**:
```json
{
  "detail": "Rate limit exceeded: 5 per 1 minute"
}
```
HTTP Status: 429 Too Many Requests

**Cấu Hình** (`backend/app/core/config.py`):
```python
RATE_LIMIT_ENABLED: bool = True
RATE_LIMIT_PER_MINUTE: int = 60  # Default limit
```

---

## 9. SQL Injection Protection

### 🔍 Kỹ Thuật Là Gì?

SQL Injection là lỗ hổng bảo mật khi attacker có thể inject mã SQL độc hại vào query. Protection là cách ngăn chặn lỗ hổng này.

### 💡 Tại Sao Quan Trọng?

1. **Bảo Vệ Database**: Ngăn attacker truy cập/thiệt hại dữ liệu
2. **Data Integrity**: Đảm bảo dữ liệu không bị thay đổi bất hợp pháp
3. **Compliance**: Tuân thủ các chuẩn bảo mật (OWASP Top 10)
4. **Critical**: SQL injection là một trong những lỗ hổng nguy hiểm nhất

### ⚙️ Cách Hoạt Động

**SQL Injection Attack Example**:
```sql
-- Input: admin' OR '1'='1
-- Nếu không parameterize:
SELECT * FROM users WHERE email = 'admin' OR '1'='1'  -- ❌ Nguy hiểm!

-- Với ORM (SQLAlchemy):
user = db.query(User).filter(User.email == email).first()  -- ✅ An toàn
-- ORM tự động escape và parameterize
```

**ORM Protection**:
- ORM tự động escape special characters
- Sử dụng parameterized queries
- Type checking và validation

### 📍 Áp Dụng Trong Dự Án

**Không sử dụng Raw SQL**, tất cả queries đều qua SQLAlchemy ORM:

**Ví dụ An Toàn** - `backend/app/core/security.py`:
```python
def get_current_user(token: str, db: Session) -> User:
    payload = jwt.decode(token, SECRET_KEY)
    email = payload.get("sub")
    
    # ✅ ORM tự động parameterize, không thể SQL injection
    user = db.query(User).filter(User.email == email).first()
    return user
```

**Ví dụ Khác** - `backend/app/api/v1/endpoints/wallets.py`:
```python
# ✅ An toàn: ORM filter
transactions = db.query(Transaction).filter(
    (Transaction.sender_id == current_user.id) | 
    (Transaction.receiver_id == current_user.id)
).order_by(Transaction.timestamp.desc()).all()

# ✅ An toàn: ORM relationship
wallet = db.query(Wallet).filter(Wallet.user_id == current_user.id).first()

# ✅ An toàn: ORM join
user = db.query(User).join(Wallet).filter(User.email == email).first()
```

**❌ KHÔNG BAO GIỜ làm**:
```python
# ❌ NGUY HIỂM: Raw SQL với string formatting
db.execute(f"SELECT * FROM users WHERE email = '{email}'")

# ❌ NGUY HIỂM: Raw SQL với % formatting
db.execute("SELECT * FROM users WHERE email = '%s'" % email)
```

**Best Practices**:
- ✅ Luôn sử dụng SQLAlchemy ORM
- ✅ Sử dụng `.filter()`, `.join()` methods
- ✅ Không dùng raw SQL queries
- ✅ Validate input trước khi query (qua Pydantic)

---

## 10. Input Validation với Pydantic

### 🔍 Kỹ Thuật Là Gì?

Input Validation là quá trình kiểm tra và sanitize dữ liệu đầu vào từ client trước khi xử lý. Pydantic là library Python sử dụng type hints để validate data.

### 💡 Tại Sao Quan Trọng?

1. **Data Integrity**: Đảm bảo dữ liệu đúng format và type
2. **Security**: Ngăn chặn invalid/malicious data
3. **Error Handling**: Phát hiện lỗi sớm, trả về error message rõ ràng
4. **Developer Experience**: Tự động generate documentation và type checking

### ⚙️ Cách Hoạt Động

1. Định nghĩa Pydantic model với type hints và validators
2. FastAPI tự động validate request body/query params theo model
3. Nếu invalid → Trả về 422 Unprocessable Entity với error details
4. Nếu valid → Data được parse và type-cast tự động

### 📍 Áp Dụng Trong Dự Án

**File**: `backend/app/schemas/user.py`

**Ví dụ Schema**:
```python
from pydantic import BaseModel, EmailStr, validator

class UserCreate(BaseModel):
    email: EmailStr  # ✅ Tự động validate email format
    password: str
    full_name: str
    
    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if len(v) > 128:
            raise ValueError('Password must be at most 128 characters')
        return v

class TransactionPinRequest(BaseModel):
    current_password: str
    transaction_pin: str
    
    @validator('transaction_pin')
    def validate_pin(cls, v):
        if not v.isdigit():
            raise ValueError('Transaction PIN must contain only digits')
        if len(v) != 6:
            raise ValueError('Transaction PIN must be 6 digits')
        return v
```

**Sử Dụng Trong Endpoint**:
```python
@router.post("/register", response_model=UserResponse)
async def register(user: UserCreate, db: Session = Depends(get_db)):
    # FastAPI tự động validate user.email, user.password, user.full_name
    # Nếu invalid → Trả về 422 với error details
    
    # Data đã được validate, an toàn để sử dụng
    hashed_password = get_password_hash(user.password)
    db_user = User(email=user.email, ...)
```

**Validation Rules**:

1. **Email**: `EmailStr` - Validate format email
2. **Password**: Min 8, max 128 characters
3. **Transaction PIN**: 6 digits only
4. **Amount**: Positive number, max limit
5. **Date/Time**: ISO format

**Error Response**:
```json
{
  "detail": [
    {
      "loc": ["body", "transaction_pin"],
      "msg": "Transaction PIN must be 6 digits",
      "type": "value_error"
    }
  ]
}
```

**Schemas Location**:
- `backend/app/schemas/user.py` - User, Auth schemas
- `backend/app/schemas/wallet.py` - Wallet, Transaction schemas
- `backend/app/schemas/bank_card.py` - Bank card schemas
- Và các schemas khác trong `backend/app/schemas/`

---

## 11. Secure Storage (Keychain/Keystore)

### 🔍 Kỹ Thuật Là Gì?

Secure Storage là cách lưu trữ dữ liệu nhạy cảm (tokens, keys) trên thiết bị di động sử dụng hệ thống bảo mật native của OS.

### 💡 Tại Sao Quan Trọng?

1. **OS-Level Security**: Sử dụng hardware security của thiết bị
2. **Encrypted Storage**: Dữ liệu được mã hóa bởi OS
3. **Access Control**: Chỉ app có thể truy cập dữ liệu của chính nó
4. **No Plain Text**: Dữ liệu không bao giờ lưu plain text trong app storage

### ⚙️ Cách Hoạt Động

**iOS - Keychain**:
- Keychain là encrypted database của iOS
- Mỗi app có keychain access group riêng
- Dữ liệu được encrypt bằng device key (hardware-backed)
- Chỉ app đó mới có thể truy cập

**Android - Keystore**:
- Android Keystore là hardware-backed storage
- Keys được lưu trong secure hardware (Trusted Execution Environment)
- Mỗi app có keystore riêng
- Không thể extract keys từ keystore

### 📍 Áp Dụng Trong Dự Án

**File**: `mobile/lib/services/api_service.dart`

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();
  
  // Lưu tokens sau khi login
  Future<Map<String, dynamic>> login(...) async {
    final response = await http.post(...);
    final data = jsonDecode(response.body);
    
    // ✅ Lưu vào secure storage (Keychain/Keystore)
    await _storage.write(key: 'access_token', value: data['access_token']);
    await _storage.write(key: 'refresh_token', value: data['refresh_token']);
    
    return data;
  }
  
  // Đọc token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');  // Đọc từ secure storage
  }
  
  // Xóa tokens khi logout
  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
}
```

**Dữ Liệu Được Lưu**:
- ✅ `access_token` - JWT access token
- ✅ `refresh_token` - JWT refresh token

**Dữ Liệu KHÔNG Được Lưu**:
- ❌ Passwords
- ❌ Transaction PINs
- ❌ OTP codes
- ❌ Plain text sensitive data

**Package**: `flutter_secure_storage`
- Tự động sử dụng Keychain trên iOS
- Tự động sử dụng Keystore trên Android
- Cross-platform API, không cần code riêng cho từng platform

**Security Benefits**:
1. Tokens được encrypt bởi OS
2. Không thể đọc từ file system
3. Protected bởi device lock screen
4. Không bị lộ khi app bị decompile

---

## 12. Auto Logout (Inactivity Wrapper)

### 🔍 Kỹ Thuật Là Gì?

Auto Logout là cơ chế tự động đăng xuất người dùng sau một khoảng thời gian không hoạt động để bảo vệ session.

### 💡 Tại Sao Quan Trọng?

1. **Session Security**: Ngăn người khác sử dụng app khi user rời đi
2. **Token Expiry**: Tự động clear tokens khi không dùng
3. **Privacy**: Bảo vệ thông tin tài chính khi device bị truy cập bất hợp pháp
4. **Compliance**: Tuân thủ các yêu cầu bảo mật ngành tài chính

### ⚙️ Cách Hoạt Động

1. Track tất cả user interactions (tap, scroll, pointer events)
2. Reset timer mỗi khi có interaction
3. Sau timeout period → Show warning dialog
4. Nếu user không phản hồi → Auto logout

### 📍 Áp Dụng Trong Dự Án

**File**: `mobile/lib/widgets/inactivity_wrapper.dart`

```dart
class InactivityWrapper extends StatefulWidget {
  final Widget child;
  final Duration timeout;
  
  const InactivityWrapper({
    this.timeout = const Duration(minutes: 10),  // 10 phút timeout
  });
}

class _InactivityWrapperState extends State<InactivityWrapper> {
  Timer? _inactivityTimer;
  
  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(widget.timeout, _onInactivityTimeout);
  }
  
  Future<void> _onInactivityTimeout() async {
    // Show warning dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hết Phiên Làm Việc'),
        content: Text('Bạn đã không hoạt động trong một thời gian...'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              _resetTimer();  // Reset nếu chọn tiếp tục
            },
            child: Text('Tiếp Tục Đăng Nhập'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Đăng Xuất'),
          ),
        ],
      ),
    );
    
    if (shouldLogout == true) {
      await context.read<AuthProvider>().logout();
      // Navigate to login
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _resetTimer,  // Reset timer khi tap
      onPanDown: (_) => _resetTimer(),  // Reset khi scroll
      child: Listener(
        onPointerDown: (_) => _resetTimer(),  // Track mọi interaction
        onPointerMove: (_) => _resetTimer(),
        onPointerUp: (_) => _resetTimer(),
        child: widget.child,
      ),
    );
  }
}
```

**Sử Dụng**:
```dart
// mobile/lib/screens/wallet/wallet_home_screen.dart
InactivityWrapper(  // Wrap toàn bộ wallet screen
  child: WalletHomeScreen(),
)
```

**Tính Năng**:
- ✅ Timeout: 10 phút
- ✅ Warning dialog trước khi logout
- ✅ User có thể chọn tiếp tục hoặc logout
- ✅ Track tất cả interactions (tap, scroll, pointer)
- ✅ Reset timer khi có activity

**Luồng Hoạt Động**:
1. User vào wallet screen
2. Timer bắt đầu (10 phút)
3. User tương tác → Reset timer
4. Sau 10 phút không activity → Show dialog
5. User chọn "Tiếp Tục" → Reset timer
6. User chọn "Đăng Xuất" → Logout và về login screen

---

## 13. Root/Jailbreak Detection

### 🔍 Kỹ Thuật Là Gì?

Root/Jailbreak Detection là kỹ thuật phát hiện thiết bị đã bị root (Android) hoặc jailbreak (iOS), có thể gây rủi ro bảo mật.

### 💡 Tại Sao Quan Trọng?

1. **Device Security**: Rooted/Jailbroken devices có rủi ro bảo mật cao hơn
2. **App Integrity**: Attacker có thể modify app behavior trên rooted device
3. **Data Protection**: Dữ liệu nhạy cảm có thể bị truy cập bởi malicious apps
4. **Compliance**: Nhiều ngân hàng/fintech apps yêu cầu không hỗ trợ rooted devices

### ⚙️ Cách Hoạt Động

**Android - Root Detection**:
- Check các file/system paths thường có khi root
- Check su binary
- Check các apps quản lý root (SuperSU, Magisk)
- Check build properties

**iOS - Jailbreak Detection**:
- Check các paths/file thường có khi jailbreak
- Check Cydia app
- Check file system permissions

### 📍 Áp Dụng Trong Dự Án

**File**: `mobile/lib/services/security_service.dart`

```dart
import 'package:root_detector/root_detector.dart';

class SecurityService {
  // Check device có bị compromise không
  Future<bool> isDeviceCompromised() async {
    try {
      if (Platform.isAndroid) {
        return await RootDetector.isRooted();  // Check root
      } else if (Platform.isIOS) {
        // iOS jailbreak detection (có thể mở rộng)
        return false;
      }
      return false;
    } catch (e) {
      return false;  // Fail open (cho phép nếu không check được)
    }
  }
  
  // Get security status
  Future<Map<String, dynamic>> getSecurityStatus() async {
    final isCompromised = await isDeviceCompromised();
    return {
      'isCompromised': isCompromised,
      'isSecure': !isCompromised,
      'platform': Platform.operatingSystem,
    };
  }
}
```

**Sử Dụng**:

**Security Check Screen** (`mobile/lib/screens/security/security_check_screen.dart`):
```dart
class SecurityCheckScreen extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    _checkSecurity();  // Check khi screen load
  }
  
  Future<void> _checkSecurity() async {
    final status = await _securityService.getSecurityStatus();
    
    if (status['isCompromised'] == true) {
      // Show warning
      setState(() => _isCompromised = true);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isCompromised) {
      return WarningScreen();  // Hiển thị cảnh báo
    }
    return widget.child;  // Cho phép tiếp tục
  }
}
```

**Main App** (`mobile/lib/main.dart`):
```dart
MaterialApp(
  home: SecurityCheckScreen(  // Wrap toàn bộ app
    child: SplashScreen(),
  ),
)
```

**Warning Screen**:
- Hiển thị cảnh báo về rủi ro bảo mật
- Cho phép user chọn "Tiếp Tục Dù Vậy" (accept risk)
- Hoặc "Quay Lại" (exit app)

**Package**: `root_detector`
- Hỗ trợ Android root detection
- Có thể mở rộng cho iOS jailbreak detection

**Best Practices**:
- ✅ Check khi app khởi động
- ✅ Show warning nhưng không block hoàn toàn
- ✅ Log security events
- ✅ Fail open (cho phép nếu không check được)

---

## 📊 Tổng Kết

### Các Kỹ Thuật Bảo Mật Đã Triển Khai

| Kỹ Thuật | Tầm Quan Trọng | Độ Phức Tạp | Trạng Thái |
|----------|----------------|-------------|------------|
| JWT Tokens | ⭐⭐⭐⭐⭐ | Trung bình | ✅ Hoàn chỉnh |
| Password Hashing (bcrypt) | ⭐⭐⭐⭐⭐ | Thấp | ✅ Hoàn chỉnh |
| OTP Verification | ⭐⭐⭐⭐⭐ | Trung bình | ✅ Hoàn chỉnh |
| Transaction PIN | ⭐⭐⭐⭐⭐ | Thấp | ✅ Hoàn chỉnh |
| AES Encryption | ⭐⭐⭐⭐⭐ | Trung bình | ✅ Hoàn chỉnh |
| Rate Limiting | ⭐⭐⭐⭐ | Thấp | ✅ Hoàn chỉnh |
| SQL Injection Protection | ⭐⭐⭐⭐⭐ | Thấp | ✅ Hoàn chỉnh |
| Input Validation | ⭐⭐⭐⭐ | Thấp | ✅ Hoàn chỉnh |
| Secure Storage | ⭐⭐⭐⭐⭐ | Thấp | ✅ Hoàn chỉnh |
| Auto Logout | ⭐⭐⭐⭐ | Trung bình | ✅ Hoàn chỉnh |
| Root Detection | ⭐⭐⭐ | Thấp | ✅ Hoàn chỉnh |
| Biometric Auth | ⭐⭐⭐⭐ | Trung bình | ✅ Hoàn chỉnh |

### Nguyên Tắc Bảo Mật Áp Dụng

1. **Defense in Depth**: Nhiều lớp bảo mật, không phụ thuộc vào một kỹ thuật
2. **Least Privilege**: User chỉ có quyền tối thiểu cần thiết
3. **Encryption at Rest**: Mã hóa dữ liệu nhạy cảm trong database
4. **Encryption in Transit**: HTTPS cho tất cả API calls
5. **Secure by Default**: Các cài đặt mặc định đều an toàn
6. **Fail Secure**: Khi có lỗi, hệ thống fail về trạng thái an toàn

---

*Tài liệu này giải thích chi tiết các kỹ thuật bảo mật được sử dụng trong E-Wallet App. Để hiểu sâu hơn, vui lòng tham khảo code trong các file được chỉ định.*

