# 🔒 Code Obfuscation Guide

Hướng dẫn sử dụng Code Obfuscation để bảo vệ mã nguồn ứng dụng.

## 📋 Tổng Quan

Code Obfuscation giúp:
- ✅ Làm khó reverse engineering
- ✅ Bảo vệ logic nghiệp vụ và API endpoints
- ✅ Giảm kích thước file APK/IPA
- ✅ Tối ưu hiệu suất ứng dụng

## 🤖 Android

### Cấu hình đã được thiết lập

File `android/app/build.gradle.kts` đã được cấu hình với:
- ✅ `minifyEnabled = true` - Bật code minification
- ✅ `shrinkResources = true` - Xóa resources không sử dụng
- ✅ ProGuard rules trong `proguard-rules.pro`

### Build với Obfuscation

**APK:**
```bash
flutter build apk --release \
    --obfuscate \
    --split-debug-info=./debug-info/android
```

**App Bundle (AAB):**
```bash
flutter build appbundle --release \
    --obfuscate \
    --split-debug-info=./debug-info/android
```

### ProGuard Rules

File `android/app/proguard-rules.pro` chứa các rules để:
- Giữ lại các class cần thiết cho Flutter
- Giữ lại Firebase và các dependencies
- Xóa logging trong release builds
- Tối ưu code

## 🍎 iOS

### Build với Obfuscation

Flutter tự động obfuscate Dart code khi dùng flag `--obfuscate`:

```bash
flutter build ios --release \
    --obfuscate \
    --split-debug-info=./debug-info/ios
```

### Xcode Settings (Tùy chọn)

Để bật thêm obfuscation cho native iOS code:

1. Mở Xcode project: `ios/Runner.xcworkspace`
2. Chọn target **Runner**
3. Vào tab **Build Settings**
4. Tìm **Swift Compiler - Code Generation**
5. Set **Optimization Level** = **Optimize for Speed** (cho Release)
6. Set **Strip Debug Symbols During Copy** = **Yes** (cho Release)

## 🚀 Sử dụng Script Tự Động

Script `build_release_obfuscated.sh` đã được tạo để tự động build:

```bash
# Build cả Android và iOS
./build_release_obfuscated.sh

# Chỉ build Android
./build_release_obfuscated.sh android

# Chỉ build iOS
./build_release_obfuscated.sh ios
```

## ⚠️ Lưu Ý Quan Trọng

### Debug Info Directory

Khi build với `--split-debug-info`, Flutter sẽ tạo các file debug info trong thư mục `debug-info/`.

**⚠️ QUAN TRỌNG:**
- ✅ **LƯU TRỮ AN TOÀN** các file debug info
- ✅ Cần chúng để **symbolicate crash reports**
- ❌ **KHÔNG commit** vào git (đã có trong .gitignore)
- ❌ **KHÔNG chia sẻ** công khai

### Symbolicate Crash Reports

Khi có crash report, sử dụng debug info để symbolicate:

```bash
flutter symbolize -i <crash-file> -d ./debug-info/android
```

## 📝 Kiểm Tra Obfuscation

### Android

Sau khi build, kiểm tra APK:

```bash
# Giải nén APK
unzip -q app-release.apk -d apk_contents

# Kiểm tra classes.dex (sẽ thấy code đã bị obfuscate)
# Tên class/method sẽ là a, b, c... thay vì tên thật
```

### iOS

Kiểm tra trong Xcode:
1. Mở **Window** > **Organizer**
2. Chọn build đã archive
3. Xem **Symbols** - sẽ thấy code đã bị obfuscate

## 🔧 Troubleshooting

### Lỗi ProGuard

Nếu gặp lỗi ProGuard khi build:

1. Kiểm tra `proguard-rules.pro` có đúng rules
2. Thêm `-keep` rules cho class bị lỗi
3. Xem log trong `android/app/build/outputs/mapping/release/`

### App Crash Sau Khi Obfuscate

1. Kiểm tra có thiếu `-keep` rules không
2. Xem crash log để tìm class/method bị ảnh hưởng
3. Thêm rules tương ứng vào `proguard-rules.pro`

### Debug Info Bị Mất

Nếu mất debug info:
- Không thể symbolicate crash reports
- Cần build lại với `--split-debug-info`
- Lưu trữ debug info an toàn cho mỗi version

## 📚 Tài Liệu Tham Khảo

- [Flutter Code Obfuscation](https://docs.flutter.dev/deployment/obfuscate)
- [Android ProGuard](https://developer.android.com/studio/build/shrink-code)
- [iOS Code Obfuscation](https://developer.apple.com/documentation/xcode/reducing-your-app-s-size)

---

**Last updated:** December 2024

