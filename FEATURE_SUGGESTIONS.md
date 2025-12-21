# 💡 Đề Xuất Tính Năng Bổ Sung Cho E-Wallet App

> Tham khảo các ví điện tử phổ biến (MoMo, ZaloPay, PayPal, Venmo) và đề xuất tính năng mới

---

## 📊 Tổng Quan Tính Năng Hiện Tại

### ✅ Đã Có
- ✅ Đăng ký/Đăng nhập với OTP email
- ✅ Nạp tiền/Rút tiền/Chuyển tiền
- ✅ Lịch sử giao dịch
- ✅ Transaction PIN
- ✅ Xác thực sinh trắc học (FaceID/Fingerprint)
- ✅ QR Code chuyển tiền
- ✅ Biểu đồ giao dịch
- ✅ Đổi mật khẩu
- ✅ Auto logout sau 10 phút
- ✅ Bảo mật: Certificate pinning, Root detection

---

## 🚀 Đề Xuất Tính Năng Mới

### 🎯 **Nhóm 1: Quản Lý Danh Bạ & Thanh Toán Nhanh** (Priority: 🔴 High)

#### 1.1 Danh Bạ Người Nhận (Contact List)
**Mô tả:** Lưu danh sách người nhận thường xuyên để chuyển tiền nhanh

**Tính năng:**
- Thêm/xóa/sửa danh bạ người nhận
- Tìm kiếm theo tên, email, số điện thoại
- Hiển thị avatar (initials hoặc icon)
- Lịch sử giao dịch với từng người nhận
- Tổng số tiền đã chuyển cho mỗi người

**Backend API:**
```
POST   /api/v1/contacts              # Thêm danh bạ
GET    /api/v1/contacts              # Lấy danh sách
GET    /api/v1/contacts/{id}         # Chi tiết
PUT    /api/v1/contacts/{id}         # Cập nhật
DELETE /api/v1/contacts/{id}         # Xóa
GET    /api/v1/contacts/{id}/stats   # Thống kê giao dịch
```

**Database:**
```sql
CREATE TABLE contacts (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(20),
    avatar_url TEXT,
    notes TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

---

#### 1.2 Thanh Toán Nhanh (Quick Pay)
**Mô tả:** Chuyển tiền nhanh từ danh bạ hoặc số tiền đã lưu

**Tính năng:**
- Widget chuyển tiền nhanh trên home screen
- Lưu các mức tiền thường dùng (50k, 100k, 200k, 500k)
- Chuyển tiền 1 chạm từ danh bạ
- Lịch sử thanh toán nhanh

**UI Flow:**
```
Home Screen → Quick Pay Button → Select Contact → Select Amount → Confirm → Done
```

---

### 💳 **Nhóm 2: Liên Kết Ngân Hàng & Thẻ** (Priority: 🔴 High)

#### 2.1 Liên Kết Thẻ Ngân Hàng
**Mô tả:** Liên kết thẻ ATM/Visa/Mastercard để nạp/rút tiền thực tế

**Tính năng:**
- Thêm thẻ ngân hàng (số thẻ, tên chủ thẻ, ngày hết hạn, CVV)
- Mã hóa thông tin thẻ (AES-256)
- Xác thực thẻ qua OTP SMS
- Danh sách thẻ đã liên kết
- Xóa thẻ (cần xác thực PIN)

**Backend API:**
```
POST   /api/v1/cards                 # Thêm thẻ
GET    /api/v1/cards                 # Danh sách thẻ
DELETE /api/v1/cards/{id}            # Xóa thẻ
POST   /api/v1/cards/{id}/verify     # Xác thực thẻ
```

**Database:**
```sql
CREATE TABLE bank_cards (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    card_number_encrypted TEXT,      # Mã hóa AES
    card_holder_name VARCHAR(255),
    expiry_date_encrypted TEXT,
    cvv_encrypted TEXT,
    bank_name VARCHAR(100),
    card_type VARCHAR(20),            # VISA, MASTERCARD, ATM
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP
);
```

---

#### 2.2 Nạp Tiền Từ Thẻ
**Mô tả:** Nạp tiền vào ví từ thẻ ngân hàng đã liên kết

**Tính năng:**
- Chọn thẻ ngân hàng
- Nhập số tiền
- Xác thực bằng PIN/OTP
- Phí giao dịch (nếu có)
- Thời gian xử lý: Tức thời hoặc 1-2 ngày

**Backend API:**
```
POST /api/v1/wallets/deposit-from-card
Body: {
    "card_id": "uuid",
    "amount": 1000000,
    "transaction_pin": "1234"
}
```

---

#### 2.3 Rút Tiền Về Thẻ
**Mô tả:** Rút tiền từ ví về thẻ ngân hàng

**Tính năng:**
- Chọn thẻ ngân hàng
- Nhập số tiền
- Phí rút tiền
- Thời gian xử lý: 1-3 ngày làm việc
- Lịch sử rút tiền

**Backend API:**
```
POST /api/v1/wallets/withdraw-to-card
Body: {
    "card_id": "uuid",
    "amount": 500000,
    "transaction_pin": "1234"
}
```

---

### 📱 **Nhóm 3: Thanh Toán Hóa Đơn & Dịch Vụ** (Priority: 🟡 Medium)

#### 3.1 Thanh Toán Hóa Đơn
**Mô tả:** Thanh toán các loại hóa đơn (điện, nước, internet, cước điện thoại)

**Tính năng:**
- Danh sách nhà cung cấp dịch vụ
- Nhập mã khách hàng/số hợp đồng
- Xem hóa đơn chưa thanh toán
- Thanh toán hóa đơn
- Lưu thông tin thanh toán để thanh toán lại
- Lịch sử thanh toán hóa đơn

**Backend API:**
```
GET    /api/v1/bills/providers       # Danh sách nhà cung cấp
POST   /api/v1/bills/check           # Kiểm tra hóa đơn
POST   /api/v1/bills/pay             # Thanh toán
GET    /api/v1/bills/history         # Lịch sử
```

**Database:**
```sql
CREATE TABLE bill_providers (
    id UUID PRIMARY KEY,
    name VARCHAR(255),                # EVN, SAVACO, FPT, Viettel...
    code VARCHAR(50),
    logo_url TEXT,
    is_active BOOLEAN
);

