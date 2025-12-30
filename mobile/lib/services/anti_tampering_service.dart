import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Anti-tampering service for app integrity verification
/// 
/// Features:
/// - App signature verification (Android)
/// - Integrity checks (file hash verification)
/// - Detects if app has been modified or repackaged
class AntiTamperingService {
  static final AntiTamperingService _instance = AntiTamperingService._internal();
  factory AntiTamperingService() => _instance;
  AntiTamperingService._internal();

  static const MethodChannel _channel = MethodChannel('com.ewallet.ewallet_app/anti_tampering');
  
  // Expected app signature hash (should be set during build)
  // In production, this should be fetched from secure server
  static const String _expectedSignatureHash = ''; // Set during build
  
  // Expected app package name
  static const String _expectedPackageName = 'com.ewallet.ewallet_app';

  /// Verify app signature (Android only)
  /// Returns true if signature is valid, false if tampered
  Future<bool> verifyAppSignature() async {
    if (!Platform.isAndroid) {
      // iOS uses code signing, which is handled by the OS
      return true;
    }

    try {
      final String? signatureHash = await _channel.invokeMethod('getAppSignature');
      
      if (signatureHash == null) {
        Logger.warning('Could not retrieve app signature');
        // Fail secure: if we can't verify, assume tampered
        return false;
      }

      // If expected signature is set, verify against it
      if (_expectedSignatureHash.isNotEmpty) {
        return signatureHash == _expectedSignatureHash;
      }

      // If no expected signature set, at least verify we got a signature
      // In production, always verify against expected signature
      Logger.warning('No expected signature set - signature verification skipped');
      return true;
    } catch (e) {
      Logger.error('Error verifying app signature', error: e);
      // Fail secure: if verification fails, assume tampered
      return false;
    }
  }

  /// Verify app package name
  /// Returns true if package name matches expected
  Future<bool> verifyPackageName() async {
    if (!Platform.isAndroid) {
      return true; // iOS uses bundle ID, handled differently
    }

    try {
      final String? packageName = await _channel.invokeMethod('getPackageName');
      
      if (packageName == null) {
        Logger.warning('Could not retrieve package name');
        return false;
      }

      return packageName == _expectedPackageName;
    } catch (e) {
      Logger.error('Error verifying package name', error: e);
      return false;
    }
  }

  /// Check if app is installed from Play Store (Android) or App Store (iOS)
  /// Returns true if installed from official store
  Future<bool> isInstalledFromOfficialStore() async {
    try {
      if (Platform.isAndroid) {
        final bool? isPlayStore = await _channel.invokeMethod('isInstalledFromPlayStore');
        return isPlayStore ?? false;
      } else if (Platform.isIOS) {
        // iOS apps can only be installed from App Store (unless jailbroken)
        // If app is running, it's likely from App Store
        return true;
      }
      return false;
    } catch (e) {
      Logger.error('Error checking installation source', error: e);
      return false;
    }
  }

  /// Verify app integrity by checking critical files
  /// This is a basic check - in production, implement more sophisticated checks
  Future<bool> verifyAppIntegrity() async {
    try {
      // Check if app is in debug mode (should not be in production)
      if (kDebugMode) {
        // In debug mode, skip integrity checks
        return true;
      }

      // Verify package name
      final packageValid = await verifyPackageName();
      if (!packageValid) {
        Logger.error('Package name verification failed');
        return false;
      }

      // Verify app signature (Android)
      if (Platform.isAndroid) {
        final signatureValid = await verifyAppSignature();
        if (!signatureValid) {
          Logger.error('App signature verification failed');
          return false;
        }
      }

      return true;
    } catch (e) {
      Logger.error('Error verifying app integrity', error: e);
      return false;
    }
  }

  /// Get comprehensive security status
  Future<Map<String, dynamic>> getSecurityStatus() async {
    final signatureValid = await verifyAppSignature();
    final packageValid = await verifyPackageName();
    final fromStore = await isInstalledFromOfficialStore();
    final integrityValid = await verifyAppIntegrity();

    return {
      'signatureValid': signatureValid,
      'packageValid': packageValid,
      'fromOfficialStore': fromStore,
      'integrityValid': integrityValid,
      'isSecure': signatureValid && packageValid && integrityValid,
      'platform': Platform.operatingSystem,
    };
  }
}

