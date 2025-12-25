import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/providers.dart';
import '../services/api_service.dart';

/// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  
  // Initialize Firebase for background handler
  await Firebase.initializeApp();
  
  // Initialize local notifications for background handler
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  
  final FlutterLocalNotificationsPlugin localNotifications = 
      FlutterLocalNotificationsPlugin();
  await localNotifications.initialize(initializationSettings);
  
  // Create notification channel for Android (must be done before showing notification)
  if (Platform.isAndroid) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ewallet_notifications',
      'E-Wallet Notifications',
      description: 'Notifications for transactions and alerts',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(channel);
  }
  
  // Show notification
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'ewallet_notifications',
    'E-Wallet Notifications',
    channelDescription: 'Notifications for transactions and alerts',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
    playSound: true,
    enableVibration: true,
  );
  
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  
  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );
  
  await localNotifications.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    message.notification?.title ?? 'E-Wallet',
    message.notification?.body ?? '',
    notificationDetails,
  );
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

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

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request notification permissions
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
      } else if (Platform.isAndroid) {
        // Request notification permission for Android 13+
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          final bool? granted = await androidImplementation.requestNotificationsPermission();
          debugPrint('Android notification permission granted: $granted');
        }
      }

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Get FCM token
      try {
        _fcmToken = await _firebaseMessaging!.getToken();
        debugPrint('FCM Token: $_fcmToken');
        
        if (_fcmToken == null) {
          debugPrint('⚠️ WARNING: FCM token is null. This usually means:');
          debugPrint('   1. Android emulator without Google Play Services');
          debugPrint('   2. Firebase not properly configured');
          debugPrint('   3. Network connectivity issues');
          debugPrint('   Solution: Use an emulator with Google Play Services or test on a physical device');
        }
      } catch (e) {
        debugPrint('❌ ERROR: Failed to get FCM token: $e');
        debugPrint('   This is common on Android emulators without Google Play Services.');
        debugPrint('   To test notifications:');
        debugPrint('   - Use an emulator with Google APIs (includes Play Services)');
        debugPrint('   - Or test on a physical Android device');
        return; // Exit if we can't get token
      }

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
      FirebaseMessaging.onMessage.listen((message) async {
        if (context != null && context.mounted) {
          await _handleForegroundMessage(message, context);
        } else {
          // Still show notification even without context
          await _showNotification(
            title: message.notification?.title ?? 'E-Wallet',
            body: message.notification?.body ?? '',
            data: message.data,
          );
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

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
        // Handle notification tap if needed
      },
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'ewallet_notifications', // id
        'E-Wallet Notifications', // name
        description: 'Notifications for transactions and alerts',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.createNotificationChannel(channel);
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
  Future<void> _handleForegroundMessage(RemoteMessage message, BuildContext? context) async {
    debugPrint('Received foreground message: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Display notification
    await _showNotification(
      title: message.notification?.title ?? 'E-Wallet',
      body: message.notification?.body ?? '',
      data: message.data,
    );

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
  }

  /// Show local notification
  Future<void> _showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('Attempting to show notification: $title - $body');
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'ewallet_notifications',
        'E-Wallet Notifications',
        channelDescription: 'Notifications for transactions and alerts',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: data != null ? data.toString() : null,
      );
      
      debugPrint('Notification shown successfully');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
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