CREATE TABLE saved_bills (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    provider_id UUID REFERENCES bill_providers(id),
    customer_code VARCHAR(100),
    customer_name VARCHAR(255),
    alias VARCHAR(100),               # Tên gợi nhớ
    created_at TIMESTAMP
);

CREATE TABLE bill_transactions (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    provider_id UUID REFERENCES bill_providers(id),
    customer_code VARCHAR(100),
    amount DECIMAL(15,2),
    bill_period VARCHAR(20),          # Tháng/Năm
    transaction_id UUID REFERENCES transactions(id),
    created_at TIMESTAMP
);
```

---

#### 3.2 Nạp Tiền Điện Thoại
**Mô tả:** Nạp tiền điện thoại trả trước/trả sau

**Tính năng:**
- Chọn nhà mạng (Viettel, VinaPhone, Mobifone, Vietnamobile)
- Nhập số điện thoại
- Chọn mệnh giá (10k, 20k, 50k, 100k, 200k, 500k)
- Nạp tiền tức thời
- Lưu số điện thoại thường nạp

**Backend API:**
```
POST /api/v1/topup/mobile
Body: {
    "phone_number": "0912345678",
    "amount": 50000,
    "carrier": "VIETTEL"
}
```

---

#### 3.3 Mua Thẻ Cào
**Mô tả:** Mua thẻ cào điện thoại, game, internet

**Tính năng:**
- Chọn loại thẻ (điện thoại, game, internet)
- Chọn nhà cung cấp
- Chọn mệnh giá
- Nhận mã thẻ cào ngay sau khi thanh toán
- Lưu lịch sử mua thẻ

**Backend API:**
```
POST /api/v1/cards/purchase
Body: {
    "card_type": "MOBILE",            # MOBILE, GAME, INTERNET
    "provider": "VIETTEL",
    "denomination": 50000,
    "quantity": 1
}
```

---

### 🎁 **Nhóm 4: Khuyến Mãi & Thưởng** (Priority: 🟢 Low)

#### 4.1 Mã Khuyến Mãi (Promo Codes)
**Mô tả:** Nhập mã khuyến mãi để nhận tiền thưởng/giảm giá

**Tính năng:**
- Nhập mã khuyến mãi
- Kiểm tra mã hợp lệ
- Áp dụng mã (tiền thưởng vào ví hoặc giảm giá giao dịch)
- Lịch sử sử dụng mã
- Thông báo mã mới

**Backend API:**
```
POST /api/v1/promos/apply
Body: {
    "promo_code": "WELCOME2024"
}

GET /api/v1/promos/my-promos        # Mã đã sử dụng
```

**Database:**
```sql
CREATE TABLE promo_codes (
    id UUID PRIMARY KEY,
    code VARCHAR(50) UNIQUE,
    description TEXT,
    discount_type VARCHAR(20),       # PERCENTAGE, FIXED_AMOUNT, BONUS
    discount_value DECIMAL(15,2),
    min_amount DECIMAL(15,2),        # Số tiền tối thiểu
    max_discount DECIMAL(15,2),      # Giảm tối đa
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    usage_limit INTEGER,             # Số lần sử dụng tối đa
    used_count INTEGER DEFAULT 0,
    is_active BOOLEAN
);

