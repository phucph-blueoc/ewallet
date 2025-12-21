import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/auth/login_screen.dart';
import '../providers/providers.dart';
import 'package:provider/provider.dart';

/// Helper to handle 401 Unauthorized and navigate to login
Future<void> handleUnauthorized(BuildContext? context) async {
  // Get context from navigator key if not provided
  final ctx = context ?? navigatorKey.currentContext;
  if (ctx == null) return;

  // Logout user
  await ctx.read<AuthProvider>().logout();

  // Navigate to login screen and clear all previous routes
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );

  // Show notification
  if (ctx.mounted) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Text('Phiên đã hết hạn. Vui lòng đăng nhập lại.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

