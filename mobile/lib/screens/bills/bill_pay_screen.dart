import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/tech_card.dart';

class BillPayScreen extends StatefulWidget {
  final BillProvider provider;
  final String customerCode;
  final BillInfo billInfo;
  final SavedBill? savedBill; // Optional: if paying from saved bill

  const BillPayScreen({
    super.key,
    required this.provider,
    required this.customerCode,
    required this.billInfo,
    this.savedBill,
  });

  @override
  State<BillPayScreen> createState() => _BillPayScreenState();
}

class _BillPayScreenState extends State<BillPayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _saveBill = false;
  final _aliasController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.savedBill != null) {
      _saveBill = true;
      _aliasController.text = widget.savedBill!.alias ?? '';
    }
    // Load wallet to show balance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().loadWallet(context);
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _payBill() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<BillProviderProvider>().payBill(
            providerId: widget.provider.id,
            customerCode: widget.customerCode,
            amount: widget.billInfo.amount,
            transactionPin: _pinController.text,
            saveBill: _saveBill,
            alias: _saveBill ? _aliasController.text.trim() : null,
          );

      // Reload wallet
      await context.read<WalletProvider>().loadWallet(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Thanh toán hóa đơn thành công! Số tiền: ₫${widget.billInfo.amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        // Improve error message display
        if (errorMessage.contains('Số dư không đủ')) {
          errorMessage = 'Số dư không đủ để thanh toán. Vui lòng nạp thêm tiền vào ví.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>().wallet;

    return TechBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Thanh Toán Hóa Đơn'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TechCard(
                  glowColor: Colors.orange,
                  child: Column(
                    children: [
                      Text(
                        widget.provider.icon,
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.provider.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mã KH: ${widget.customerCode}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TechCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thông Tin Hóa Đơn',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Số tiền', '₫${widget.billInfo.amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'),
                      if (widget.billInfo.billPeriod != null)
                        _buildInfoRow('Kỳ hóa đơn', widget.billInfo.billPeriod!),
                      if (wallet != null) ...[
                        _buildInfoRow('Số dư khả dụng', '₫${wallet.balance.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'),
                        if (wallet.balance < widget.billInfo.amount) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Số dư không đủ để thanh toán. Cần thêm: ₫${(widget.billInfo.amount - wallet.balance).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _pinController,
                  decoration: InputDecoration(
                    labelText: 'Mã PIN Giao Dịch *',
                    hintText: '4-6 chữ số',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscurePin = !_obscurePin),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: _obscurePin,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Nhập mã PIN';
                    if (v.length < 4 || v.length > 6) return 'Mã PIN phải có 4-6 chữ số';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                CheckboxListTile(
                  title: const Text('Lưu hóa đơn để thanh toán lại'),
                  value: _saveBill,
                  onChanged: (value) {
                    setState(() {
                      _saveBill = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFF00D4FF),
                ),
                if (_saveBill) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _aliasController,
                    decoration: const InputDecoration(
                      labelText: 'Tên gợi nhớ (tùy chọn)',
                      hintText: 'Ví dụ: Hóa đơn nhà',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    maxLength: 100,
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: (_isLoading || (wallet != null && wallet.balance < widget.billInfo.amount)) 
                      ? null 
                      : _payBill,
                  style: FilledButton.styleFrom(
                    backgroundColor: (wallet != null && wallet.balance < widget.billInfo.amount)
                        ? Colors.grey
                        : Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          (wallet != null && wallet.balance < widget.billInfo.amount)
                              ? 'Số Dư Không Đủ'
                              : 'Xác Nhận Thanh Toán',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
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

