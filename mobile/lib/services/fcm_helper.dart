/// Helper to ensure FCM token is registered after login
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fcm_service.dart';
import '../providers/providers.dart';
import 'api_service.dart';
import '../utils/logger.dart';

/// Register FCM token if available and user is authenticated
Future<void> ensureFCMTokenRegistered(BuildContext? context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('fcm_token');
    
    if (savedToken == null || savedToken.isEmpty) {
      Logger.debug('No saved FCM token found');
      return;
    }
    
    // Check if user is authenticated
    bool isAuthenticated = false;
    if (context != null) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        isAuthenticated = authProvider.isAuthenticated;
      } catch (e) {
        Logger.warning('Could not check auth status', error: e);
      }
    }
    
    if (!isAuthenticated) {
      // Try to check via API token
      final apiService = ApiService();
      final token = await apiService.getAccessToken();
      isAuthenticated = token != null && token.isNotEmpty;
    }
    
    if (isAuthenticated) {
      final fcmService = FCMService();
      final deviceType = fcmService.getDeviceType();
      final apiService = ApiService();
      
      try {
        await apiService.registerDevice(
          deviceToken: savedToken,
          deviceType: deviceType,
        );
        Logger.info('Successfully registered FCM token after login');
      } catch (e) {
        Logger.error('Failed to register FCM token', error: e);
      }
    }
  } catch (e) {
    Logger.error('Error ensuring FCM token registration', error: e);
  }
}