CREATE TABLE user_promo_usage (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    promo_id UUID REFERENCES promo_codes(id),
    transaction_id UUID REFERENCES transactions(id),
    discount_amount DECIMAL(15,2),
    used_at TIMESTAMP
);
```

---

#### 4.2 Chương Trình Hoàn Tiền (Cashback)
**Mô tả:** Nhận hoàn tiền khi thanh toán hoặc chuyển tiền

**Tính năng:**
- Tỷ lệ hoàn tiền theo loại giao dịch
- Lịch sử hoàn tiền
- Số tiền hoàn tiền đang chờ
- Rút hoàn tiền về ví

**Backend API:**
```
GET /api/v1/cashback/balance        # Số dư hoàn tiền
GET /api/v1/cashback/history        # Lịch sử
POST /api/v1/cashback/withdraw      # Rút hoàn tiền
```

---

#### 4.3 Điểm Thưởng (Loyalty Points)
**Mô tả:** Tích điểm khi sử dụng dịch vụ, đổi điểm lấy tiền hoặc quà

**Tính năng:**
- Tích điểm theo giao dịch
- Xem số điểm hiện tại
- Đổi điểm lấy tiền (ví dụ: 100 điểm = 1.000₫)
- Đổi điểm lấy voucher/quà tặng
- Lịch sử tích điểm và đổi điểm

**Backend API:**
```
GET /api/v1/loyalty/points          # Số điểm hiện tại
GET /api/v1/loyalty/history         # Lịch sử
POST /api/v1/loyalty/redeem         # Đổi điểm
```

---

### 📊 **Nhóm 5: Báo Cáo & Phân Tích** (Priority: 🟡 Medium)

#### 5.1 Báo Cáo Chi Tiêu
**Mô tả:** Phân tích chi tiêu theo thời gian, danh mục, người nhận

**Tính năng:**
- Biểu đồ chi tiêu theo ngày/tuần/tháng/năm
- Phân loại chi tiêu (ăn uống, mua sắm, hóa đơn, chuyển tiền...)
- So sánh chi tiêu giữa các kỳ
- Dự báo chi tiêu
- Xuất báo cáo PDF

**Backend API:**
```
GET /api/v1/analytics/spending?period=month&year=2024
GET /api/v1/analytics/categories?period=month
GET /api/v1/analytics/trends?period=year
GET /api/v1/analytics/export?format=pdf
```

---

#### 5.2 Ngân Sách (Budget)
**Mô tả:** Đặt ngân sách chi tiêu và theo dõi

**Tính năng:**
- Tạo ngân sách theo tháng
- Phân loại ngân sách theo danh mục
- Cảnh báo khi gần hết ngân sách
- Thống kê thực tế vs ngân sách

**Backend API:**
```
POST /api/v1/budgets                # Tạo ngân sách
GET  /api/v1/budgets                # Danh sách
GET  /api/v1/budgets/{id}/status    # Trạng thái
PUT  /api/v1/budgets/{id}           # Cập nhật
```

**Database:**
```sql
CREATE TABLE budgets (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    category VARCHAR(100),
    amount DECIMAL(15,2),
    period VARCHAR(20),              # MONTH, YEAR
    month INTEGER,
    year INTEGER,
    created_at TIMESTAMP
);
```

---

#### 5.3 Mục Tiêu Tiết Kiệm (Savings Goals)
**Mô tả:** Đặt mục tiêu tiết kiệm và theo dõi tiến độ

**Tính năng:**
- Tạo mục tiêu tiết kiệm (ví dụ: 10 triệu trong 6 tháng)
- Tự động trích tiền vào mục tiêu
- Theo dõi tiến độ (% hoàn thành)
- Thông báo khi đạt mục tiêu
- Rút tiền từ mục tiêu (nếu cần)

**Backend API:**
```
POST /api/v1/savings/goals          # Tạo mục tiêu
GET  /api/v1/savings/goals          # Danh sách
POST /api/v1/savings/deposit        # Nạp vào mục tiêu
POST /api/v1/savings/withdraw       # Rút từ mục tiêu
```

**Database:**
```sql
CREATE TABLE savings_goals (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    name VARCHAR(255),
    target_amount DECIMAL(15,2),
    current_amount DECIMAL(15,2) DEFAULT 0,
    deadline DATE,
    auto_deposit_amount DECIMAL(15,2),  # Tự động trích mỗi tháng
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP
);
```

---

### 🔔 **Nhóm 6: Thông Báo & Cảnh Báo** (Priority: 🟡 Medium)

#### 6.1 Thông Báo Đẩy (Push Notifications)
**Mô tả:** Thông báo về giao dịch, khuyến mãi, bảo mật

**Tính năng:**
- Thông báo khi nhận tiền
- Thông báo khi chuyển tiền thành công
- Thông báo khuyến mãi mới
- Thông báo bảo mật (đăng nhập mới, đổi mật khẩu)
- Cài đặt loại thông báo muốn nhận

**Backend API:**
```
POST /api/v1/notifications/register  # Đăng ký device token
GET  /api/v1/notifications           # Lịch sử thông báo
PUT  /api/v1/notifications/settings  # Cài đặt
```

---

#### 6.2 Cảnh Báo Giao Dịch
**Mô tả:** Cảnh báo khi có giao dịch lớn hoặc bất thường

**Tính năng:**
- Cảnh báo giao dịch lớn (vượt ngưỡng)
- Cảnh báo đăng nhập từ thiết bị mới
- Cảnh báo số dư thấp
- Cảnh báo ngân sách sắp hết

**Backend API:**
```
POST /api/v1/alerts/settings        # Cài đặt cảnh báo
GET  /api/v1/alerts                 # Danh sách cảnh báo
```

---

### 🔐 **Nhóm 7: Bảo Mật Nâng Cao** (Priority: 🔴 High)

#### 7.1 Xác Thực 2 Lớp (2FA)
**Mô tả:** Bật/tắt xác thực 2 lớp bằng ứng dụng Authenticator

**Tính năng:**
- Tích hợp Google Authenticator / Authy
- QR code để quét và thêm vào app
- Backup codes để khôi phục
- Yêu cầu mã 2FA khi đăng nhập

**Backend API:**
```
POST /api/v1/auth/2fa/enable        # Bật 2FA
POST /api/v1/auth/2fa/disable       # Tắt 2FA
POST /api/v1/auth/2fa/verify        # Xác thực mã
GET  /api/v1/auth/2fa/backup-codes  # Lấy backup codes
```

---

#### 7.2 Quản Lý Thiết Bị
**Mô tả:** Xem và quản lý các thiết bị đã đăng nhập

**Tính năng:**
- Danh sách thiết bị đã đăng nhập
- Thông tin thiết bị (tên, OS, IP, thời gian đăng nhập)
- Đăng xuất từ xa
- Cảnh báo thiết bị mới

**Backend API:**
```
GET    /api/v1/devices              # Danh sách thiết bị
DELETE /api/v1/devices/{id}         # Đăng xuất thiết bị
POST   /api/v1/devices/{id}/rename  # Đổi tên thiết bị
```

**Database:**
```sql
CREATE TABLE user_devices (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    device_token VARCHAR(255),
    device_name VARCHAR(255),
    device_type VARCHAR(50),         # IOS, ANDROID, WEB
    ip_address VARCHAR(45),
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);
```

---

#### 7.3 Lịch Sử Bảo Mật
**Mô tả:** Xem lịch sử các hoạt động bảo mật

**Tính năng:**
- Lịch sử đăng nhập
- Lịch sử đổi mật khẩu
- Lịch sử đổi PIN
- Lịch sử bật/tắt 2FA
- Lịch sử thay đổi cài đặt bảo mật

**Backend API:**
```
GET /api/v1/security/history
```

---

### 💬 **Nhóm 8: Hỗ Trợ & Trợ Giúp** (Priority: 🟢 Low)

#### 8.1 Trung Tâm Trợ Giúp (Help Center)
**Mô tả:** FAQ và hướng dẫn sử dụng

**Tính năng:**
- Danh sách câu hỏi thường gặp
- Tìm kiếm câu hỏi
- Hướng dẫn từng bước
- Video hướng dẫn

---

#### 8.2 Liên Hệ Hỗ Trợ
**Mô tả:** Chat hoặc gửi yêu cầu hỗ trợ

**Tính năng:**
- Chat trực tuyến với CSKH
- Gửi ticket hỗ trợ
- Theo dõi trạng thái ticket
- Lịch sử hỗ trợ

**Backend API:**
```
POST /api/v1/support/tickets        # Tạo ticket
GET  /api/v1/support/tickets        # Danh sách ticket
GET  /api/v1/support/tickets/{id}   # Chi tiết
POST /api/v1/support/tickets/{id}/messages  # Gửi tin nhắn
```

---

#### 8.3 Báo Cáo Sự Cố
**Mô tả:** Báo cáo lỗi hoặc giao dịch bất thường

**Tính năng:**
- Form báo cáo sự cố
- Đính kèm ảnh chụp màn hình
- Ưu tiên xử lý (cao/trung bình/thấp)
- Theo dõi trạng thái xử lý

---

### 🎨 **Nhóm 9: Tùy Chỉnh & Cá Nhân Hóa** (Priority: 🟢 Low)

#### 9.1 Hồ Sơ Người Dùng
**Mô tả:** Quản lý thông tin cá nhân

**Tính năng:**
- Xem/sửa thông tin cá nhân
- Upload avatar
- Thay đổi email (cần xác thực)
- Thay đổi số điện thoại
- Xác thực danh tính (KYC) - tùy chọn

**Backend API:**
```
GET  /api/v1/users/profile          # Xem hồ sơ
PUT  /api/v1/users/profile          # Cập nhật
POST /api/v1/users/avatar           # Upload avatar
POST /api/v1/users/verify-identity  # Xác thực danh tính
```

---

#### 9.2 Cài Đặt Giao Diện
**Mô tả:** Tùy chỉnh giao diện app

**Tính năng:**
- Chọn theme (sáng/tối/tự động)
- Chọn ngôn ngữ (Tiếng Việt/Tiếng Anh)
- Chọn đơn vị tiền tệ hiển thị
- Ẩn/hiện số dư
- Cài đặt màn hình khóa

---

#### 9.3 Widget & Shortcuts
**Mô tả:** Widget cho màn hình chính và shortcuts

**Tính năng:**
- Widget hiển thị số dư (Android/iOS)
- Shortcut chuyển tiền nhanh
- Shortcut quét QR
- Shortcut nạp tiền

---

### 📅 **Nhóm 10: Giao Dịch Định Kỳ & Lịch** (Priority: 🟡 Medium)

#### 10.1 Chuyển Tiền Định Kỳ
**Mô tả:** Lên lịch chuyển tiền tự động

**Tính năng:**
- Tạo lịch chuyển tiền (hàng tuần/tháng)
- Chọn người nhận
- Chọn số tiền
- Chọn ngày chuyển
- Bật/tắt lịch
- Lịch sử chuyển tiền định kỳ

**Backend API:**
```
POST /api/v1/scheduled-transfers    # Tạo lịch
GET  /api/v1/scheduled-transfers    # Danh sách
PUT  /api/v1/scheduled-transfers/{id}  # Cập nhật
DELETE /api/v1/scheduled-transfers/{id}  # Xóa
```

**Database:**
```sql
CREATE TABLE scheduled_transfers (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    receiver_email VARCHAR(255),
    amount DECIMAL(15,2),
    frequency VARCHAR(20),           # WEEKLY, MONTHLY
    day_of_week INTEGER,             # 1-7 (Monday-Sunday)
    day_of_month INTEGER,            # 1-31
    next_transfer_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP
);
```

---

#### 10.2 Nhắc Nhở Thanh Toán
**Mô tả:** Nhắc nhở thanh toán hóa đơn định kỳ

**Tính năng:**
- Tạo nhắc nhở thanh toán
- Chọn loại hóa đơn
- Chọn ngày nhắc nhở
- Tự động thanh toán (nếu có đủ tiền)

---

### 🌍 **Nhóm 11: Đa Tiền Tệ** (Priority: 🟢 Low)

#### 11.1 Quản Lý Nhiều Ví
**Mô tả:** Tạo và quản lý nhiều ví với các loại tiền tệ khác nhau

**Tính năng:**
- Tạo ví mới (VND, USD, EUR...)
- Chuyển đổi giữa các ví
- Tỷ giá chuyển đổi real-time
- Lịch sử chuyển đổi

**Backend API:**
```
POST /api/v1/wallets                # Tạo ví mới
GET  /api/v1/wallets                # Danh sách ví
POST /api/v1/wallets/convert        # Chuyển đổi tiền tệ
GET  /api/v1/exchange-rates         # Tỷ giá
```

---

### 💰 **Nhóm 12: Tính Năng Xã Hội & Chia Sẻ** (Priority: 🟡 Medium)

#### 12.1 Chia Hóa Đơn (Bill Splitting)
**Mô tả:** Chia hóa đơn ăn uống, mua sắm với bạn bè

**Tính năng:**
- Tạo hóa đơn chia sẻ
- Thêm nhiều người tham gia
- Chia đều hoặc chia theo phần
- Gửi yêu cầu thanh toán
- Theo dõi ai đã trả, ai chưa trả
- Nhắc nhở tự động

**Backend API:**
```
POST /api/v1/bills/split              # Tạo hóa đơn chia
GET  /api/v1/bills/split              # Danh sách hóa đơn
POST /api/v1/bills/split/{id}/pay     # Thanh toán phần của mình
GET  /api/v1/bills/split/{id}         # Chi tiết hóa đơn
```

**Database:**
```sql
CREATE TABLE split_bills (
    id UUID PRIMARY KEY,
    creator_id UUID REFERENCES users(id),
    title VARCHAR(255),
    total_amount DECIMAL(15,2),
    description TEXT,
    created_at TIMESTAMP
);

