import 'package:flutter/material.dart';
import 'auth_exception.dart';
import 'navigation_helper.dart';

/// Wrapper to handle UnauthorizedException and navigate to login
Future<T> handleApiCall<T>(
  BuildContext? context,
  Future<T> Function() apiCall,
) async {
  try {
    return await apiCall();
  } on UnauthorizedException {
    if (context != null) {
      await handleUnauthorized(context);
    }
    rethrow;
  }
}

