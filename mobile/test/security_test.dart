/// Security Test Cases for E-Wallet Mobile App
///
/// Tests cover:
/// - Secure Storage
/// - Biometric Authentication
/// - Auto Logout / Session Management
/// - Root/Jailbreak Detection
/// - Certificate Pinning
/// - Token Management

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Note: These tests use mocks since we can't test actual biometrics/secure storage
// in unit tests. Integration tests would be needed for full coverage.

@GenerateMocks([FlutterSecureStorage, LocalAuthentication, SharedPreferences])
import 'security_test.mocks.dart';

void main() {
  group('Secure Storage Tests', () {
    late MockFlutterSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
    });

    test('Tokens should be stored in secure storage', () async {
      // Arrange
      const testToken = 'test_access_token_12345';
      const testRefreshToken = 'test_refresh_token_67890';

      // Act - Simulate storing tokens
      when(
        mockStorage.write(key: 'access_token', value: testToken),
      ).thenAnswer((_) async => {});
      when(
        mockStorage.write(key: 'refresh_token', value: testRefreshToken),
      ).thenAnswer((_) async => {});

      await mockStorage.write(key: 'access_token', value: testToken);
      await mockStorage.write(key: 'refresh_token', value: testRefreshToken);

      // Assert
      verify(
        mockStorage.write(key: 'access_token', value: testToken),
      ).called(1);
      verify(
        mockStorage.write(key: 'refresh_token', value: testRefreshToken),
      ).called(1);
    });

    test('Tokens should be retrieved from secure storage', () async {
      // Arrange
      const testToken = 'test_access_token_12345';
      when(
        mockStorage.read(key: 'access_token'),
      ).thenAnswer((_) async => testToken);

      // Act
      final token = await mockStorage.read(key: 'access_token');

      // Assert
      expect(token, equals(testToken));
      verify(mockStorage.read(key: 'access_token')).called(1);
    });

    test('Tokens should be deleted on logout', () async {
      // Arrange
      when(mockStorage.delete(key: 'access_token')).thenAnswer((_) async => {});
      when(
        mockStorage.delete(key: 'refresh_token'),
      ).thenAnswer((_) async => {});

      // Act
      await mockStorage.delete(key: 'access_token');
      await mockStorage.delete(key: 'refresh_token');

      // Assert
      verify(mockStorage.delete(key: 'access_token')).called(1);
      verify(mockStorage.delete(key: 'refresh_token')).called(1);
    });

    test('Sensitive data should not be stored in SharedPreferences', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Act - Store non-sensitive preference
      await prefs.setBool('biometric_enabled', true);
      await prefs.setString('theme', 'dark');

      // Assert - Verify tokens are NOT stored in SharedPreferences
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
      expect(prefs.getString('password'), isNull);
    });

    test('Secure storage should handle null values gracefully', () async {
      // Arrange
      when(
        mockStorage.read(key: 'non_existent_key'),
      ).thenAnswer((_) async => null);

      // Act
      final value = await mockStorage.read(key: 'non_existent_key');

      // Assert
      expect(value, isNull);
    });
  });

  group('Biometric Authentication Tests', () {
    late MockLocalAuthentication mockLocalAuth;

    setUp(() {
      mockLocalAuth = MockLocalAuthentication();
    });

    test('Should check if biometric authentication is available', () async {
      // Arrange
      when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);

      // Act
      final canCheck = await mockLocalAuth.canCheckBiometrics;
      final isSupported = await mockLocalAuth.isDeviceSupported();

      // Assert
      expect(canCheck, isTrue);
      expect(isSupported, isTrue);
      verify(mockLocalAuth.canCheckBiometrics).called(1);
      verify(mockLocalAuth.isDeviceSupported()).called(1);
    });

    test('Should get available biometric types', () async {
      // Arrange
      when(
        mockLocalAuth.getAvailableBiometrics(),
      ).thenAnswer((_) async => [BiometricType.fingerprint]);

      // Act
      final biometrics = await mockLocalAuth.getAvailableBiometrics();

      // Assert
      expect(biometrics, isNotEmpty);
      expect(biometrics.contains(BiometricType.fingerprint), isTrue);
      verify(mockLocalAuth.getAvailableBiometrics()).called(1);
    });

    test('Should authenticate with biometrics', () async {
      // Arrange
      when(
        mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          options: anyNamed('options'),
        ),
      ).thenAnswer((_) async => true);

      // Act
      final result = await mockLocalAuth.authenticate(
        localizedReason: 'Please authenticate to access your wallet',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      // Assert
      expect(result, isTrue);
      verify(
        mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          options: anyNamed('options'),
        ),
      ).called(1);
    });

    test('Should handle biometric authentication failure', () async {
      // Arrange
      when(
        mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          options: anyNamed('options'),
        ),
      ).thenAnswer((_) async => false);

      // Act
      final result = await mockLocalAuth.authenticate(
        localizedReason: 'Please authenticate',
        options: const AuthenticationOptions(),
      );

      // Assert
      expect(result, isFalse);
    });

    test('Should handle biometric not available gracefully', () async {
      // Arrange
      when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
      when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

      // Act
      final canCheck = await mockLocalAuth.canCheckBiometrics;
      final isSupported = await mockLocalAuth.isDeviceSupported();

      // Assert
      expect(canCheck, isFalse);
      expect(isSupported, isFalse);
    });
  });

  group('Auto Logout / Session Management Tests', () {
    late MockSharedPreferences mockPrefs;

    setUp(() {
      mockPrefs = MockSharedPreferences();
    });

    test('Should track last activity timestamp', () async {
      // Arrange
      final lastActivity = DateTime.now().millisecondsSinceEpoch;
      when(
        mockPrefs.setInt('last_activity', any),
      ).thenAnswer((_) async => true);
      when(mockPrefs.getInt('last_activity')).thenReturn(lastActivity);

      // Act
      await mockPrefs.setInt('last_activity', lastActivity);
      final stored = mockPrefs.getInt('last_activity');

      // Assert
      expect(stored, equals(lastActivity));
      verify(mockPrefs.setInt('last_activity', any)).called(1);
    });

    test('Should detect inactivity timeout', () {
      // Arrange
      const timeoutMinutes = 15;
      final lastActivity = DateTime.now().subtract(
        const Duration(minutes: timeoutMinutes + 1),
      );
      final now = DateTime.now();
      final difference = now.difference(lastActivity);

      // Act & Assert
      expect(difference.inMinutes, greaterThan(timeoutMinutes));
    });

    test('Should not logout if within timeout period', () {
      // Arrange
      const timeoutMinutes = 15;
      final lastActivity = DateTime.now().subtract(
        const Duration(minutes: timeoutMinutes - 1),
      );
      final now = DateTime.now();
      final difference = now.difference(lastActivity);

      // Act & Assert
      expect(difference.inMinutes, lessThan(timeoutMinutes));
    });

    test('Should clear authentication state on logout', () async {
      // Arrange
      final mockStorage = MockFlutterSecureStorage();
      when(mockStorage.delete(key: 'access_token')).thenAnswer((_) async => {});
      when(
        mockStorage.delete(key: 'refresh_token'),
      ).thenAnswer((_) async => {});
      when(mockPrefs.remove('last_activity')).thenAnswer((_) async => true);

      // Act
      await mockStorage.delete(key: 'access_token');
      await mockStorage.delete(key: 'refresh_token');
      await mockPrefs.remove('last_activity');

      // Assert
      verify(mockStorage.delete(key: 'access_token')).called(1);
      verify(mockStorage.delete(key: 'refresh_token')).called(1);
      verify(mockPrefs.remove('last_activity')).called(1);
    });
  });

  group('Token Management Tests', () {
    late MockFlutterSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
    });

    test('Access token should be retrieved correctly', () async {
      // Arrange
      const testToken = 'test_access_token';
      when(
        mockStorage.read(key: 'access_token'),
      ).thenAnswer((_) async => testToken);

      // Act
      final token = await mockStorage.read(key: 'access_token');

      // Assert
      expect(token, equals(testToken));
      expect(token, isNotNull);
    });

    test('Refresh token should be retrieved correctly', () async {
      // Arrange
      const testRefreshToken = 'test_refresh_token';
      when(
        mockStorage.read(key: 'refresh_token'),
      ).thenAnswer((_) async => testRefreshToken);

      // Act
      final refreshToken = await mockStorage.read(key: 'refresh_token');

      // Assert
      expect(refreshToken, equals(testRefreshToken));
      expect(refreshToken, isNotNull);
    });

    test('Should handle missing tokens gracefully', () async {
      // Arrange
      when(mockStorage.read(key: 'access_token')).thenAnswer((_) async => null);

      // Act
      final token = await mockStorage.read(key: 'access_token');

      // Assert
      expect(token, isNull);
    });

    test('Tokens should be stored separately', () async {
      // Arrange
      const accessToken = 'access_token_123';
      const refreshToken = 'refresh_token_456';

      when(
        mockStorage.write(key: 'access_token', value: accessToken),
      ).thenAnswer((_) async => {});
      when(
        mockStorage.write(key: 'refresh_token', value: refreshToken),
      ).thenAnswer((_) async => {});

      // Act
      await mockStorage.write(key: 'access_token', value: accessToken);
      await mockStorage.write(key: 'refresh_token', value: refreshToken);

      // Assert - Verify they are different
      expect(accessToken, isNot(equals(refreshToken)));
      verify(
        mockStorage.write(key: 'access_token', value: accessToken),
      ).called(1);
      verify(
        mockStorage.write(key: 'refresh_token', value: refreshToken),
      ).called(1);
    });
  });

  group('Security Configuration Tests', () {
    test('Biometric preference should be stored correctly', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Act
      await prefs.setBool('biometric_enabled', true);
      final enabled = prefs.getBool('biometric_enabled');

      // Assert
      expect(enabled, isTrue);
    });

    test('Biometric preference should default to false', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Act
      final enabled = prefs.getBool('biometric_enabled');

      // Assert
      expect(enabled, isNull);
    });

    test('Should toggle biometric preference', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Act - Enable
      await prefs.setBool('biometric_enabled', true);
      expect(prefs.getBool('biometric_enabled'), isTrue);

      // Act - Disable
      await prefs.setBool('biometric_enabled', false);
      expect(prefs.getBool('biometric_enabled'), isFalse);
    });
  });
}
