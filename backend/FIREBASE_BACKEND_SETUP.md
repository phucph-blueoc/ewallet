# Cấu hình Firebase Admin SDK cho Backend

## Bước 1: Lấy Firebase Service Account Key

1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Chọn project của bạn (ewallet-7a05e)
3. Vào **Project Settings** (biểu tượng ⚙️)
4. Vào tab **Service Accounts**
5. Click **Generate new private key**
6. Click **Generate key** để tải file JSON

## Bước 2: Đặt Service Account Key vào Backend

Đặt file JSON vừa tải vào thư mục `backend/` với tên:
```
firebase-service-account-key.json
```

Hoặc set environment variable:
```bash
export FIREBASE_CREDENTIALS=/path/to/your/firebase-service-account-key.json
```

## Bước 3: Cài đặt Dependencies

```bash
cd backend
pip install firebase-admin
```

Hoặc nếu dùng requirements.txt:
```bash
pip install -r requirements.txt
```

## Bước 4: Test

1. Đảm bảo user đã đăng ký device token (qua Flutter app)
2. Thực hiện một giao dịch (nạp/rút tiền)
3. Kiểm tra push notification trên device

## Lưu ý Bảo Mật

⚠️ **QUAN TRỌNG**: File `firebase-service-account-key.json` chứa credentials quan trọng:
- KHÔNG commit file này vào git
- Thêm vào `.gitignore`:
  ```
  firebase-service-account-key.json
  *.json
  ```
- Chỉ share cho team members cần thiết
- Trong production, sử dụng environment variables hoặc secret manager

## Troubleshooting

### Lỗi: "Firebase service account key not found"
- Kiểm tra file có đúng tên và đường dẫn không
- Kiểm tra environment variable FIREBASE_CREDENTIALS

### Lỗi: "Invalid credentials"
- Kiểm tra file JSON có hợp lệ không
- Đảm bảo bạn đã tải key từ đúng Firebase project

### Không nhận được push notification
- Kiểm tra device token đã được đăng ký chưa (qua API `/api/v1/notifications/register`)
- Kiểm tra logs của backend để xem có lỗi gì không
- Kiểm tra notification settings của user có bật transaction notifications không