CREATE TABLE split_bill_participants (
    id UUID PRIMARY KEY,
    bill_id UUID REFERENCES split_bills(id),
    user_id UUID REFERENCES users(id),
    amount DECIMAL(15,2),
    is_paid BOOLEAN DEFAULT FALSE,
    paid_at TIMESTAMP
);
```

---

#### 12.2 Yêu Cầu Thanh Toán (Request Money)
**Mô tả:** Gửi yêu cầu thanh toán cho người khác

**Tính năng:**
- Tạo yêu cầu thanh toán
- Gửi link/QR code cho người nhận
- Người nhận có thể chấp nhận/từ chối
- Nhắc nhở tự động
- Lịch sử yêu cầu

**Backend API:**
```
POST /api/v1/requests                 # Tạo yêu cầu
GET  /api/v1/requests/received        # Yêu cầu nhận được
GET  /api/v1/requests/sent            # Yêu cầu đã gửi
POST /api/v1/requests/{id}/accept     # Chấp nhận
POST /api/v1/requests/{id}/reject     # Từ chối
```

---

#### 12.3 Quyên Góp & Từ Thiện
**Mô tả:** Quyên góp cho các tổ chức từ thiện

**Tính năng:**
- Danh sách tổ chức từ thiện
- Quyên góp một lần hoặc định kỳ
- Xem tổng số tiền đã quyên góp
- Giấy chứng nhận quyên góp
- Lịch sử quyên góp

**Backend API:**
```
GET  /api/v1/charities                # Danh sách tổ chức
POST /api/v1/charities/{id}/donate    # Quyên góp
GET  /api/v1/donations                # Lịch sử quyên góp
```

---

### 🏪 **Nhóm 13: Thanh Toán Tại Cửa Hàng** (Priority: 🟡 Medium)

#### 13.1 Thanh Toán QR Tại Cửa Hàng
**Mô tả:** Quét QR code tại cửa hàng để thanh toán

**Tính năng:**
- Quét QR code của cửa hàng
- Xem thông tin cửa hàng
- Nhập số tiền hoặc chọn hóa đơn
- Xác nhận thanh toán
- Nhận hóa đơn điện tử
- Lưu lịch sử mua hàng

**Backend API:**
```
POST /api/v1/merchants/scan           # Quét QR cửa hàng
GET  /api/v1/merchants/{id}           # Thông tin cửa hàng
POST /api/v1/merchants/{id}/pay       # Thanh toán
GET  /api/v1/merchants/payments       # Lịch sử thanh toán
```

**Database:**
```sql
CREATE TABLE merchants (
    id UUID PRIMARY KEY,
    name VARCHAR(255),
    qr_code TEXT,
    category VARCHAR(100),            # RESTAURANT, RETAIL, SERVICE...
    address TEXT,
    phone VARCHAR(20),
    is_active BOOLEAN
);

