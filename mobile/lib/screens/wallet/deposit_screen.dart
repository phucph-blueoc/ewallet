import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/tech_card.dart';
import '../bank_cards/add_edit_bank_card_screen.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = false;
  
  String _sourceType = 'bank_card'; // Default to bank_card, no manual option
  String? _selectedCardId;

  final List<double> _quickAmounts = [50000, 100000, 200000, 500000, 1000000, 5000000, 10000000];

  @override
  void initState() {
    super.initState();
    // Load bank cards after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBankCards();
    });
  }

  Future<void> _loadBankCards() async {
    try {
      await context.read<BankCardProvider>().loadBankCards();
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _deposit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final amount = double.parse(_amountController.text.replaceAll(',', ''));
      
      String? sourceId;
      String? transactionPin;
      
      if (_sourceType == 'bank_card') {
        if (_selectedCardId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng chọn thẻ ngân hàng'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        sourceId = _selectedCardId;
        transactionPin = _pinController.text;
      }
      
      await context.read<WalletProvider>().deposit(
        amount: amount,
        sourceType: _sourceType,
        sourceId: sourceId,
        transactionPin: transactionPin,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nạp tiền thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TechBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Nạp Tiền')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TechCard(
                  glowColor: Colors.green,
                  child: Column(
                    children: [
                      const Icon(Icons.add_circle_outline, size: 48, color: Colors.green),
                      const SizedBox(height: 8),
                      const Text(
                        'Nạp Tiền Vào Ví',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _sourceType,
                  decoration: const InputDecoration(
                    labelText: 'Nguồn Tiền *',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'bank_card', child: Text('Thẻ Ngân Hàng')),
                    DropdownMenuItem(value: 'momo', child: Text('MoMo')),
                    DropdownMenuItem(value: 'zalopay', child: Text('ZaloPay')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _sourceType = value ?? 'bank_card';
                      _selectedCardId = null;
                      _pinController.clear();
                    });
                  },
                ),
                if (_sourceType == 'bank_card') ...[
                  const SizedBox(height: 16),
                  Consumer<BankCardProvider>(
                    builder: (context, bankCardProvider, _) {
                      final verifiedCards = bankCardProvider.bankCards
                          .where((card) => card.isVerified)
                          .toList();
                      
                      if (verifiedCards.isEmpty) {
                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.orange),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Chưa có thẻ ngân hàng nào đã liên kết. Vui lòng liên kết thẻ trước.',
                                      style: TextStyle(color: Colors.orange[300]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddEditBankCardScreen(),
                                  ),
                                );
                                if (result == true && mounted) {
                                  await _loadBankCards();
                                }
                              },
                              icon: const Icon(Icons.add_card),
                              label: const Text('Liên Kết Thẻ Ngân Hàng'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00D4FF),
                                side: const BorderSide(color: Color(0xFF00D4FF)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ],
                        );
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedCardId,
                            decoration: const InputDecoration(
                              labelText: 'Chọn Thẻ Ngân Hàng Đã Liên Kết *',
                              prefixIcon: Icon(Icons.credit_card),
                              helperText: 'Chỉ hiển thị thẻ đã liên kết và xác thực',
                            ),
                            items: verifiedCards.map((card) {
                              final last4Digits = card.cardNumberMasked.substring(card.cardNumberMasked.length - 4);
                              return DropdownMenuItem(
                                value: card.id,
                                child: Text(
                                  '${card.bankName} - ${card.cardType} •••• $last4Digits',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCardId = value;
                              });
                            },
                            validator: (value) {
                              if (_sourceType == 'bank_card' && (value == null || value.isEmpty)) {
                                return 'Vui lòng chọn thẻ ngân hàng';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddEditBankCardScreen(),
                                ),
                              );
                              if (result == true && mounted) {
                                await _loadBankCards();
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Liên kết thẻ mới'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF00D4FF),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (_sourceType == 'bank_card') ...[
                    const SizedBox(height: 16),
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
                        if (_sourceType == 'bank_card') {
                          if (v == null || v.isEmpty) return 'Nhập mã PIN';
                          if (v.length < 4 || v.length > 6) return 'Mã PIN phải có 4-6 chữ số';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Số Tiền *',
                    prefixText: '₫ ',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Bắt buộc';
                    final amount = double.tryParse(v!.replaceAll(',', ''));
                    if (amount == null || amount <= 0) return 'Số tiền không hợp lệ';
                    if (amount > 100000000) return 'Số tiền vượt quá giới hạn (100,000,000₫)';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Số tiền nhanh',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickAmounts.map((amount) {
                    return ActionChip(
                      label: Text('₫${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'),
                      onPressed: () {
                        setState(() {
                          _amountController.text = amount.toInt().toString();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _deposit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Nạp Tiền'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
