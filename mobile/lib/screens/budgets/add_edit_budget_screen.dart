import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/tech_background.dart';

class AddEditBudgetScreen extends StatefulWidget {
  final Budget? budget;

  const AddEditBudgetScreen({super.key, this.budget});

  @override
  State<AddEditBudgetScreen> createState() => _AddEditBudgetScreenState();
}

class _AddEditBudgetScreenState extends State<AddEditBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _selectedCategory = 'FOOD';
  String _selectedPeriod = 'MONTH';
  int? _selectedMonth;
  int _selectedYear = DateTime.now().year;

  final List<Map<String, String>> _categories = [
    {'value': 'FOOD', 'label': 'Ăn uống'},
    {'value': 'SHOPPING', 'label': 'Mua sắm'},
    {'value': 'BILLS', 'label': 'Hóa đơn'},
    {'value': 'TRANSPORT', 'label': 'Giao thông'},
    {'value': 'ENTERTAINMENT', 'label': 'Giải trí'},
    {'value': 'HEALTH', 'label': 'Sức khỏe'},
    {'value': 'EDUCATION', 'label': 'Giáo dục'},
    {'value': 'OTHER', 'label': 'Khác'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _selectedCategory = widget.budget!.category;
      _selectedPeriod = widget.budget!.period;
      _selectedMonth = widget.budget!.month;
      _selectedYear = widget.budget!.year;
      _amountController.text = widget.budget!.amount.toStringAsFixed(0);
    } else {
      _selectedMonth = DateTime.now().month;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPeriod == 'MONTH' && _selectedMonth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn tháng')),
      );
      return;
    }

    try {
      final amount = double.parse(_amountController.text.replaceAll(',', ''));

      if (widget.budget != null) {
        await context.read<BudgetProvider>().updateBudget(
              budgetId: widget.budget!.id,
              category: _selectedCategory,
              amount: amount,
              period: _selectedPeriod,
              month: _selectedMonth,
              year: _selectedYear,
            );
      } else {
        await context.read<BudgetProvider>().createBudget(
              category: _selectedCategory,
              amount: amount,
              period: _selectedPeriod,
              month: _selectedMonth,
              year: _selectedYear,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.budget != null
                ? 'Cập nhật ngân sách thành công'
                : 'Tạo ngân sách thành công'),
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
          title: Text(widget.budget != null ? 'Sửa Ngân Sách' : 'Tạo Ngân Sách'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Danh Mục *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat['value'],
                      child: Text(cat['label']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value!);
                  },
                ),
                const SizedBox(height: 16),
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
                    if (amount == null || amount <= 0) {
                      return 'Số tiền phải lớn hơn 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedPeriod,
                  decoration: const InputDecoration(
                    labelText: 'Kỳ Hạn *',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'MONTH', child: Text('Tháng')),
                    DropdownMenuItem(value: 'YEAR', child: Text('Năm')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedPeriod = value!;
                      if (_selectedPeriod == 'YEAR') {
                        _selectedMonth = null;
                      } else {
                        _selectedMonth = DateTime.now().month;
                      }
                    });
                  },
                ),
                if (_selectedPeriod == 'MONTH') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Tháng *',
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem(
                        value: month,
                        child: Text('Tháng $month'),
                      );
                    }),
                    onChanged: (value) {
                      setState(() => _selectedMonth = value);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Năm *',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  items: List.generate(5, (index) {
                    final year = DateTime.now().year - 2 + index;
                    return DropdownMenuItem(value: year, child: Text('$year'));
                  }),
                  onChanged: (value) {
                    setState(() => _selectedYear = value!);
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
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

