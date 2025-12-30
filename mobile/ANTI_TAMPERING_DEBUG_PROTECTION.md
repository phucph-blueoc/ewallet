# Anti-Tampering và Debug Protection Implementation

Tài liệu này mô tả việc triển khai các tính năng Anti-Tampering và Debug Protection cho E-Wallet App.

## 📋 Tổng Quan

Đã triển khai các tính năng bảo mật sau:
1. ✅ **Anti-Tampering**: App signature verification, integrity checks
2. ✅ **Debug Protection**: Disable debug logging trong release builds, remove debug symbols

---

## 🔒 Anti-Tampering

### 1. App Signature Verification

**File**: `mobile/lib/services/anti_tampering_service.dart`

Service này kiểm tra:
- **App signature hash** (Android): Xác minh chữ ký ứng dụng để phát hiện repackaging
- **Package name verification**: Đảm bảo package name không bị thay đổi
- **Installation source check**: Kiểm tra app có được cài từ Play Store/App Store không

**Native Implementation**: `mobile/android/app/src/main/kotlin/com/ewallet/ewallet_app/AntiTamperingPlugin.kt`

### 2. Integrity Checks

Service thực hiện các kiểm tra toàn vẹn:
- Verify app signature
- Verify package name
- Check installation source
- Root/jailbreak detection (đã có sẵn)

### 3. Integration với SecurityService

**File**: `mobile/lib/services/security_service.dart`

`SecurityService` đã được cập nhật để tích hợp anti-tampering checks:
- `isAppTampered()`: Kiểm tra app có bị tamper không
- `verifyAppSignature()`: Xác minh chữ ký ứng dụng
- `isInstalledFromOfficialStore()`: Kiểm tra nguồn cài đặt
- `performSecurityCheck()`: Kiểm tra bảo mật toàn diện

---

## 🛡️ Debug Protection

### 1. Logger Utility

**File**: `mobile/lib/utils/logger.dart`

Logger utility tự động disable debug logging trong release builds:

```dart
Logger.debug('Debug message');      // Chỉ hiển thị trong debug mode
Logger.info('Info message');        // Chỉ hiển thị trong debug mode
Logger.warning('Warning message');  // Chỉ hiển thị trong debug mode
Logger.error('Error message', error: e, stackTrace: stackTrace);
Logger.sensitive('Sensitive data'); // Không bao giờ log trong production
```

**Tính năng**:
- Tự động disable trong release builds (`kDebugMode` check)
- Phân loại log levels (debug, info, warning, error, sensitive)
- Không log sensitive data trong production

### 2. Thay Thế Debug Statements

Đã thay thế tất cả `debugPrint()` và `print()` statements bằng `Logger`:
- ✅ `mobile/lib/main.dart`
- ✅ `mobile/lib/services/fcm_service.dart`
- ✅ `mobile/lib/services/biometric_service.dart`
- ✅ `mobile/lib/services/fcm_helper.dart`
- ✅ `mobile/lib/screens/bank_cards/verify_bank_card_screen.dart`

### 3. Build Configuration

**File**: `mobile/android/app/build.gradle.kts`

Đã cập nhật build configuration:
- **Release builds**: Remove debug symbols (`debugSymbolLevel = "NONE"`)
- **Debug builds**: Keep debug symbols (`debugSymbolLevel = "FULL"`)

**Build Script**: `mobile/build_release_obfuscated.sh`

Script build đã có sẵn:
- `--obfuscate`: Enable code obfuscation
- `--split-debug-info`: Tách debug info ra khỏi APK/AAB

---

## 🚀 Cách Sử Dụng

### 1. Sử dụng Logger

```dart
import '../utils/logger.dart';

// Debug logging (chỉ trong debug mode)
Logger.debug('Processing request...');

// Info logging
Logger.info('User logged in successfully');

// Warning logging
Logger.warning('Low balance detected');

// Error logging
Logger.error('Failed to process payment', error: e, stackTrace: stackTrace);

// Sensitive data (không bao giờ log trong production)
Logger.sensitive('Token: $token');
```

### 2. Sử dụng Anti-Tampering Service

