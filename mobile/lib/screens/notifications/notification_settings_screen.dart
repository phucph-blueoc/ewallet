import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _enableTransaction = true;
  bool _enablePromotion = true;
  bool _enableSecurity = true;
  bool _enableAlert = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    final provider = context.read<NotificationProvider>();
    await provider.loadSettings();
    final settings = provider.settings;
    if (settings != null) {
      setState(() {
        _enableTransaction = settings.enableTransactionNotifications;
        _enablePromotion = settings.enablePromotionNotifications;
        _enableSecurity = settings.enableSecurityNotifications;
        _enableAlert = settings.enableAlertNotifications;
      });
    }
  }

  Future<void> _saveSettings() async {
    final provider = context.read<NotificationProvider>();
    await provider.updateSettings(
      enableTransactionNotifications: _enableTransaction,
      enablePromotionNotifications: _enablePromotion,
      enableSecurityNotifications: _enableSecurity,
      enableAlertNotifications: _enableAlert,
    );

    if (mounted && provider.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật cài đặt thông báo'),
          backgroundColor: Color(0xFF00FF88),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài Đặt Thông Báo'),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.settings == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Loại Thông Báo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D4FF),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSwitchTile(
                        title: 'Thông báo giao dịch',
                        subtitle: 'Nhận thông báo khi có giao dịch mới',
                        icon: Icons.payment,
                        value: _enableTransaction,
                        onChanged: (value) {
                          setState(() {
                            _enableTransaction = value;
                          });
                          _saveSettings();
                        },
                      ),
                      const Divider(),
                      _buildSwitchTile(
                        title: 'Thông báo khuyến mãi',
                        subtitle: 'Nhận thông báo về các chương trình khuyến mãi',
                        icon: Icons.local_offer,
                        value: _enablePromotion,
                        onChanged: (value) {
                          setState(() {
                            _enablePromotion = value;
                          });
                          _saveSettings();
                        },
                      ),
                      const Divider(),
                      _buildSwitchTile(
                        title: 'Thông báo bảo mật',
                        subtitle: 'Nhận thông báo về các hoạt động bảo mật',
                        icon: Icons.security,
                        value: _enableSecurity,
                        onChanged: (value) {
                          setState(() {
                            _enableSecurity = value;
                          });
                          _saveSettings();
                        },
                      ),
                      const Divider(),
                      _buildSwitchTile(
                        title: 'Thông báo cảnh báo',
                        subtitle: 'Nhận thông báo về các cảnh báo quan trọng',
                        icon: Icons.warning,
                        value: _enableAlert,
                        onChanged: (value) {
                          setState(() {
                            _enableAlert = value;
                          });
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (provider.settings?.deviceToken != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thiết Bị',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00D4FF),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Loại: ${provider.settings?.deviceType ?? "N/A"}',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Token: ${provider.settings?.deviceToken?.substring(0, 20) ?? "N/A"}...',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Row(
        children: [
          Icon(icon, color: const Color(0xFF00D4FF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 32, top: 4),
        child: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF00D4FF),
    );
  }
}

