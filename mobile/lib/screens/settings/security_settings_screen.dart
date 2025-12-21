import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/security_service.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final SecurityService _securityService = SecurityService();
  Map<String, dynamic>? _securityStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSecurityStatus();
  }

  Future<void> _loadSecurityStatus() async {
    final status = await _securityService.getSecurityStatus();
    setState(() {
      _securityStatus = status;
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài Đặt Bảo Mật'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Device Security Status
                Text(
                  'Bảo Mật Thiết Bị',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _securityStatus?['isSecure'] == true
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: _securityStatus?['isSecure'] == true
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _securityStatus?['isSecure'] == true
                                    ? 'Thiết Bị An Toàn'
                                    : 'Cảnh Báo Bảo Mật',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_securityStatus?['isCompromised'] == true)
                          _buildStatusItem(
                            'Trạng Thái Thiết Bị',
                            '${_securityStatus?['platform'] == 'android' ? 'Đã Root' : 'Đã Jailbreak'}',
                            Colors.red,
                          ),
                        if (_securityStatus?['hasDeveloperOptions'] == true)
                          _buildStatusItem(
                            'Tùy Chọn Nhà Phát Triển',
                            'Đã Bật',
                            Colors.orange,
                          ),
                        if (_securityStatus?['isSecure'] == true)
                          _buildStatusItem(
                            'Trạng Thái Thiết Bị',
                            'An Toàn',
                            Colors.green,
                          ),
                          _buildStatusItem(
                            'Nền Tảng',
                            _securityStatus?['platform']?.toString().toUpperCase() ?? 'Không Xác Định',
                            Colors.blue,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Security Features
                Text(
                  'Tính Năng Bảo Mật',
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
                        title: const Text('Ghim Chứng Chỉ'),
                        subtitle: const Text('Bảo vệ chống tấn công MITM'),
                        trailing: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.security),
                        title: const Text('Phát Hiện Root/Jailbreak'),
                        subtitle: const Text('Cảnh báo về thiết bị đã bị xâm phạm'),
                        trailing: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.vpn_key),
                        title: const Text('Bàn Phím An Toàn'),
                        subtitle: const Text('Bảo mật nhập PIN nâng cao'),
                        trailing: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Actions
                Text(
                  'Hành Động',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.refresh),
                    title: const Text('Làm Mới Trạng Thái Bảo Mật'),
                    onTap: _loadSecurityStatus,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Đăng Xuất',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: _handleLogout,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

