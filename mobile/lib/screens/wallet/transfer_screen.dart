import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/providers.dart';
import '../../services/biometric_service.dart';

class TransferScreen extends StatefulWidget {
  final String? preFillEmail;
  final double? preFillAmount;
  final String? preFillNote;

  const TransferScreen({
    super.key,
    this.preFillEmail,
    this.preFillAmount,
    this.preFillNote,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();
  final BiometricService _biometricService = BiometricService();
  bool _isLoading = false;
  bool _otpRequired = false;
  bool _otpSent = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    // Pre-fill data if provided (from QR scan)
    if (widget.preFillEmail != null) {
      _emailController.text = widget.preFillEmail!;
    }
    if (widget.preFillAmount != null) {
      _amountController.text = widget.preFillAmount!.toStringAsFixed(0);
    }
    if (widget.preFillNote != null) {
      _noteController.text = widget.preFillNote!;
    }
  }

  Future<void> _loadBiometricSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    final isAvailable = await _biometricService.isAvailable();
    setState(() {
      _biometricEnabled = biometricEnabled && isAvailable;
    });
  }

  Future<bool> _authenticateWithBiometric() async {
    if (!_biometricEnabled) return true;
    
    return await _biometricService.authenticate(
      reason: 'Xác thực để xác nhận chuyển tiền',
    );
  }

  Future<void> _checkOtpAndTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pinController.text.length < 4 || _pinController.text.length > 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhập mã PIN giao dịch 4-6 chữ số'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_otpSent) {
      await _requestOtp();
    } else {
      await _transfer();
    }
  }

  Future<void> _requestOtp() async {
    setState(() => _isLoading = true);
    try {
      final amount = double.parse(_amountController.text);
      await context.read<WalletProvider>().requestTransferOtp(
            _emailController.text.trim(),
            amount,
            _pinController.text.trim(),
          );

      if (mounted) {
        setState(() {
          _otpRequired = true;
          _otpSent = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP đã được gửi đến email của bạn. Vui lòng nhập mã bên dưới.'),
            backgroundColor: Colors.blue,
          ),
        );
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

  Future<void> _transfer() async {
    // Validate OTP if required
    if (_otpRequired && _otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mã OTP 6 chữ số'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Authenticate with biometric if enabled
    final authenticated = await _authenticateWithBiometric();
    if (!authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xác thực sinh trắc học thất bại'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final amount = double.parse(_amountController.text);
      await context.read<WalletProvider>().transfer(
            _emailController.text.trim(),
            amount,
            _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            transactionPin: _pinController.text.trim(),
            otpCode: _otpController.text,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chuyển tiền thành công!'),
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
    final wallet = context.watch<WalletProvider>().wallet;

    return Scaffold(
      appBar: AppBar(title: const Text('Chuyển Tiền')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.send_outlined, size: 60, color: Colors.blue),
              const SizedBox(height: 16),
              if (wallet != null)
                Text(
                  'Khả dụng: ₫${wallet.balance.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Người Nhận',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !_otpSent,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Bắt buộc';
                  if (!v!.contains('@')) return 'Email không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Số Tiền',
                  prefixText: '₫ ',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: !_otpSent,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Bắt buộc';
                  final amount = double.tryParse(v!);
                  if (amount == null || amount <= 0) return 'Số tiền không hợp lệ';
                  if (wallet != null && amount > wallet.balance) {
                    return 'Số dư không đủ';
                  }
                  return null;
                },
                onChanged: (_) {
                  // Reset OTP state when amount changes
                  if (_otpSent) {
                    setState(() {
                      _otpSent = false;
                      _otpRequired = false;
                      _otpController.clear();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'Mã PIN Giao Dịch',
                  hintText: '4-6 chữ số',
                  prefixIcon: Icon(Icons.lock),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                enabled: !_otpSent,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Nhập mã PIN';
                  if (v.length < 4 || v.length > 6) return 'Mã PIN phải có 4-6 chữ số';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Ghi Chú (Tùy chọn)',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
                maxLength: 100,
                enabled: !_otpSent,
              ),
              
              // OTP Section
              if (_otpRequired) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Nhập mã OTP đã được gửi đến email của bạn',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otpController,
                        decoration: const InputDecoration(
                          labelText: 'Nhập Mã OTP',
                          hintText: '000000',
                          prefixIcon: Icon(Icons.pin),
                        ),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, letterSpacing: 4),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _checkOtpAndTransfer,
                style: FilledButton.styleFrom(backgroundColor: Colors.blue),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_otpSent ? 'Xác Nhận Chuyển Tiền' : 'Lấy Mã OTP'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _otpController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}
