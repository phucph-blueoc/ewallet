import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';

class AlertSettingsScreen extends StatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  final _largeTransactionController = TextEditingController();
  final _lowBalanceController = TextEditingController();
  final _budgetWarningController = TextEditingController();
  
  bool _enableLargeTransaction = true;
  bool _enableLowBalance = true;
  bool _enableBudget = true;
  bool _enableNewDevice = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  @override
  void dispose() {
    _largeTransactionController.dispose();
    _lowBalanceController.dispose();
    _budgetWarningController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final provider = context.read<AlertProvider>();
    await provider.loadSettings();
    final settings = provider.settings;
    if (settings != null) {
      setState(() {
        _largeTransactionController.text = settings.largeTransactionThreshold?.toString() ?? '';
        _lowBalanceController.text = settings.lowBalanceThreshold?.toString() ?? '';
        _budgetWarningController.text = settings.budgetWarningPercentage.toString();
        _enableLargeTransaction = settings.enableLargeTransactionAlert;
        _enableLowBalance = settings.enableLowBalanceAlert;
        _enableBudget = settings.enableBudgetAlert;
        _enableNewDevice = settings.enableNewDeviceAlert;
      });
    }
  }

  Future<void> _saveSettings() async {
    final provider = context.read<AlertProvider>();
    
    await provider.updateSettings(
      largeTransactionThreshold: _largeTransactionController.text.isNotEmpty
          ? double.tryParse(_largeTransactionController.text)
          : null,
      lowBalanceThreshold: _lowBalanceController.text.isNotEmpty
          ? double.tryParse(_lowBalanceController.text)
          : null,
      budgetWarningPercentage: double.tryParse(_budgetWarningController.text) ?? 80.0,
      enableLargeTransactionAlert: _enableLargeTransaction,
      enableLowBalanceAlert: _enableLowBalance,
      enableBudgetAlert: _enableBudget,
      enableNewDeviceAlert: _enableNewDevice,
    );

    if (mounted && provider.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật cài đặt cảnh báo'),
          backgroundColor: Color(0xFF00FF88),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài Đặt Cảnh Báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: Consumer<AlertProvider>(
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
                        'Ngưỡng Cảnh Báo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D4FF),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildThresholdField(
                        controller: _largeTransactionController,
                        label: 'Ngưỡng giao dịch lớn',
                        hint: 'Nhập số tiền (VND)',
                        icon: Icons.payment,
                        enabled: _enableLargeTransaction,
                        formatter: currencyFormat,
                      ),
                      const SizedBox(height: 16),
                      _buildThresholdField(
                        controller: _lowBalanceController,
                        label: 'Ngưỡng số dư thấp',
                        hint: 'Nhập số tiền (VND)',
                        icon: Icons.account_balance_wallet,
                        enabled: _enableLowBalance,
                        formatter: currencyFormat,
                      ),
                      const SizedBox(height: 16),
                      _buildThresholdField(
                        controller: _budgetWarningController,
                        label: 'Cảnh báo ngân sách (%)',
                        hint: 'Nhập phần trăm (0-100)',
                        icon: Icons.pie_chart,
                        enabled: _enableBudget,
                        isPercentage: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bật/Tắt Cảnh Báo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D4FF),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSwitchTile(
                        title: 'Cảnh báo giao dịch lớn',
                        subtitle: 'Cảnh báo khi có giao dịch vượt ngưỡng',
                        icon: Icons.payment,
                        value: _enableLargeTransaction,
                        onChanged: (value) {
                          setState(() {
                            _enableLargeTransaction = value;
                          });
                          _saveSettings();
                        },
                      ),
                      const Divider(),
                      _buildSwitchTile(
                        title: 'Cảnh báo số dư thấp',
                        subtitle: 'Cảnh báo khi số dư xuống dưới ngưỡng',
                        icon: Icons.account_balance_wallet,
                        value: _enableLowBalance,
                        onChanged: (value) {
                          setState(() {
                            _enableLowBalance = value;
                          });
                          _saveSettings();
                        },
                      ),
                      const Divider(),
                      _buildSwitchTile(
                        title: 'Cảnh báo ngân sách',
                        subtitle: 'Cảnh báo khi ngân sách sắp hết',
                        icon: Icons.pie_chart,
                        value: _enableBudget,
                        onChanged: (value) {
                          setState(() {
                            _enableBudget = value;
                          });
                          _saveSettings();
                        },
                      ),
                      const Divider(),
                      _buildSwitchTile(
                        title: 'Cảnh báo thiết bị mới',
                        subtitle: 'Cảnh báo khi đăng nhập từ thiết bị mới',
                        icon: Icons.devices,
                        value: _enableNewDevice,
                        onChanged: (value) {
                          setState(() {
                            _enableNewDevice = value;
                          });
                          _saveSettings();
                        },
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

  Widget _buildThresholdField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool enabled,
    NumberFormat? formatter,
    bool isPercentage = false,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF00D4FF)),
        suffixText: isPercentage ? '%' : null,
      ),
      onChanged: (_) => _saveSettings(),
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

