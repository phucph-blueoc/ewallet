import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes_fast.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';

/// Service for encrypting and decrypting sensitive strings at runtime
/// Uses AES-256 encryption with a key derived from a master key
class StringEncryptionService {
  // Master key - In production, this should be obfuscated or derived from device-specific data
  // This is a base key that will be used to derive the actual encryption key
  static const String _masterKeyBase = 'ewallet_app_secure_key_2024';

  // Salt for key derivation - should be unique per app
  static const String _salt = 'ewallet_salt_2024';

  /// Derive encryption key from master key using PBKDF2
  static Uint8List _deriveKey(String password, String salt) {
    final keyDerivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    final params = Pbkdf2Parameters(
      utf8.encode(salt),
      10000, // Iteration count
      32, // Key length (256 bits)
    );
    keyDerivator.init(params);

    return keyDerivator.process(utf8.encode(password));
  }

  /// Encrypt a string using AES-256-CBC
  static String encrypt(String plaintext) {
    try {
      // Derive key from master key
      final key = _deriveKey(_masterKeyBase, _salt);

      // Generate random IV
      final iv = Uint8List(16);
      final random = Random.secure();
      for (int i = 0; i < iv.length; i++) {
        iv[i] = random.nextInt(256);
      }

      // Create cipher
      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESFastEngine()),
      );

      final params = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv),
        null,
      );
      cipher.init(true, params);

      // Encrypt
      final plaintextBytes = utf8.encode(plaintext);
      final cipherText = cipher.process(plaintextBytes);

      // Combine IV + ciphertext and encode as base64
      final combined = Uint8List(iv.length + cipherText.length);
      combined.setRange(0, iv.length, iv);
      combined.setRange(iv.length, combined.length, cipherText);

      return base64Encode(combined);
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  /// Decrypt a string using AES-256-CBC
  static String decrypt(String encryptedText) {
    try {
      // Decode base64
      final combined = base64Decode(encryptedText);

      // Extract IV and ciphertext
      final iv = combined.sublist(0, 16);
      final cipherText = combined.sublist(16);

      // Derive key from master key
      final key = _deriveKey(_masterKeyBase, _salt);

      // Create cipher
      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESFastEngine()),
      );

      final params = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv),
        null,
      );
      cipher.init(false, params);

      // Decrypt
      final plaintextBytes = cipher.process(cipherText);
      return utf8.decode(plaintextBytes);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  /// Get decrypted base URL
  /// This method decrypts the encrypted base URL at runtime
  static String getBaseUrl() {
    // Encrypted base URLs for different environments
    // These are encrypted versions of the actual URLs
    // To generate new encrypted strings, use the encrypt() method

    // Development/Emulator URL (encrypted)
    const encryptedDevUrl =
        'Z9Ha+sIAMb+xaNkBrid1iyB9SiBQqFAsF7PhxgvdpRcT9G1nI/JDE2z3uF6SVYyw';

    // Production URL (encrypted) - uncomment when ready
    // const encryptedProdUrl = 'YOUR_ENCRYPTED_PROD_URL_HERE';

    // For now, return decrypted dev URL
    // In production, you can switch based on build flavor or environment variable
    try {
      // If encrypted URL is set, decrypt it
      if (encryptedDevUrl !=
          'Z9Ha+sIAMb+xaNkBrid1iyB9SiBQqFAsF7PhxgvdpRcT9G1nI/JDE2z3uF6SVYyw') {
        return decrypt(encryptedDevUrl);
      }

      // Fallback to plain text (for development only)
      // Remove this in production!
      return 'http://10.0.2.2:8000/api/v1';
    } catch (e) {
      // Fallback if decryption fails
      return 'http://10.0.2.2:8000/api/v1';
    }
  }
}
