import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';

/// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  // Handle background message here
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final ApiService _apiService = ApiService();

  String? _fcmToken;
  bool _initialized = false;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _initialized;

  /// Initialize FCM service
  Future<void> initialize(BuildContext? context) async {
    if (_initialized) return;

    try {
      // Check if Firebase is initialized
      try {
        Firebase.app(); // This will throw if Firebase is not initialized
      } catch (e) {
        debugPrint('Firebase not initialized. Attempting to initialize...');
        try {
          await Firebase.initializeApp();
          debugPrint('Firebase initialized successfully in FCM service');
        } catch (initError) {
          debugPrint('Failed to initialize Firebase: $initError');
          debugPrint(
            'FCM will not be available. App can continue without push notifications.',
          );
          return; // Exit early if Firebase can't be initialized
        }
      }

      // Initialize FirebaseMessaging only if Firebase is available
      try {
        _firebaseMessaging = FirebaseMessaging.instance;
      } catch (e) {
        debugPrint('Failed to get FirebaseMessaging instance: $e');
        return;
      }

      if (_firebaseMessaging == null) {
        debugPrint('FirebaseMessaging is null. FCM unavailable.');
        return;
      }

      // Request permission for iOS
      if (Platform.isIOS) {
        NotificationSettings settings = await _firebaseMessaging!
            .requestPermission(
              alert: true,
              badge: true,
              sound: true,
              provisional: false,
            );

        if (settings.authorizationStatus != AuthorizationStatus.authorized) {
          debugPrint(
            'User declined or has not accepted notification permissions',
          );
          return;
        }
      }

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Get FCM token
      _fcmToken = await _firebaseMessaging!.getToken();
      debugPrint('FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        // Save token locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);

        // Register token with backend if user is authenticated
        // Try to register even if context is not available (for background/refresh cases)
        try {
          if (context != null) {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            if (authProvider.isAuthenticated) {
              await _registerTokenWithBackend(_fcmToken!);
            }
          } else {
            // If no context, try to register anyway (will fail gracefully if not authenticated)
            await _registerTokenWithBackend(_fcmToken!);
          }
        } catch (e) {
          debugPrint('Failed to register token on initialization: $e');
          // Token will be registered later when user logs in or when token refresh happens
        }
      }

      // Listen for token refresh
      _firebaseMessaging!.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _fcmToken = newToken;
        _registerTokenWithBackend(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((message) {
        if (context != null && context.mounted) {
          _handleForegroundMessage(message, context);
        } else {
          // If context is not available, just log the message
          debugPrint('Received foreground message but context not available');
        }
      });

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (context != null && context.mounted) {
          _handleNotificationTap(message, context: context);
        }
      });

      // Check if app was opened from a notification (terminated state)
      RemoteMessage? initialMessage = await _firebaseMessaging!
          .getInitialMessage();
      if (initialMessage != null && context != null) {
        _handleNotificationTap(initialMessage, context: context);
      }

      _initialized = true;
      debugPrint('FCM Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  }

  /// Register FCM token with backend
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final deviceType = Platform.isIOS ? 'IOS' : 'ANDROID';
      await _apiService.registerDevice(
        deviceToken: token,
        deviceType: deviceType,
      );
      debugPrint('FCM token registered with backend');
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message, BuildContext? context) {
    debugPrint('Received foreground message: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Refresh notifications count when receiving a notification
    if (context != null) {
      try {
        final notificationProvider = Provider.of<NotificationProvider>(
          context,
          listen: false,
        );
        notificationProvider.refreshUnreadCount();
      } catch (e) {
        debugPrint('Error refreshing notification count: $e');
      }
    }

    // Show in-app notification or snackbar
    // For now, we'll just log it. You can add flutter_local_notifications for better UX
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message, {BuildContext? context}) {
    debugPrint('Notification tapped: ${message.messageId}');
    debugPrint('Data: ${message.data}');

    // Navigate based on notification data
    if (context != null) {
      final data = message.data;

      // Refresh notifications if user taps on a notification
      try {
        final notificationProvider = Provider.of<NotificationProvider>(
          context,
          listen: false,
        );
        notificationProvider.loadNotifications();
        notificationProvider.refreshUnreadCount();
      } catch (e) {
        debugPrint('Error refreshing notifications: $e');
      }

      // Navigate based on notification type
      // Note: Navigation will be handled by the app's navigation structure
      // You can implement custom navigation logic here based on your needs
      debugPrint('Notification type: ${data['type']}');
    }
  }

  /// Get device type for registration
  String getDeviceType() {
    if (Platform.isIOS) return 'IOS';
    if (Platform.isAndroid) return 'ANDROID';
    return 'WEB';
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    if (_firebaseMessaging == null) return;
    try {
      await _firebaseMessaging!.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_firebaseMessaging == null) return;
    try {
      await _firebaseMessaging!.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }

  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    if (_firebaseMessaging == null) return;
    try {
      await _firebaseMessaging!.deleteToken();
      _fcmToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      debugPrint('FCM token deleted');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }
}
