# 💡 Secure Wallet App - Ví Điện Tử Mini

> Xây dựng ứng dụng Ví điện tử mini tích hợp cơ chế an toàn và bảo mật

---

## 🎯 Mục tiêu

- Cho phép người dùng **đăng ký / đăng nhập / xác thực 2 lớp**
- Cho phép **nạp tiền, chuyển tiền, xem lịch sử giao dịch**
- Bảo vệ dữ liệu người dùng và giao dịch bằng **mã hóa, JWT, HTTPS**
- Có hệ thống **backend FastAPI** quản lý người dùng, giao dịch, token

---

## ⚙️ Kiến trúc tổng thể

```
┌─────────────────┐     ┌─────────────────────┐     ┌────────────────────────────┐
│   Flutter App   │ ←→  │   FastAPI Backend   │ ←→  │  PostgreSQL / SQLite DB    │
└─────────────────┘     └─────────────────────┘     └────────────────────────────┘
         ↑                        ↓
   Secure Storage          JWT + OTP + AES
```

---

## 🔐 Các cơ chế bảo mật tích hợp

| Thành phần | Cơ chế bảo mật | Mô tả |
|------------|----------------|-------|
| Đăng nhập | JWT + Refresh Token | Tạo JWT ngắn hạn, refresh token lưu an toàn |
| Đăng ký | OTP Email / SMS | Xác minh danh tính người dùng |
| Giao dịch | Mã hóa AES-256 | Mã hóa thông tin giao dịch trước khi lưu DB |
| Backend API | HTTPS + Token | Bảo vệ chống MITM và request giả mạo |
| Lưu trữ local | Secure Storage / Keychain | Lưu token, key bí mật |
| Phát hiện gian lận | Rate limit + timestamp | Ngăn replay / spam yêu cầu nạp tiền |

---

## 🧩 Chức năng chính của hệ thống

### 1️⃣ Người dùng

- [x] Đăng ký / Đăng nhập
- [x] Xác minh OTP (qua email)
- [ ] Đổi mật khẩu

### 2️⃣ Ví điện tử

- [x] Xem số dư hiện tại
- [x] Nạp tiền (giả lập, ví dụ +100.000₫)
- [x] Chuyển tiền cho người khác (qua email hoặc ID)
- [x] Xem lịch sử giao dịch
- [ ] Giao diện biểu đồ giao dịch

### 3️⃣ Bảo mật

- [x] Mã hóa dữ liệu trước khi gửi lên server
- [x] OTP khi đăng nhập hoặc chuyển tiền
- [ ] Tự động đăng xuất sau thời gian không hoạt động
- [ ] Chống gửi lại giao dịch cũ (nonce/timestamp)

---

## 👥 Phân chia công việc nhóm (2–3 người)

| Vai trò | Thành viên | Công việc |
|---------|------------|-----------|
| Frontend Developer (Flutter) | 1 người | UI, logic đăng nhập, OTP, giao diện ví, chuyển tiền |
| Backend Developer (FastAPI) | 1 người | API REST, JWT auth, OTP email, mã hóa AES, DB |
| Security & Integration | 1 người | HTTPS setup, kiểm tra bảo mật API, encryption keys, test bảo mật |

---

## 🧱 Thiết kế cơ sở dữ liệu

### Bảng `users`

| Trường | Kiểu | Mô tả |
|--------|------|-------|
| id | UUID | Khóa chính |
| email | TEXT | Duy nhất |
| hashed_password | TEXT | Mã hóa bcrypt |
| balance | FLOAT | Số dư |
| otp_secret | TEXT | Key tạo mã OTP |
| is_verified | BOOLEAN | Trạng thái xác thực email |
| created_at | TIMESTAMP | Ngày tạo |

### Bảng `wallets`

| Trường | Kiểu | Mô tả |
|--------|------|-------|
| id | UUID | Khóa chính |
| user_id | UUID | FK → users.id |
| balance | FLOAT | Số dư ví |
| encrypted_balance | TEXT | Số dư mã hóa AES |
| created_at | TIMESTAMP | Ngày tạo |

### Bảng `transactions`

| Trường | Kiểu | Mô tả |
|--------|------|-------|
| id | UUID | Khóa chính |
| sender_id | UUID | Người gửi |
| receiver_id | UUID | Người nhận |
| amount | FLOAT | Số tiền |
| transaction_type | TEXT | DEPOSIT / WITHDRAW / TRANSFER |
| timestamp | TIMESTAMP | Thời gian |
| encrypted_note | TEXT | Ghi chú (mã hóa AES) |

---

## 🛠️ Công nghệ sử dụng

### Frontend (Flutter)

| Package | Mục đích |
|---------|----------|
| `flutter_secure_storage` | Lưu token an toàn |
| `http` / `dio` | Gọi API HTTPS |
| `local_auth` | Xác thực sinh trắc học |
| `provider` | Quản lý state |
| `charts_flutter` | Hiển thị biểu đồ giao dịch |

### Backend (FastAPI)