CREATE TABLE merchant_payments (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    merchant_id UUID REFERENCES merchants(id),
    amount DECIMAL(15,2),
    transaction_id UUID REFERENCES transactions(id),
    receipt_url TEXT,
    created_at TIMESTAMP
);
```

---

#### 13.2 Thanh Toán NFC (Near Field Communication)
**Mô tả:** Thanh toán bằng cách chạm điện thoại vào máy POS

**Tính năng:**
- Bật/tắt thanh toán NFC
- Chạm để thanh toán
- Xác thực bằng PIN/biometric
- Giới hạn số tiền thanh toán NFC
- Lịch sử thanh toán NFC

**Backend API:**
```
POST /api/v1/payments/nfc             # Thanh toán NFC
GET  /api/v1/payments/nfc/settings    # Cài đặt NFC
PUT  /api/v1/payments/nfc/settings    # Cập nhật cài đặt
```

---

### 🏦 **Nhóm 14: Tích Lũy & Đầu Tư** (Priority: 🟢 Low)

#### 14.1 Tiết Kiệm Có Lãi
**Mô tả:** Gửi tiền tiết kiệm và nhận lãi suất

**Tính năng:**
- Gửi tiền tiết kiệm
- Chọn kỳ hạn (1 tháng, 3 tháng, 6 tháng, 12 tháng)
- Xem lãi suất
- Tính toán lãi dự kiến
- Rút tiền trước hạn (mất lãi)
- Lịch sử tiết kiệm

**Backend API:**
```
POST /api/v1/savings/deposit          # Gửi tiết kiệm
GET  /api/v1/savings/accounts         # Danh sách sổ tiết kiệm
GET  /api/v1/savings/rates            # Lãi suất
POST /api/v1/savings/{id}/withdraw    # Rút tiền
GET  /api/v1/savings/{id}/interest    # Tính lãi
```

**Database:**
```sql
CREATE TABLE savings_accounts (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    amount DECIMAL(15,2),
    interest_rate DECIMAL(5,2),       # Lãi suất %
    term_months INTEGER,              # Kỳ hạn (tháng)
    start_date DATE,
    maturity_date DATE,
    interest_earned DECIMAL(15,2) DEFAULT 0,
    status VARCHAR(20),               # ACTIVE, MATURED, WITHDRAWN
    created_at TIMESTAMP
);
```

---

#### 14.2 Đầu Tư Quỹ (Investment Funds)
**Mô tả:** Đầu tư vào các quỹ đầu tư

**Tính năng:**
- Xem danh sách quỹ đầu tư
- Xem hiệu suất quỹ
- Mua/bán chứng chỉ quỹ
- Theo dõi danh mục đầu tư
- Lịch sử giao dịch

**Backend API:**
```
GET  /api/v1/funds                    # Danh sách quỹ
GET  /api/v1/funds/{id}               # Chi tiết quỹ
POST /api/v1/funds/{id}/buy           # Mua quỹ
POST /api/v1/funds/{id}/sell          # Bán quỹ
GET  /api/v1/portfolio                # Danh mục đầu tư
```

---

### 👨‍👩‍👧‍👦 **Nhóm 15: Ví Gia Đình & Ví Con** (Priority: 🟢 Low)

#### 15.1 Ví Con (Sub-Wallets)
**Mô tả:** Tạo ví con cho các mục đích khác nhau

**Tính năng:**
- Tạo ví con (ví dụ: ví ăn uống, ví mua sắm, ví tiết kiệm)
- Chuyển tiền giữa các ví
- Đặt ngân sách cho từng ví
- Theo dõi chi tiêu từng ví
- Xóa ví con

**Backend API:**
```
POST /api/v1/sub-wallets              # Tạo ví con
GET  /api/v1/sub-wallets              # Danh sách
POST /api/v1/sub-wallets/{id}/transfer  # Chuyển tiền
DELETE /api/v1/sub-wallets/{id}       # Xóa ví
```

**Database:**
```sql
CREATE TABLE sub_wallets (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    name VARCHAR(255),
    balance DECIMAL(15,2) DEFAULT 0,
    category VARCHAR(100),
    budget DECIMAL(15,2),
    color VARCHAR(7),                 # Màu hiển thị
    icon VARCHAR(50),                 # Icon
    created_at TIMESTAMP
);
```

---

#### 15.2 Ví Gia Đình (Family Wallet)
**Mô tả:** Quản lý ví chung cho gia đình

**Tính năng:**
- Tạo ví gia đình
- Mời thành viên gia đình
- Phân quyền (chủ ví, thành viên)
- Giới hạn chi tiêu cho từng thành viên
- Lịch sử giao dịch gia đình
- Thống kê chi tiêu gia đình

**Backend API:**
```
POST /api/v1/family-wallets           # Tạo ví gia đình
GET  /api/v1/family-wallets           # Danh sách ví gia đình
POST /api/v1/family-wallets/{id}/invite  # Mời thành viên
GET  /api/v1/family-wallets/{id}/members  # Danh sách thành viên
POST /api/v1/family-wallets/{id}/set-limit  # Đặt giới hạn
```

**Database:**
```sql
CREATE TABLE family_wallets (
    id UUID PRIMARY KEY,
    owner_id UUID REFERENCES users(id),
    name VARCHAR(255),
    balance DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP
);

