# 🔐 String Encryption Guide

Hướng dẫn sử dụng String Encryption để bảo vệ các strings nhạy cảm trong code.

## 📋 Tổng Quan

String Encryption giúp:
- ✅ Mã hóa các strings nhạy cảm (API URLs, keys) trong code
- ✅ Giảm nguy cơ bị reverse engineering
- ✅ Bảo vệ API endpoints và configuration
- ✅ Decrypt strings tại runtime khi cần

## 🔧 Cấu Hình

### Dependencies

Package `pointycastle` đã được thêm vào `pubspec.yaml` để hỗ trợ AES-256 encryption.

### Service

`StringEncryptionService` cung cấp:
- `encrypt(String)` - Mã hóa string
- `decrypt(String)` - Giải mã string
- `getBaseUrl()` - Lấy base URL đã được giải mã

## 🚀 Sử Dụng

### 1. Encrypt Strings

Sử dụng script `tools/encrypt_strings.dart` để encrypt strings:

```bash
cd mobile
dart tools/encrypt_strings.dart "http://10.0.2.2:8000/api/v1"
```

Output sẽ là encrypted string dạng base64.

### 2. Thêm Encrypted String vào Code

Sau khi có encrypted string, thêm vào `StringEncryptionService.getBaseUrl()`:

```dart
static String getBaseUrl() {
  // Thay YOUR_ENCRYPTED_URL_HERE bằng encrypted string từ script
  const encryptedDevUrl = 'YOUR_ENCRYPTED_STRING_HERE';
  
  if (encryptedDevUrl != 'YOUR_ENCRYPTED_URL_HERE') {
    return decrypt(encryptedDevUrl);
  }
  
  // Fallback (chỉ dùng trong development)
  return 'http://10.0.2.2:8000/api/v1';
}
```

### 3. Sử Dụng trong Code

File `constants.dart` đã được cập nhật để sử dụng encrypted URL:

```dart
import '../services/string_encryption_service.dart';

String get baseUrl => StringEncryptionService.getBaseUrl();
```

Code khác sử dụng `baseUrl` sẽ tự động nhận được decrypted URL.

## 🔒 Bảo Mật

### Master Key

Master key được lưu trong `StringEncryptionService`:
- **⚠️ QUAN TRỌNG**: Trong production, nên obfuscate master key
- Có thể kết hợp với device-specific data để tăng bảo mật
- Không commit master key vào public repositories

### Key Derivation

- Sử dụng PBKDF2 với 10,000 iterations
- Key length: 256 bits (AES-256)
- Salt: unique per application

### Encryption Algorithm

- **Algorithm**: AES-256-CBC
- **Padding**: PKCS7
- **IV**: Random 16 bytes (được prepend vào ciphertext)

## 📝 Ví Dụ

### Encrypt Base URL

```bash
# Development URL
dart tools/encrypt_strings.dart "http://10.0.2.2:8000/api/v1"

# Production URL
dart tools/encrypt_strings.dart "https://api.ewallet.com/v1"
```

### Encrypt API Keys (nếu có)

```bash
dart tools/encrypt_strings.dart "your-api-key-here"
```

Sau đó thêm vào service tương ứng.

## ⚠️ Lưu Ý Quan Trọng

### Development vs Production

1. **Development**: Có thể dùng fallback plain text URL
2. **Production**: **BẮT BUỘC** phải dùng encrypted strings
3. **Không commit** encrypted strings vào git nếu chứa production URLs

### Performance

- Decryption chỉ xảy ra một lần khi app khởi động
- Overhead rất nhỏ (< 1ms)
- Có thể cache decrypted values

### Error Handling

Service có fallback mechanism:
- Nếu decryption fails → dùng fallback URL
- Trong production, nên log error và alert

## 🔧 Troubleshooting

### Decryption Fails

**Nguyên nhân:**
- Master key không khớp
- Encrypted string bị corrupt
- Salt không đúng

**Giải pháp:**
1. Kiểm tra master key trong service
2. Re-encrypt string bằng script
3. Đảm bảo salt giống nhau

### Script Không Chạy

**Lỗi:** `package:pointycastle not found`

**Giải pháp:**
```bash
cd mobile
flutter pub get
```

### App Crash Khi Decrypt

**Nguyên nhân:**
- Encrypted string format không đúng
- Master key thay đổi

**Giải pháp:**
1. Kiểm tra encrypted string format (phải là base64)
2. Đảm bảo master key không đổi
3. Test với plain text fallback trước

## 📚 Best Practices

1. **Obfuscate Master Key**: Sử dụng code obfuscation để bảo vệ master key
2. **Environment-based**: Sử dụng different encrypted strings cho dev/staging/prod
3. **Key Rotation**: Có thể rotate master key theo version
4. **Monitoring**: Log decryption failures để phát hiện tampering

## 🔄 Migration Guide

### Từ Plain Text sang Encrypted

1. Encrypt tất cả sensitive strings:
   ```bash
   dart tools/encrypt_strings.dart "your-string"
   ```

2. Thay thế trong code:
   ```dart
   // Trước
   const String baseUrl = 'http://example.com';
   
   // Sau
   const String encryptedUrl = 'YOUR_ENCRYPTED_STRING';
   String get baseUrl => StringEncryptionService.decrypt(encryptedUrl);
   ```

3. Test thoroughly
4. Remove plain text strings

## 📚 Tài Liệu Tham Khảo

- [PointyCastle Documentation](https://pub.dev/packages/pointycastle)
- [AES Encryption](https://en.wikipedia.org/wiki/Advanced_Encryption_Standard)
- [PBKDF2](https://en.wikipedia.org/wiki/PBKDF2)

---

**Last updated:** December 2024

