import 'dart:io';
import 'package:root_detector/root_detector.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

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
      return false;
    }
  }

  /// Get security status report
  Future<Map<String, dynamic>> getSecurityStatus() async {
    final isCompromised = await isDeviceCompromised();
    final hasDevOptions = await hasDeveloperOptionsEnabled();

    return {
      'isCompromised': isCompromised,
      'hasDeveloperOptions': hasDevOptions,
      'isSecure': !isCompromised && !hasDevOptions,
      'platform': Platform.operatingSystem,
    };
  }
}

