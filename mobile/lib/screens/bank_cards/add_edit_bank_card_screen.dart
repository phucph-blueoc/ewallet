import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';

class AddEditBankCardScreen extends StatefulWidget {
  final BankCard? card;

  const AddEditBankCardScreen({super.key, this.card});

  @override
  State<AddEditBankCardScreen> createState() => _AddEditBankCardScreenState();
}

class _AddEditBankCardScreenState extends State<AddEditBankCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();
  final _bankNameController = TextEditingController();
  String _selectedCardType = 'VISA';
  bool _isLoading = false;

  final List<String> _cardTypes = ['VISA', 'MASTERCARD', 'ATM'];
  final List<String> _bankNames = [
    'Vietcombank',
    'BIDV',
    'VietinBank',
    'Agribank',
    'ACB',
    'Techcombank',
    'MBBank',
    'VPBank',
    'TPBank',
    'SHB',
    'Khác',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.card != null) {
      _cardHolderController.text = widget.card!.cardHolderName;
      _bankNameController.text = widget.card!.bankName;
      _selectedCardType = widget.card!.cardType;
    }
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  String _formatCardNumber(String value) {
    // Remove all non-digits
    value = value.replaceAll(RegExp(r'[^\d]'), '');
    // Add spaces every 4 digits
    String formatted = '';
    for (int i = 0; i < value.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += value[i];
    }
    return formatted;
  }

  String _formatExpiryDate(String value) {
    // Remove all non-digits
    value = value.replaceAll(RegExp(r'[^\d]'), '');
    // Format as MM/YY
    if (value.length >= 2) {
      final month = value.substring(0, 2);
      if (value.length >= 4) {
        return '$month/${value.substring(2, 4)}';
      } else if (value.length > 2) {
        return '$month/${value.substring(2)}';
      } else {
        return '$month/';
      }
    }
    return value;
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.card == null) {
        // Create new card
        await context.read<BankCardProvider>().createBankCard(
          cardNumber: _cardNumberController.text.replaceAll(' ', ''),
          cardHolderName: _cardHolderController.text.trim(),
          expiryDate: _expiryDateController.text.trim(),
          cvv: _cvvController.text.trim(),
          bankName: _bankNameController.text.trim(),
          cardType: _selectedCardType,
        );

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã thêm thẻ thành công. Vui lòng xác thực thẻ bằng OTP.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Update existing card
        await context.read<BankCardProvider>().updateBankCard(
          cardId: widget.card!.id,
          cardHolderName: _cardHolderController.text.trim(),
          bankName: _bankNameController.text.trim(),
        );

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã cập nhật thẻ thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
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
    return Scaffold(
      backgroundColor: const Color(0xFF050810),
      appBar: AppBar(
        title: Text(widget.card == null ? 'Thêm Thẻ Ngân Hàng' : 'Sửa Thẻ'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _saveCard),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.card == null) ...[
                TextFormField(
                  controller: _cardNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Số thẻ *',
                    hintText: '1234 5678 9012 3456',
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(19),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final formatted = _formatCardNumber(newValue.text);
                      return TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập số thẻ';
                    }
                    final digits = value.replaceAll(' ', '');
                    if (digits.length < 13 || digits.length > 19) {
                      return 'Số thẻ phải từ 13 đến 19 chữ số';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expiryDateController,
                        decoration: const InputDecoration(
                          labelText: 'Hết hạn (MM/YY) *',
                          hintText: '12/25',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final formatted = _formatExpiryDate(newValue.text);
                            return TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                            );
                          }),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập ngày hết hạn';
                          }
                          if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
                            return 'Định dạng: MM/YY';
                          }
                          final parts = value.split('/');
                          final month = int.tryParse(parts[0]);
                          if (month == null || month < 1 || month > 12) {
                            return 'Tháng không hợp lệ';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _cvvController,
                        decoration: const InputDecoration(
                          labelText: 'CVV *',
                          hintText: '123',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập CVV';
                          }
                          if (value.length < 3 || value.length > 4) {
                            return 'CVV phải từ 3 đến 4 chữ số';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _cardHolderController,
                decoration: const InputDecoration(
                  labelText: 'Tên chủ thẻ *',
                  hintText: 'NGUYEN VAN A',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên chủ thẻ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCardType,
                decoration: const InputDecoration(
                  labelText: 'Loại thẻ *',
                  prefixIcon: Icon(Icons.credit_card),
                ),
                items: _cardTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCardType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _bankNameController.text.isEmpty
                    ? null
                    : _bankNames.contains(_bankNameController.text)
                    ? _bankNameController.text
                    : 'Khác',
                decoration: const InputDecoration(
                  labelText: 'Ngân hàng *',
                  prefixIcon: Icon(Icons.account_balance),
                ),
                items: _bankNames.map((bank) {
                  return DropdownMenuItem(value: bank, child: Text(bank));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _bankNameController.text = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng chọn ngân hàng';
                  }
                  return null;
                },
              ),
              if (_bankNameController.text == 'Khác') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên ngân hàng',
                    hintText: 'Nhập tên ngân hàng',
                  ),
                  validator: (value) {
                    if (_bankNameController.text == 'Khác' &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Vui lòng nhập tên ngân hàng';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCard,
                child: Text(widget.card == null ? 'Thêm Thẻ' : 'Cập Nhật'),
              ),
              if (widget.card == null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Thông tin thẻ được mã hóa an toàn. Bạn sẽ nhận OTP để xác thực thẻ.',
                          style: TextStyle(
                            color: Colors.blue[200],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