CREATE TABLE family_wallet_members (
    id UUID PRIMARY KEY,
    wallet_id UUID REFERENCES family_wallets(id),
    user_id UUID REFERENCES users(id),
    role VARCHAR(20),                 # OWNER, MEMBER
    spending_limit DECIMAL(15,2),
    joined_at TIMESTAMP
);
```

---

### 🎫 **Nhóm 16: Voucher & Coupon** (Priority: 🟢 Low)

#### 16.1 Quản Lý Voucher
**Mô tả:** Lưu trữ và sử dụng voucher, coupon

**Tính năng:**
- Lưu voucher từ các đối tác
- Quét QR code để lưu voucher
- Xem danh sách voucher
- Lọc theo loại, trạng thái
- Nhắc nhở voucher sắp hết hạn
- Sử dụng voucher khi thanh toán

**Backend API:**
```
POST /api/v1/vouchers                 # Thêm voucher
GET  /api/v1/vouchers                 # Danh sách
GET  /api/v1/vouchers/{id}            # Chi tiết
POST /api/v1/vouchers/{id}/use        # Sử dụng
DELETE /api/v1/vouchers/{id}          # Xóa
```

**Database:**
```sql
CREATE TABLE vouchers (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    title VARCHAR(255),
    description TEXT,
    discount_type VARCHAR(20),        # PERCENTAGE, FIXED_AMOUNT
    discount_value DECIMAL(15,2),
    min_purchase DECIMAL(15,2),
    max_discount DECIMAL(15,2),
    merchant_name VARCHAR(255),
    qr_code TEXT,
    expiry_date DATE,
    is_used BOOLEAN DEFAULT FALSE,
    used_at TIMESTAMP,
    created_at TIMESTAMP
);
```

---

### 📍 **Nhóm 17: Tìm Kiếm & Khám Phá** (Priority: 🟢 Low)

#### 17.1 Tìm Cửa Hàng Gần Đây
**Mô tả:** Tìm cửa hàng, nhà hàng gần đây chấp nhận thanh toán

**Tính năng:**
- Tìm kiếm cửa hàng theo vị trí
- Xem bản đồ cửa hàng
- Xem đánh giá, hình ảnh
- Xem khuyến mãi tại cửa hàng
- Chỉ đường đến cửa hàng

**Backend API:**
```
GET /api/v1/merchants/nearby?lat={lat}&lng={lng}&radius={km}
GET /api/v1/merchants/{id}/reviews
GET /api/v1/merchants/{id}/promotions
```

---

#### 17.2 Khám Phá Khuyến Mãi
**Mô tả:** Xem các khuyến mãi, ưu đãi đang có

**Tính năng:**
- Danh sách khuyến mãi
- Lọc theo danh mục, khu vực
- Lưu khuyến mãi yêu thích
- Nhắc nhở khuyến mãi sắp hết hạn
- Chia sẻ khuyến mãi với bạn bè

**Backend API:**
```
GET /api/v1/promotions                # Danh sách khuyến mãi
GET /api/v1/promotions/{id}           # Chi tiết
POST /api/v1/promotions/{id}/save     # Lưu khuyến mãi
GET /api/v1/promotions/saved          # Khuyến mãi đã lưu
```

---

### 🔗 **Nhóm 18: Tích Hợp & API** (Priority: 🟢 Low)

#### 18.1 API Key Cho Developer
**Mô tả:** Cung cấp API key để tích hợp với ứng dụng khác

**Tính năng:**
- Tạo API key
- Quản lý API key
- Xem lịch sử sử dụng API
- Giới hạn rate limit
- Revoke API key

**Backend API:**
```
POST /api/v1/developer/api-keys       # Tạo API key
GET  /api/v1/developer/api-keys       # Danh sách
DELETE /api/v1/developer/api-keys/{id}  # Xóa
GET  /api/v1/developer/api-keys/{id}/usage  # Lịch sử sử dụng
```

---

#### 18.2 Webhook
**Mô tả:** Nhận thông báo về giao dịch qua webhook

**Tính năng:**
- Đăng ký webhook URL
- Nhận thông báo khi có giao dịch
- Xác thực webhook signature
- Xem lịch sử webhook calls

**Backend API:**
```
POST /api/v1/webhooks                 # Đăng ký webhook
GET  /api/v1/webhooks                 # Danh sách
PUT  /api/v1/webhooks/{id}            # Cập nhật
DELETE /api/v1/webhooks/{id}          # Xóa
GET  /api/v1/webhooks/{id}/logs       # Lịch sử
```

---

### 🎮 **Nhóm 19: Gamification** (Priority: 🟢 Low)

#### 19.1 Thành Tích & Huy Hiệu (Achievements & Badges)
**Mô tả:** Hệ thống thành tích để khuyến khích sử dụng

**Tính năng:**
- Danh sách thành tích
- Nhận huy hiệu khi đạt mục tiêu
- Xem tiến độ thành tích
- Chia sẻ thành tích
- Leaderboard

**Backend API:**
```
GET /api/v1/achievements              # Danh sách thành tích
GET /api/v1/achievements/my           # Thành tích của tôi
GET /api/v1/achievements/leaderboard  # Bảng xếp hạng
```

**Database:**
```sql
CREATE TABLE achievements (
    id UUID PRIMARY KEY,
    name VARCHAR(255),
    description TEXT,
    icon_url TEXT,
    condition_type VARCHAR(50),       # FIRST_TRANSFER, TOTAL_SPENT...
    condition_value DECIMAL(15,2)
);

