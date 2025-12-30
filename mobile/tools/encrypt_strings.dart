#!/usr/bin/env dart

/// Script to encrypt sensitive strings for use in the app
/// Usage: dart tools/encrypt_strings.dart

import 'dart:convert';
import 'dart:io';
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

/// Derive encryption key from master key using PBKDF2
Uint8List _deriveKey(String password, String salt) {
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
String encrypt(String plaintext) {
  // Master key - must match the one in StringEncryptionService
  const masterKeyBase = 'ewallet_app_secure_key_2024';
  const salt = 'ewallet_salt_2024';

  // Derive key from master key
  final key = _deriveKey(masterKeyBase, salt);

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
}

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart tools/encrypt_strings.dart <string-to-encrypt>');
    print('');
    print('Examples:');
    print('  dart tools/encrypt_strings.dart "http://10.0.2.2:8000/api/v1"');
    print('  dart tools/encrypt_strings.dart "https://api.example.com/v1"');
    exit(1);
  }

  final plaintext = args.join(' ');
  print('Encrypting: $plaintext');
  print('');

  try {
    final encrypted = encrypt(plaintext);
    print('Encrypted string:');
    print(encrypted);
    print('');
    print('Copy this encrypted string to StringEncryptionService.getBaseUrl()');
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
