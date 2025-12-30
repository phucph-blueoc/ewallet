import 'package:flutter/foundation.dart';

/// Logger utility that disables debug logging in release builds
/// 
/// Usage:
/// ```dart
/// Logger.debug('Debug message');
/// Logger.info('Info message');
/// Logger.warning('Warning message');
/// Logger.error('Error message', error: e, stackTrace: stackTrace);
/// ```
class Logger {
  /// Debug level logging - only shown in debug mode
  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      if (error != null) {
        debugPrint('🔵 [DEBUG] $message');
        debugPrint('   Error: $error');
        if (stackTrace != null) {
          debugPrint('   StackTrace: $stackTrace');
        }
      } else {
        debugPrint('🔵 [DEBUG] $message');
      }
    }
  }

  /// Info level logging - shown in debug mode only
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ [INFO] $message');
    }
  }

  /// Warning level logging - shown in debug mode only
  static void warning(String message, {Object? error}) {
    if (kDebugMode) {
      if (error != null) {
        debugPrint('⚠️ [WARNING] $message');
        debugPrint('   Error: $error');
      } else {
        debugPrint('⚠️ [WARNING] $message');
      }
    }
  }

  /// Error level logging - shown in debug mode only
  /// In production, errors should be logged to crash reporting service
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('❌ [ERROR] $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('   StackTrace: $stackTrace');
      }
    }
    // In production, send to crash reporting service (Firebase Crashlytics, Sentry, etc.)
    // Example: FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  /// Print sensitive data - NEVER logs in production, only in debug mode
  static void sensitive(String message) {
    if (kDebugMode) {
      debugPrint('🔒 [SENSITIVE] $message');
    }
  }
}

