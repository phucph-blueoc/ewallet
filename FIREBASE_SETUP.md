# Firebase Cloud Messaging (FCM) Setup Guide

## Tổng quan
Ứng dụng đã được tích hợp FCM để gửi push notifications. Để sử dụng, bạn cần cấu hình Firebase project.

## Bước 1: Tạo Firebase Project

1. Truy cập [Firebase Console](https://console.firebase.google.com/)
2. Tạo project mới hoặc chọn project hiện có
3. Thêm Android app:
   - Package name: `com.example.ewallet_app` (hoặc package name của bạn)
   - Download `google-services.json`
   - Đặt file vào `mobile/android/app/`

4. Thêm iOS app (nếu cần):
   - Bundle ID: Bundle ID của iOS app
   - Download `GoogleService-Info.plist`
   - Đặt file vào `mobile/ios/Runner/`

## Bước 2: Cấu hình Android

1. Đảm bảo `google-services.json` đã được đặt trong `mobile/android/app/`
2. Kiểm tra `mobile/android/build.gradle`:
   ```gradle
   buildscript {
       dependencies {
           classpath 'com.google.gms:google-services:4.4.0'
       }
   }
   ```

3. Kiểm tra `mobile/android/app/build.gradle`:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

## Bước 3: Cấu hình iOS (nếu cần)

1. Đảm bảo `GoogleService-Info.plist` đã được đặt trong `mobile/ios/Runner/`
2. Mở Xcode và thêm file vào project
3. Cấu hình Push Notifications capability trong Xcode

## Bước 4: Cài đặt Dependencies

```bash
cd mobile
flutter pub get
```

## Bước 5: Cấu hình Backend để gửi Push Notifications

### 5.1. Tải Firebase Service Account Key

1. Vào Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Tải file JSON (ví dụ: `ewallet-firebase-adminsdk.json`)
4. Đặt file vào thư mục `backend/` với tên `firebase-service-account-key.json`

Hoặc set environment variable:
```bash
export FIREBASE_CREDENTIALS=/path/to/firebase-service-account-key.json
```

### 5.2. Cài đặt Dependencies

Backend đã có `firebase-admin` trong `requirements.txt`. Chạy:

```bash
cd backend
pip install firebase-admin
```

### 5.3. Backend đã tự động tích hợp

Backend đã có FCM service (`app/services/fcm_service.py`) và sẽ tự động:
- Gửi push notification khi có transaction (nạp/rút/chuyển tiền)
- Lấy device token từ `notification_settings` table
- Xử lý lỗi gracefully nếu Firebase chưa được cấu hình

### 5.4. Test Push Notifications

1. Đảm bảo user đã đăng ký device token (qua API `/api/v1/notifications/register`)
2. Thực hiện một giao dịch (nạp/rút tiền)
3. Kiểm tra push notification trên device

## Cách hoạt động

1. **Khởi tạo**: FCM được khởi tạo khi user đăng nhập và vào WalletHomeScreen
2. **Đăng ký token**: Token được tự động đăng ký với backend qua API `/api/v1/notifications/register`
3. **Nhận notifications**:
   - **Foreground**: App đang mở - notifications được xử lý và refresh notification count
   - **Background**: App đang chạy ở background - notifications hiển thị trong notification tray
   - **Terminated**: App đã đóng - notifications hiển thị trong notification tray, khi tap sẽ mở app

## Testing

1. Chạy app và đăng nhập
2. Kiểm tra log để xem FCM token đã được lấy chưa
3. Gửi test notification từ Firebase Console hoặc backend
4. Kiểm tra notification được nhận ở các trạng thái khác nhau

## Lưu ý

- iOS cần request permission trước khi nhận notifications
- Android tự động có permission
- Token có thể refresh, service sẽ tự động đăng ký lại
- Khi logout, token sẽ bị xóa

