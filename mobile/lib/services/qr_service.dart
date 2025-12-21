import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';

class QRService {
  /// Generate QR code data for current user (receiver)
  /// Format: JSON with user email so others can send money to this user
  static String generateUserQRData({
    required String email,
  }) {
    final data = {
      'type': 'receive',
      'email': email,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return jsonEncode(data);
  }

  /// Generate QR code data for transfer (legacy - for scanning)
  /// Format: JSON with email, amount, and optional note
  static String generateTransferQRData({
    required String email,
    required double amount,
    String? note,
  }) {
    final data = {
      'type': 'transfer',
      'email': email,
      'amount': amount,
      if (note != null && note.isNotEmpty) 'note': note,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return jsonEncode(data);
  }

  /// Parse QR code data
  static Map<String, dynamic>? parseTransferQRData(String qrData) {
    try {
      final data = jsonDecode(qrData);
      // Support both 'transfer' (with amount) and 'receive' (just email) types
      if (data['type'] == 'transfer' && data['email'] != null && data['amount'] != null) {
        return data;
      } else if (data['type'] == 'receive' && data['email'] != null) {
        // For receive type, return email only (amount/note will be entered by sender)
        return {
          'type': 'transfer',
          'email': data['email'],
          'amount': null, // Sender will enter amount
          'note': null, // Sender will enter note
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Generate QR code widget
  static Widget generateQRCode({
    required String data,
    double size = 200,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: backgroundColor ?? Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
  }
}

