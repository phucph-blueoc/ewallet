# Troubleshooting Push Notifications

## Vấn đề: Không nhận được push notifications

### Bước 1: Kiểm tra Device Token đã được đăng ký chưa

Chạy script test:
```bash
cd backend
python test_fcm.py
```

Nếu thấy "No users with device tokens found", thì:
1. Mở Flutter app
2. Đăng nhập lại (logout rồi login)
3. Kiểm tra logs để xem token có được đăng ký không

### Bước 2: Kiểm tra Flutter App Logs

Trong Flutter app, kiểm tra console logs khi đăng nhập:
- Tìm "FCM Token: ..."
- Tìm "FCM token registered with backend"

Nếu không thấy các log này:
- FCM có thể chưa được khởi tạo
- Hoặc Firebase chưa được cấu hình đúng

### Bước 3: Kiểm tra Backend Logs

Khi thực hiện giao dịch (nạp/rút tiền), kiểm tra backend logs:
- Tìm "Created notification ..."
- Tìm "Successfully sent push notification" hoặc "Failed to send push notification"

### Bước 4: Kiểm tra Notification Settings

Đảm bảo user có notification settings và transaction notifications đã bật:
```sql
SELECT * FROM notification_settings WHERE user_id = 'your-user-id';
```

Kiểm tra:
- `enable_transaction_notifications` = true
- `device_token` IS NOT NULL và không rỗng

### Bước 5: Kiểm tra Firebase Service Account Key

Đảm bảo file `firebase-service-account-key.json` tồn tại trong thư mục `backend/`:
```bash
ls -la backend/firebase-service-account-key.json
```

### Bước 6: Test Push Notification Thủ Công

Sau khi đảm bảo device token đã được đăng ký, chạy test:
```bash
cd backend
python test_fcm.py
```

Nếu test thành công nhưng vẫn không nhận được notification khi nạp/rút tiền:
- Kiểm tra logs khi thực hiện giao dịch
- Kiểm tra xem notification có được tạo trong database không
- Kiểm tra xem push notification có được gọi không

## Các Lỗi Thường Gặp

### 1. "No device token found"
**Nguyên nhân**: Flutter app chưa đăng ký device token với backend
**Giải pháp**: 
- Đăng nhập lại vào app
- Kiểm tra logs để xem có lỗi khi đăng ký token không

### 2. "Firebase service account key not found"
**Nguyên nhân**: File service account key chưa được đặt đúng vị trí
**Giải pháp**: Đặt file `firebase-service-account-key.json` vào thư mục `backend/`

### 3. "Failed to send push notification: UnregisteredError"
**Nguyên nhân**: Device token không còn hợp lệ (app đã được uninstall hoặc token đã expire)
**Giải pháp**: 
- Đăng nhập lại để lấy token mới
- Token sẽ tự động refresh khi app mở lại

### 4. Notification được tạo nhưng không nhận được push
**Nguyên nhân**: 
- Device token chưa được đăng ký
- Notification settings đã tắt transaction notifications
- Firebase chưa được cấu hình đúng

**Giải pháp**: Làm theo các bước trên để kiểm tra từng điểm

## Debug Checklist

- [ ] Firebase service account key đã được đặt đúng vị trí
- [ ] Flutter app đã đăng nhập
- [ ] Device token đã được đăng ký (kiểm tra database)
- [ ] Transaction notifications đã được bật trong settings
- [ ] Backend logs không có lỗi khi gửi push notification
- [ ] Đã test bằng script test_fcm.py và thành công