| Package | Mục đích |
|---------|----------|
| `fastapi` | Web framework |
| `pydantic` | Validation |
| `sqlalchemy` | ORM |
| `passlib[bcrypt]` | Mã hóa mật khẩu |
| `pyotp` | Tạo mã OTP 6 số |
| `cryptography` | Mã hóa AES |
| `python-jose` | JWT tokens |
| `slowapi` | Rate limiting |

---

## 🔎 Luồng hoạt động an toàn

```
1. User đăng ký
   └─→ Backend gửi mã OTP email

2. Xác minh OTP
   └─→ Tạo tài khoản, sinh cặp JWT và refresh token

3. Khi chuyển tiền:
   ├─→ App gửi yêu cầu + timestamp
   ├─→ Backend kiểm tra token hợp lệ và thời gian hợp lệ
   └─→ Dữ liệu giao dịch (ghi chú) được mã hóa AES trước khi lưu

4. Sau 10 phút không hoạt động
   └─→ Auto logout
```

### Sequence Diagram - Đăng ký

```
┌────────┐          ┌─────────┐          ┌──────────┐
│  App   │          │ Backend │          │  Email   │
└───┬────┘          └────┬────┘          └────┬─────┘
    │                    │                    │
    │  POST /register    │                    │
    │───────────────────>│                    │
    │                    │   Send OTP Email   │
    │                    │───────────────────>│
    │                    │                    │
    │  201 Created       │                    │
    │<───────────────────│                    │
    │                    │                    │
    │  POST /verify-otp  │                    │
    │───────────────────>│                    │
    │                    │                    │
    │  200 OK (Verified) │                    │
    │<───────────────────│                    │
    │                    │                    │
```

---

## 🧠 Phần nâng cao (điểm cộng đồ án)

| Tính năng | Trạng thái | Mô tả |
|-----------|------------|-------|
| 🪪 FaceID / Vân tay | ✅ Hoàn thành | Tích hợp khi mở app |
| 🔏 QR Code chuyển tiền | ✅ Hoàn thành | Generate & Scan QR code |
| 🌐 Pin certificate HTTPS | ⬜ Chưa làm | Chống MITM attack |
| 🧬 Phát hiện root/jailbreak | ⬜ Chưa làm | Bảo vệ trên thiết bị đã root |
| 📊 Biểu đồ giao dịch | ✅ Hoàn thành | Pie chart & Bar chart |
| ⏰ Auto logout | ✅ Hoàn thành | Tự động đăng xuất sau 10 phút |

---

## 📁 Cấu trúc dự án

```
e-wallet/
├── mobile/                 # Flutter App
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   │   ├── auth/
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── register_screen.dart
│   │   │   │   └── otp_verification_screen.dart
│   │   │   ├── wallet/
│   │   │   │   ├── wallet_home_screen.dart
│   │   │   │   ├── deposit_screen.dart
│   │   │   │   ├── withdraw_screen.dart
│   │   │   │   └── transfer_screen.dart
│   │   │   └── splash_screen.dart
│   │   ├── services/
│   │   └── utils/
│   └── pubspec.yaml
│
├── backend/                # FastAPI Backend
│   ├── app/
│   │   ├── main.py
│   │   ├── api/v1/
│   │   ├── core/
│   │   │   ├── config.py
│   │   │   ├── database.py
│   │   │   ├── security.py
│   │   │   └── encryption.py
│   │   ├── models/
│   │   ├── schemas/
│   │   └── services/
│   ├── alembic/
│   ├── requirements.txt
│   └── .env
│
└── REQUIREMENTS.md         # This file
```

---

## 🚀 Hướng dẫn chạy dự án

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Setup database
alembic upgrade head

# Run server
uvicorn app.main:app --reload
```

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

---

## 📝 API Endpoints

### Authentication

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| POST | `/api/v1/auth/register` | Đăng ký tài khoản |
| POST | `/api/v1/auth/login` | Đăng nhập |
| POST | `/api/v1/auth/verify-otp` | Xác thực OTP |
| POST | `/api/v1/auth/resend-otp` | Gửi lại OTP |

### Wallet

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| GET | `/api/v1/wallets/me` | Xem thông tin ví |
| POST | `/api/v1/wallets/deposit` | Nạp tiền |
| POST | `/api/v1/wallets/withdraw` | Rút tiền |
| POST | `/api/v1/wallets/transfer` | Chuyển tiền |
| GET | `/api/v1/wallets/transactions` | Lịch sử giao dịch |

---

## ✅ Checklist hoàn thành

- [x] Đăng ký / Đăng nhập
- [x] Xác thực OTP qua email
- [x] Gửi lại OTP
- [x] JWT + Refresh Token
- [x] Nạp tiền
- [x] Rút tiền
- [x] Chuyển tiền
- [x] Xem lịch sử giao dịch
- [x] Mã hóa AES cho giao dịch
- [x] Rate limiting
- [x] Remember session
- [ ] Đổi mật khẩu
- [ ] Auto logout sau 10 phút
- [ ] Biểu đồ giao dịch
- [ ] FaceID / Vân tay
- [ ] QR Code chuyển tiền

---

*Last updated: December 2024*