```dart
import '../services/anti_tampering_service.dart';

final antiTampering = AntiTamperingService();

// Verify app integrity
final isValid = await antiTampering.verifyAppIntegrity();
if (!isValid) {
  // App has been tampered with
}

// Get comprehensive security status
final status = await antiTampering.getSecurityStatus();
print('Signature valid: ${status['signatureValid']}');
print('Package valid: ${status['packageValid']}');
print('From official store: ${status['fromOfficialStore']}');
```

### 3. Sử dụng SecurityService (tích hợp)

```dart
import '../services/security_service.dart';

final securityService = SecurityService();

// Perform comprehensive security check
final isSecure = await securityService.performSecurityCheck();
if (!isSecure) {
  // Handle security violation
}

// Get full security status
final status = await securityService.getSecurityStatus();
```

---

## 🔧 Build Release với Obfuscation

### Android

```bash
cd mobile
./build_release_obfuscated.sh android
```

Hoặc manual:
```bash
flutter build apk --release \
    --obfuscate \
    --split-debug-info=./debug-info/android
```

### iOS

```bash
cd mobile
./build_release_obfuscated.sh ios
```

Hoặc manual:
```bash
flutter build ios --release \
    --obfuscate \
    --split-debug-info=./debug-info/ios
```

---

## ⚠️ Lưu Ý Quan Trọng

### 1. Debug Info Directory

Khi build với `--split-debug-info`, debug info được lưu trong `debug-info/`:
- **KHÔNG commit** directory này vào git
- **GIỮ AN TOÀN** để symbolicate crash reports sau này
- Thêm vào `.gitignore`:
  ```
  debug-info/
  ```

### 2. App Signature Hash

Trong production, cần set `_expectedSignatureHash` trong `anti_tampering_service.dart`:
```dart
static const String _expectedSignatureHash = 'YOUR_SIGNATURE_HASH_HERE';
```

Để lấy signature hash:
1. Build release APK
2. Install trên device
3. Call `getAppSignature()` từ service
4. Copy hash và set vào code

### 3. ProGuard Rules

Đảm bảo `proguard-rules.pro` không obfuscate các class quan trọng:
- SecurityService
- AntiTamperingService
- Native plugin classes

---

## 📊 Kết Quả

### Trước khi triển khai:
- ❌ Không có anti-tampering checks
- ❌ Debug logging hiển thị trong release builds
- ❌ Debug symbols có trong release APK

### Sau khi triển khai:
- ✅ App signature verification
- ✅ Integrity checks
- ✅ Debug logging tự động disable trong release
- ✅ Debug symbols được remove khỏi release builds
- ✅ Code obfuscation enabled

---

## 🔍 Testing

### Test Anti-Tampering

1. **Test signature verification**:
   ```dart
   final service = AntiTamperingService();
   final isValid = await service.verifyAppSignature();
   assert(isValid == true);
   ```

2. **Test package name**:
   ```dart
   final isValid = await service.verifyPackageName();
   assert(isValid == true);
   ```

3. **Test integrity check**:
   ```dart
   final isValid = await service.verifyAppIntegrity();
   assert(isValid == true);
   ```

### Test Debug Protection

1. **Build debug APK**: Logger sẽ hiển thị logs
2. **Build release APK**: Logger sẽ không hiển thị logs
3. **Check APK size**: Release APK nhỏ hơn do không có debug symbols

---

## 📝 Checklist Triển Khai

- [x] Tạo Logger utility
- [x] Tạo AntiTamperingService
- [x] Tạo Android native plugin
- [x] Cập nhật SecurityService
- [x] Thay thế tất cả debugPrint/print statements
- [x] Cập nhật build configuration
- [x] Test trong debug mode
- [x] Test trong release mode
- [ ] Set expected signature hash trong production
- [ ] Test trên physical devices
- [ ] Verify debug symbols không có trong release APK

---

## 🔗 Tài Liệu Tham Khảo

- [Flutter Code Obfuscation](https://docs.flutter.dev/deployment/obfuscate)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [ProGuard Rules](https://www.guardsquare.com/manual/configuration/usage)

