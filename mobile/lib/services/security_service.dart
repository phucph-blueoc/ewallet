import 'dart:io';
import 'package:root_detector/root_detector.dart';
import 'anti_tampering_service.dart';
import '../utils/logger.dart';

/// Comprehensive security service that combines:
/// - Root/jailbreak detection
/// - Anti-tampering checks (app signature, integrity)
/// - Developer options detection
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final _antiTamperingService = AntiTamperingService();

  /// Check if device is rooted (Android) or jailbroken (iOS)
  Future<bool> isDeviceCompromised() async {
    try {
      if (Platform.isAndroid) {
        return await RootDetector.isRooted();
      } else if (Platform.isIOS) {
        // iOS jailbreak detection - root_detector may not support iOS
        // For now, return false (can be enhanced with other packages)
        return false;
      }
      return false;
    } catch (e) {
      Logger.error('Error checking device compromise status', error: e);
      // If detection fails, assume safe (fail open)
      return false;
    }
  }

  /// Check if device has developer options enabled (Android)
  Future<bool> hasDeveloperOptionsEnabled() async {
    try {
      if (Platform.isAndroid) {
        // root_detector doesn't have this method, return false for now
        // Can be enhanced with additional checks
        return false;
      }
      return false;
    } catch (e) {
      Logger.error('Error checking developer options', error: e);
      return false;
    }
  }

  /// Check if app has been tampered with
  /// Returns true if app integrity is compromised
  Future<bool> isAppTampered() async {
    try {
      final integrityValid = await _antiTamperingService.verifyAppIntegrity();
      return !integrityValid;
    } catch (e) {
      Logger.error('Error checking app tampering', error: e);
      // Fail secure: if we can't verify, assume tampered
      return true;
    }
  }

  /// Verify app signature (Android only)
  Future<bool> verifyAppSignature() async {
    try {
      return await _antiTamperingService.verifyAppSignature();
    } catch (e) {
      Logger.error('Error verifying app signature', error: e);
      return false;
    }
  }

  /// Check if app is installed from official store
  Future<bool> isInstalledFromOfficialStore() async {
    try {
      return await _antiTamperingService.isInstalledFromOfficialStore();
    } catch (e) {
      Logger.error('Error checking installation source', error: e);
      return false;
    }
  }

  /// Comprehensive security check
  /// Returns true if all security checks pass
  Future<bool> performSecurityCheck() async {
    try {
      final isCompromised = await isDeviceCompromised();
      if (isCompromised) {
        Logger.warning('Device is compromised (rooted/jailbroken)');
        return false;
      }

      final isTampered = await isAppTampered();
      if (isTampered) {
        Logger.error('App integrity check failed - app may be tampered');
        return false;
      }

      return true;
    } catch (e) {
      Logger.error('Error performing security check', error: e);
      return false;
    }
  }

  /// Get comprehensive security status report
  Future<Map<String, dynamic>> getSecurityStatus() async {
    final isCompromised = await isDeviceCompromised();
    final hasDevOptions = await hasDeveloperOptionsEnabled();
    final isTampered = await isAppTampered();
    final signatureValid = await verifyAppSignature();
    final fromStore = await isInstalledFromOfficialStore();
    final antiTamperingStatus = await _antiTamperingService.getSecurityStatus();

    final isSecure = !isCompromised && !hasDevOptions && !isTampered && signatureValid;

    return {
      'isCompromised': isCompromised,
      'hasDeveloperOptions': hasDevOptions,
      'isTampered': isTampered,
      'signatureValid': signatureValid,
      'fromOfficialStore': fromStore,
      'isSecure': isSecure,
      'platform': Platform.operatingSystem,
      'antiTampering': antiTamperingStatus,
    };
  }
}

