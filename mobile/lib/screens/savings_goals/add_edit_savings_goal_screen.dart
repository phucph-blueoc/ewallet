import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/tech_background.dart';

class AddEditSavingsGoalScreen extends StatefulWidget {
  final SavingsGoal? goal;

  const AddEditSavingsGoalScreen({super.key, this.goal});

  @override
  State<AddEditSavingsGoalScreen> createState() =>
      _AddEditSavingsGoalScreenState();
}

class _AddEditSavingsGoalScreenState extends State<AddEditSavingsGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _autoDepositController = TextEditingController();
  DateTime? _selectedDeadline;

  @override
  void initState() {
    super.initState();
    if (widget.goal != null) {
      _nameController.text = widget.goal!.name;
      _targetAmountController.text = widget.goal!.targetAmount.toStringAsFixed(0);
      _selectedDeadline = widget.goal!.deadline;
      if (widget.goal!.autoDepositAmount != null) {
        _autoDepositController.text =
            widget.goal!.autoDepositAmount!.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _autoDepositController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final targetAmount =
          double.parse(_targetAmountController.text.replaceAll(',', ''));
      final autoDeposit = _autoDepositController.text.isNotEmpty
          ? double.parse(_autoDepositController.text.replaceAll(',', ''))
          : null;

      if (widget.goal != null) {
        await context.read<SavingsGoalProvider>().updateSavingsGoal(
              goalId: widget.goal!.id,
              name: _nameController.text.trim(),
              targetAmount: targetAmount,
              deadline: _selectedDeadline,
              autoDepositAmount: autoDeposit,
            );
      } else {
        await context.read<SavingsGoalProvider>().createSavingsGoal(
              name: _nameController.text.trim(),
              targetAmount: targetAmount,
              deadline: _selectedDeadline,
              autoDepositAmount: autoDeposit,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.goal != null
                ? 'Cập nhật mục tiêu thành công'
                : 'Tạo mục tiêu thành công'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return TechBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
              widget.goal != null ? 'Sửa Mục Tiêu' : 'Tạo Mục Tiêu Tiết Kiệm'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên Mục Tiêu *',
                    prefixIcon: Icon(Icons.flag),
                    hintText: 'Ví dụ: Mua xe, Du lịch, Mua nhà...',
                  ),
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Bắt buộc';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _targetAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Số Tiền Mục Tiêu *',
                    prefixText: '₫ ',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Bắt buộc';
                    final amount = double.tryParse(v!.replaceAll(',', ''));
                    if (amount == null || amount <= 0) {
                      return 'Số tiền phải lớn hơn 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectDeadline,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Hạn Chót (Tùy chọn)',
                      prefixIcon: Icon(Icons.calendar_today),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _selectedDeadline != null
                          ? DateFormat('dd/MM/yyyy').format(_selectedDeadline!)
                          : 'Chọn ngày',
                      style: TextStyle(
                        color: _selectedDeadline != null
                            ? Colors.white
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                if (_selectedDeadline != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _selectedDeadline = null);
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Xóa hạn chót'),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _autoDepositController,
                  decoration: const InputDecoration(
                    labelText: 'Tự Động Nạp Mỗi Tháng (Tùy chọn)',
                    prefixText: '₫ ',
                    prefixIcon: Icon(Icons.repeat),
                    helperText: 'Số tiền tự động trích vào mục tiêu mỗi tháng',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Lưu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

