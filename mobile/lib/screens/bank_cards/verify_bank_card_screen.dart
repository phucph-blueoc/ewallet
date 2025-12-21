import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/tech_card.dart';

class VerifyBankCardScreen extends StatefulWidget {
  final BankCard card;

  const VerifyBankCardScreen({super.key, required this.card});

  @override
  State<VerifyBankCardScreen> createState() => _VerifyBankCardScreenState();
}

class _VerifyBankCardScreenState extends State<VerifyBankCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyCard() async {
    print('[VerifyCard] Button pressed');
    print('[VerifyCard] OTP: ${_otpController.text}');
    print('[VerifyCard] Card ID: ${widget.card.id}');
    
    if (!_formKey.currentState!.validate()) {
      print('[VerifyCard] Form validation failed');
      return;
    }
    
    print('[VerifyCard] Form validation passed, calling API...');
    setState(() => _isLoading = true);
    
    try {
      print('[VerifyCard] Calling verifyBankCard API...');
      await context.read<BankCardProvider>().verifyBankCard(
            cardId: widget.card.id,
            otpCode: _otpController.text,
          );
      print('[VerifyCard] API call successful');

      // Reload cards list
      print('[VerifyCard] Reloading bank cards...');
      await context.read<BankCardProvider>().loadBankCards();

      if (mounted) {
        print('[VerifyCard] Showing success message');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xác thực thẻ thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      print('[VerifyCard] Error occurred: $e');
      print('[VerifyCard] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown > 0) return;

    setState(() => _isResending = true);
    try {
      final result = await context.read<BankCardProvider>().resendCardVerificationOtp(widget.card.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Mã OTP đã được gửi đến email của bạn'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        _startCooldown();
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
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TechBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Xác Thực Thẻ Ngân Hàng'),
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
                      const Icon(Icons.credit_card, size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text(
                        widget.card.bankName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '•••• ${widget.card.cardNumberMasked.substring(widget.card.cardNumberMasked.length - 4)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Text(
                          'Chưa xác thực',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mã OTP đã được gửi đến email của bạn khi thêm thẻ. Vui lòng nhập mã OTP để xác thực thẻ.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: 'Mã OTP *',
                    hintText: 'Nhập mã 6 chữ số',
                    prefixIcon: Icon(Icons.pin_outlined),
                    helperText: 'Mã OTP đã được gửi đến email của bạn',
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 4),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Nhập mã OTP';
                    if (v.length != 6) return 'Mã OTP phải có 6 chữ số';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _verifyCard,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Xác Thực Thẻ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Không nhận được mã? ",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (_isResending)
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_resendCooldown > 0)
                      Text(
                        'Gửi lại sau ${_resendCooldown}s',
                        style: TextStyle(color: Colors.grey[500]),
                      )
                    else
                      GestureDetector(
                        onTap: _resendOtp,
                        child: const Text(
                          'Gửi Lại Mã OTP',
                          style: TextStyle(
                            color: Color(0xFF00D4FF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

