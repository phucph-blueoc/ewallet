import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/biometric_service.dart';
import 'login_screen.dart';
import '../wallet/wallet_home_screen.dart';

class BiometricAuthScreen extends StatefulWidget {
  const BiometricAuthScreen({super.key});

  @override
  State<BiometricAuthScreen> createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;
  String? _errorMessage;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _authenticate();
  }

  Future<void> _checkBiometrics() async {
    final available = await _biometricService.getAvailableBiometrics();
    setState(() {
      _availableBiometrics = available;
    });
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final isAvailable = await _biometricService.isAvailable();
    if (!isAvailable) {
      // Biometric not available, skip to wallet
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WalletHomeScreen()),
        );
      }
      return;
    }

    final didAuthenticate = await _biometricService.authenticate(
      reason: 'Xác thực để truy cập ví của bạn',
    );

    if (!mounted) return;

    if (didAuthenticate) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WalletHomeScreen()),
      );
    } else {
      setState(() {
        _isAuthenticating = false;
        _errorMessage = 'Xác thực thất bại. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _skipToLogin() async {
    // User wants to login with password instead
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final biometricType = _availableBiometrics.isNotEmpty
        ? _availableBiometrics.first
        : null;
    final biometricName = biometricType != null
        ? _biometricService.getBiometricTypeName(biometricType)
        : 'Biometric';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                biometricType == BiometricType.face
                    ? Icons.face
                    : Icons.fingerprint,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Mở Khóa Bằng $biometricName',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Sử dụng $biometricName của bạn để truy cập ví một cách an toàn',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (_isAuthenticating)
                const CircularProgressIndicator()
              else if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              FilledButton.icon(
                onPressed: _isAuthenticating ? null : _authenticate,
                icon: Icon(
                  biometricType == BiometricType.face
                      ? Icons.face
                      : Icons.fingerprint,
                ),
                label: const Text('Xác Thực'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _skipToLogin,
                child: const Text('Sử Dụng Mật Khẩu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

