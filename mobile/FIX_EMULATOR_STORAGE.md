# Giải Quyết Lỗi Thiếu Dung Lượng Emulator

## Vấn Đề
Emulator không đủ dung lượng để cài đặt app. Hiện tại emulator đang sử dụng 92% dung lượng (chỉ còn 470MB trống).

## Giải Pháp

### Cách 1: Dọn Dẹp Emulator (Nhanh)
```bash
cd mobile
./clean_emulator.sh
```

### Cách 2: Xóa App Không Cần Thiết
```bash
# Xem danh sách app đã cài
adb shell pm list packages -3

# Xóa một app cụ thể (thay package_name)
adb shell pm uninstall <package_name>
```

### Cách 3: Tạo Emulator Mới Với Nhiều Storage Hơn (Khuyến Nghị)

1. Mở Android Studio
2. Tools → Device Manager
3. Tạo AVD mới hoặc chỉnh sửa AVD hiện tại:
   - Show Advanced Settings
   - Tăng **Internal Storage** lên ít nhất **8GB** (thay vì 5.8GB mặc định)
   - Tăng **SD Card** nếu cần

4. Hoặc sử dụng command line:
```bash
# Xem danh sách AVD
emulator -list-avds

# Tạo AVD mới với nhiều storage
avdmanager create avd -n "Pixel_8_API_34_Large" -k "system-images;android-34;google_apis;x86_64" -d "pixel_8" -c 8192M
```

### Cách 4: Sử Dụng Device Thật
Kết nối điện thoại Android thật qua USB và chạy:
```bash
flutter run
```

### Cách 5: Xóa Cache và Data của Emulator
```bash
# Xóa tất cả data của emulator (sẽ mất tất cả app và data)
# CẢNH BÁO: Sẽ xóa tất cả dữ liệu trên emulator
emulator -avd <avd_name> -wipe-data
```

## Kiểm Tra Dung Lượng
```bash
adb shell df -h | grep "/data"
```

## Sau Khi Giải Phóng Dung Lượng
```bash
cd mobile
flutter run
```

## Lưu Ý
- Nên tạo emulator mới với ít nhất 8GB internal storage để tránh vấn đề này
- Nếu thường xuyên test app, nên dùng device thật hoặc emulator có nhiều storage

