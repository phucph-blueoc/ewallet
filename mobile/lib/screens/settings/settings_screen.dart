import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/biometric_service.dart';
import 'change_password_screen.dart';
import 'security_settings_screen.dart';
import 'transaction_pin_screen.dart';
import '../security/device_management_screen.dart';
import '../security/security_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _biometricEnabled = false;
  bool _isBiometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    });

    final isAvailable = await _biometricService.isAvailable();
    final available = await _biometricService.getAvailableBiometrics();
    
    setState(() {
      _isBiometricAvailable = isAvailable;
      _availableBiometrics = available;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Request authentication to enable biometric
      final authenticated = await _biometricService.authenticate(
        reason: 'Bật xác thực sinh trắc học cho ví của bạn',
      );

      if (!authenticated) {
        return; // User cancelled or failed
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);

    setState(() {
      _biometricEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Xác thực sinh trắc học đã được bật'
                : 'Xác thực sinh trắc học đã được tắt',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
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
      appBar: AppBar(
        title: const Text('Cài Đặt'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Security Section
          Text(
            'Bảo Mật',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Đổi Mật Khẩu'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.vpn_key),
                  title: const Text('Mã PIN Giao Dịch'),
                  subtitle: const Text('Thiết lập hoặc cập nhật PIN cho chuyển tiền'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TransactionPinScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(
                    biometricType == BiometricType.face
                        ? Icons.face
                        : Icons.fingerprint,
                  ),
                  title: Text('$biometricName Authentication'),
                  subtitle: Text(
                    _isBiometricAvailable
                        ? 'Sử dụng $biometricName để mở khóa ví của bạn'
                        : '$biometricName không khả dụng trên thiết bị này',
                  ),
                  value: _biometricEnabled && _isBiometricAvailable,
                  onChanged: _isBiometricAvailable ? _toggleBiometric : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Cài Đặt Bảo Mật'),
                  subtitle: const Text('Trạng thái và tính năng bảo mật thiết bị'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SecuritySettingsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.devices),
                  title: const Text('Quản Lý Thiết Bị'),
                  subtitle: const Text('Xem và quản lý các thiết bị đã đăng nhập'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeviceManagementScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Lịch Sử Bảo Mật'),
                  subtitle: const Text('Xem lịch sử các hoạt động bảo mật'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SecurityHistoryScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // About Section
          Text(
            'Về Ứng Dụng',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Phiên Bản Ứng Dụng'),
              subtitle: const Text('1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}