CREATE TABLE user_achievements (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    achievement_id UUID REFERENCES achievements(id),
    unlocked_at TIMESTAMP
);
```

---

#### 19.2 Mini Games
**Mô tả:** Trò chơi nhỏ để nhận phần thưởng

**Tính năng:**
- Vòng quay may mắn
- Scratch card
- Quiz về tài chính
- Nhận phần thưởng (tiền, điểm, voucher)

**Backend API:**
```
POST /api/v1/games/spin               # Vòng quay may mắn
POST /api/v1/games/scratch            # Scratch card
GET  /api/v1/games/rewards            # Phần thưởng
```

---

### 📱 **Nhóm 20: Tính Năng Di Động Nâng Cao** (Priority: 🟡 Medium)

#### 20.1 Widget Màn Hình Chính
**Mô tả:** Widget hiển thị số dư và chức năng nhanh

**Tính năng:**
- Widget hiển thị số dư (có thể ẩn)
- Widget chuyển tiền nhanh
- Widget quét QR
- Tùy chỉnh widget

---

#### 20.2 Siri Shortcuts / Google Assistant
**Mô tả:** Điều khiển app bằng giọng nói

**Tính năng:**
- "Hey Siri, chuyển 100k cho [tên]"
- "OK Google, kiểm tra số dư"
- "Hey Siri, nạp tiền điện thoại"

---

#### 20.3 Apple Watch / Wear OS
**Mô tả:** Ứng dụng cho smartwatch

**Tính năng:**
- Xem số dư
- Quét QR thanh toán
- Nhận thông báo giao dịch
- Chuyển tiền nhanh

---

### 🔒 **Nhóm 21: Bảo Mật & Tuân Thủ** (Priority: 🔴 High)

#### 21.1 Xác Thực Danh Tính (KYC)
**Mô tả:** Xác thực danh tính người dùng

**Tính năng:**
- Upload CMND/CCCD
- Upload ảnh selfie
- Xác thực bằng AI
- Tăng hạn mức sau khi xác thực
- Trạng thái xác thực

**Backend API:**
```
POST /api/v1/kyc/submit               # Gửi giấy tờ
GET  /api/v1/kyc/status               # Trạng thái
POST /api/v1/kyc/verify               # Xác thực (admin)
```

---

#### 21.2 Báo Cáo Giao Dịch Đáng Ngờ
**Mô tả:** Báo cáo giao dịch bất thường

**Tính năng:**
- Tự động phát hiện giao dịch đáng ngờ
- Báo cáo thủ công
- Tạm khóa tài khoản nếu cần
- Xem lịch sử báo cáo

**Backend API:**
```
POST /api/v1/reports/suspicious       # Báo cáo
GET  /api/v1/reports                  # Lịch sử báo cáo
```

---

#### 21.3 Tuân Thủ AML (Anti-Money Laundering)
**Mô tả:** Tuân thủ quy định chống rửa tiền

**Tính năng:**
- Giới hạn giao dịch theo mức xác thực
- Báo cáo giao dịch lớn
- Kiểm tra danh sách đen
- Audit log

---

## 📋 Ưu Tiên Triển Khai

### 🔴 **Phase 1: Tính Năng Cốt Lõi** (2-3 tuần)
1. Danh bạ người nhận (1.1)
2. Liên kết thẻ ngân hàng (2.1)
3. Nạp/rút tiền từ thẻ (2.2, 2.3)
4. Quản lý thiết bị (7.2)

### 🟡 **Phase 2: Tính Năng Phổ Biến** (2-3 tuần)
5. Thanh toán hóa đơn (3.1)
6. Nạp tiền điện thoại (3.2)
7. Thông báo đẩy (6.1)
8. Báo cáo chi tiêu (5.1)

### 🟢 **Phase 3: Tính Năng Nâng Cao** (2-3 tuần)
9. Mã khuyến mãi (4.1)
10. Ngân sách (5.2)
11. Mục tiêu tiết kiệm (5.3)
12. Chuyển tiền định kỳ (10.1)

---

## 🛠️ Công Nghệ Cần Bổ Sung

### Backend
- **Stripe/PayPal SDK**: Xử lý thanh toán thẻ
- **Firebase Cloud Messaging**: Push notifications
- **Celery**: Xử lý task bất đồng bộ (gửi email, thông báo)
- **Redis**: Cache và queue
- **Pandas**: Xử lý dữ liệu phân tích

### Frontend
- **firebase_messaging**: Push notifications
- **stripe_payment**: Thanh toán thẻ
- **flutter_local_notifications**: Thông báo local
- **pdf**: Tạo PDF báo cáo
- **image_picker**: Chọn ảnh avatar
- **url_launcher**: Mở link hỗ trợ

---

## 📊 So Sánh Với Các Ví Điện Tử Phổ Biến

| Tính năng | MoMo | ZaloPay | PayPal | Venmo | App của bạn | Đề xuất |
|-----------|------|---------|--------|-------|-------------|---------|
| **Cơ bản** |
| Chuyển tiền | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Nạp/rút từ thẻ | ✅ | ✅ | ✅ | ✅ | ❌ | 🔴 |
| Thanh toán hóa đơn | ✅ | ✅ | ✅ | ❌ | ❌ | 🟡 |
| Nạp tiền điện thoại | ✅ | ✅ | ❌ | ❌ | ❌ | 🟡 |
| QR Code | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Danh bạ | ✅ | ✅ | ✅ | ✅ | ❌ | 🔴 |
| **Thanh toán** |
| Thanh toán tại cửa hàng | ✅ | ✅ | ✅ | ✅ | ❌ | 🟡 |
| NFC Payment | ✅ | ✅ | ✅ | ❌ | ❌ | 🟡 |
| Chia hóa đơn | ❌ | ❌ | ✅ | ✅ | ❌ | 🟡 |
| Yêu cầu thanh toán | ❌ | ❌ | ✅ | ✅ | ❌ | 🟡 |
| **Khuyến mãi** |
| Mã khuyến mãi | ✅ | ✅ | ✅ | ✅ | ❌ | 🟢 |
| Hoàn tiền | ✅ | ✅ | ✅ | ❌ | ❌ | 🟢 |
| Điểm thưởng | ✅ | ✅ | ✅ | ❌ | ❌ | 🟢 |
| Voucher | ✅ | ✅ | ✅ | ❌ | ❌ | 🟢 |
| **Phân tích** |
| Báo cáo chi tiêu | ✅ | ✅ | ✅ | ✅ | ⚠️ | 🟡 |
| Ngân sách | ❌ | ❌ | ✅ | ❌ | ❌ | 🟢 |
| Mục tiêu tiết kiệm | ❌ | ❌ | ❌ | ❌ | ❌ | 🟢 |
| Biểu đồ giao dịch | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Bảo mật** |
| 2FA | ✅ | ✅ | ✅ | ✅ | ❌ | 🔴 |
| Quản lý thiết bị | ✅ | ✅ | ✅ | ✅ | ❌ | 🔴 |
| KYC | ✅ | ✅ | ✅ | ✅ | ❌ | 🔴 |
| Biometric Auth | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Nâng cao** |
| Tiết kiệm có lãi | ✅ | ✅ | ❌ | ❌ | ❌ | 🟢 |
| Đầu tư quỹ | ✅ | ❌ | ✅ | ❌ | ❌ | 🟢 |
| Ví gia đình | ❌ | ❌ | ❌ | ❌ | ❌ | 🟢 |
| Ví con | ❌ | ❌ | ❌ | ❌ | ❌ | 🟢 |
| Chuyển tiền định kỳ | ✅ | ✅ | ✅ | ❌ | ❌ | 🟡 |
| **Xã hội** |
| Quyên góp | ✅ | ✅ | ✅ | ✅ | ❌ | 🟢 |
| Tìm cửa hàng | ✅ | ✅ | ❌ | ❌ | ❌ | 🟢 |
| Gamification | ✅ | ✅ | ❌ | ❌ | ❌ | 🟢 |
| **Tích hợp** |
| API cho developer | ❌ | ❌ | ✅ | ❌ | ❌ | 🟢 |
| Webhook | ❌ | ❌ | ✅ | ❌ | ❌ | 🟢 |
| Widget | ✅ | ✅ | ❌ | ❌ | ❌ | 🟡 |
| Smartwatch | ❌ | ❌ | ❌ | ❌ | ❌ | 🟢 |

---

## 🎯 Kết Luận

App của bạn đã có nền tảng tốt với các tính năng cơ bản. Tài liệu này đề xuất **21 nhóm tính năng** với **50+ tính năng cụ thể** để cạnh tranh với các ví điện tử phổ biến.

### 🔴 Ưu Tiên Cao (Nên làm trước)
1. **Liên kết thẻ ngân hàng** - Tính năng quan trọng nhất, cần thiết cho nạp/rút tiền thực tế
2. **Danh bạ người nhận** - Cải thiện trải nghiệm người dùng đáng kể
3. **Thanh toán hóa đơn** - Tính năng được sử dụng thường xuyên
4. **Bảo mật nâng cao** - 2FA, quản lý thiết bị, KYC
5. **Thanh toán tại cửa hàng** - QR code, NFC để thanh toán offline

### 🟡 Ưu Tiên Trung Bình (Làm sau)
6. **Tính năng xã hội** - Chia hóa đơn, yêu cầu thanh toán
7. **Báo cáo & phân tích** - Chi tiêu, ngân sách, mục tiêu tiết kiệm
8. **Thông báo** - Push notifications, cảnh báo
9. **Khuyến mãi** - Mã giảm giá, hoàn tiền, điểm thưởng

### 🟢 Ưu Tiên Thấp (Tùy chọn)
10. **Tích lũy & đầu tư** - Tiết kiệm có lãi, quỹ đầu tư
11. **Ví gia đình** - Quản lý ví chung
12. **Gamification** - Thành tích, mini games
13. **Tích hợp** - API, webhook cho developer

### 📊 Tổng Kết Tính Năng

| Nhóm | Số lượng tính năng | Ưu tiên |
|------|-------------------|---------|
| Quản lý danh bạ | 2 | 🔴 |
| Liên kết ngân hàng | 3 | 🔴 |
| Thanh toán hóa đơn | 3 | 🟡 |
| Khuyến mãi & thưởng | 3 | 🟢 |
| Báo cáo & phân tích | 3 | 🟡 |
| Thông báo | 2 | 🟡 |
| Bảo mật nâng cao | 3 | 🔴 |
| Hỗ trợ | 3 | 🟢 |
| Tùy chỉnh | 3 | 🟢 |
| Giao dịch định kỳ | 2 | 🟡 |
| Đa tiền tệ | 1 | 🟢 |
| Tính năng xã hội | 3 | 🟡 |
| Thanh toán cửa hàng | 2 | 🟡 |
| Tích lũy & đầu tư | 2 | 🟢 |
| Ví gia đình | 2 | 🟢 |
| Voucher | 1 | 🟢 |
| Tìm kiếm | 2 | 🟢 |
| Tích hợp | 2 | 🟢 |
| Gamification | 2 | 🟢 |
| Di động nâng cao | 3 | 🟡 |
| Bảo mật & tuân thủ | 3 | 🔴 |
| **TỔNG** | **50+** | |

### 💡 Lời Khuyên

1. **Bắt đầu nhỏ**: Triển khai từng nhóm tính năng một, test kỹ trước khi chuyển sang nhóm tiếp theo
2. **Lắng nghe người dùng**: Thu thập feedback để ưu tiên tính năng người dùng thực sự cần
3. **Bảo mật trước**: Đảm bảo bảo mật tốt trước khi thêm nhiều tính năng
4. **Tối ưu hiệu năng**: Mỗi tính năng mới cần được tối ưu để không làm chậm app
5. **Tuân thủ pháp luật**: Đặc biệt với các tính năng tài chính, cần tuân thủ quy định của ngân hàng nhà nước

---

*Tài liệu này được tạo dựa trên nghiên cứu các ví điện tử: MoMo, ZaloPay, PayPal, Venmo, Apple Pay, Google Pay*

