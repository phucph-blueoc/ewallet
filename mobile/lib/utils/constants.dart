import '../services/string_encryption_service.dart';

/// Get base URL - uses encrypted string for security
/// The URL is decrypted at runtime using StringEncryptionService
String get baseUrl => StringEncryptionService.getBaseUrl();

// Legacy plain text URLs (for development only - remove in production)
// const String baseUrlDev = 'http://10.0.2.2:8000/api/v1'; // Android emulator
// const String baseUrlIOS = 'http://localhost:8000/api/v1'; // iOS simulator
// const String baseUrlProd = 'http://YOUR_IP:8000/api/v1'; // Physical device
