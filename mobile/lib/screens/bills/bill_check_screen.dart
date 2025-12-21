import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/tech_card.dart';
import 'bill_pay_screen.dart';

class BillCheckScreen extends StatefulWidget {
  final BillProvider provider;

  const BillCheckScreen({super.key, required this.provider});

  @override
  State<BillCheckScreen> createState() => _BillCheckScreenState();
}

class _BillCheckScreenState extends State<BillCheckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerCodeController = TextEditingController();
  bool _isChecking = false;
  BillCheckResponse? _checkResult;

  @override
  void dispose() {
    _customerCodeController.dispose();
    super.dispose();
  }

  Future<void> _checkBill() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isChecking = true;
      _checkResult = null;
    });

    try {
      final result = await context.read<BillProviderProvider>().checkBill(
            providerId: widget.provider.id,
            customerCode: _customerCodeController.text.trim(),
          );

      setState(() {
        _checkResult = result;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _isChecking = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TechBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.provider.name),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TechCard(
                  child: Column(
                    children: [
                      Text(
                        widget.provider.icon,
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.provider.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _customerCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Mã khách hàng / Số hợp đồng *',
                    hintText: 'Nhập mã khách hàng',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Bắt buộc';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isChecking ? null : _checkBill,
                  child: _isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kiểm Tra Hóa Đơn'),
                ),
                if (_checkResult != null) ...[
                  const SizedBox(height: 24),
                  if (_checkResult!.hasBill && _checkResult!.billInfo != null) ...[
                    TechCard(
                      glowColor: Colors.orange,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long, color: Colors.orange),
                              const SizedBox(width: 12),
                              const Text(
                                'Hóa Đơn Chưa Thanh Toán',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            'Mã khách hàng',
                            _checkResult!.billInfo!.customerCode,
                          ),
                          if (_checkResult!.billInfo!.customerName != null)
                            _buildInfoRow(
                              'Tên khách hàng',
                              _checkResult!.billInfo!.customerName!,
                            ),
                          _buildInfoRow(
                            'Số tiền',
                            '₫${_checkResult!.billInfo!.amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                          ),
                          if (_checkResult!.billInfo!.billPeriod != null)
                            _buildInfoRow(
                              'Kỳ hóa đơn',
                              _checkResult!.billInfo!.billPeriod!,
                            ),
                          if (_checkResult!.billInfo!.dueDate != null)
                            _buildInfoRow(
                              'Hạn thanh toán',
                              '${_checkResult!.billInfo!.dueDate!.day}/${_checkResult!.billInfo!.dueDate!.month}/${_checkResult!.billInfo!.dueDate!.year}',
                            ),
                          if (_checkResult!.billInfo!.description != null)
                            _buildInfoRow(
                              'Mô tả',
                              _checkResult!.billInfo!.description!,
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BillPayScreen(
                                      provider: widget.provider,
                                      customerCode: _customerCodeController.text.trim(),
                                      billInfo: _checkResult!.billInfo!,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.payment),
                              label: const Text('Thanh Toán Ngay'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    TechCard(
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _checkResult!.message ?? 'Không tìm thấy hóa đơn chưa thanh toán',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

