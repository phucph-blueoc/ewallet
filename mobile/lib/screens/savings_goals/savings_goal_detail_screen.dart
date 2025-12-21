import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/tech_card.dart';
import 'add_edit_savings_goal_screen.dart';

class SavingsGoalDetailScreen extends StatefulWidget {
  final String goalId;

  const SavingsGoalDetailScreen({super.key, required this.goalId});

  @override
  State<SavingsGoalDetailScreen> createState() =>
      _SavingsGoalDetailScreenState();
}

class _SavingsGoalDetailScreenState extends State<SavingsGoalDetailScreen> {
  final _depositController = TextEditingController();
  final _withdrawController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavingsGoalProvider>().getSavingsGoal(widget.goalId);
    });
  }

  @override
  void dispose() {
    _depositController.dispose();
    _withdrawController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<SavingsGoalProvider>().getSavingsGoal(widget.goalId);
    await context.read<WalletProvider>().loadWallet(context);
  }

  Future<void> _deposit() async {
    if (_depositController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền')),
      );
      return;
    }

    try {
      final amount = double.parse(_depositController.text.replaceAll(',', ''));
      await context.read<SavingsGoalProvider>().depositToSavingsGoal(
            goalId: widget.goalId,
            amount: amount,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nạp tiền thành công'),
            backgroundColor: Colors.green,
          ),
        );
        _depositController.clear();
        _refresh();
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

  Future<void> _withdraw() async {
    if (_withdrawController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền')),
      );
      return;
    }

    try {
      final amount = double.parse(_withdrawController.text.replaceAll(',', ''));
      await context.read<SavingsGoalProvider>().withdrawFromSavingsGoal(
            goalId: widget.goalId,
            amount: amount,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rút tiền thành công'),
            backgroundColor: Colors.green,
          ),
        );
        _withdrawController.clear();
        _refresh();
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
          title: const Text('Chi Tiết Mục Tiêu'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final provider = context.read<SavingsGoalProvider>();
                final goal = provider.goals.firstWhere((g) => g.id == widget.goalId);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditSavingsGoalScreen(goal: goal),
                  ),
                );
                if (result == true) {
                  _refresh();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteDialog(),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: Consumer<SavingsGoalProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && provider.selectedGoal == null) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null || provider.selectedGoal == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        provider.error ?? 'Không tìm thấy mục tiêu',
                        style: TextStyle(color: Colors.red[300]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refresh,
                        child: const Text('Thử Lại'),
                      ),
                    ],
                  ),
                );
              }

              final goal = provider.selectedGoal!;
              final progress = goal.progressPercentage / 100;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TechCard(
                      glowColor: goal.isCompleted ? Colors.green : Colors.orange,
                      child: Column(
                        children: [
                          Text(
                            goal.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: goal.isCompleted
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: goal.isCompleted ? Colors.green : Colors.orange,
                              ),
                            ),
                            child: Text(
                              goal.statusText,
                              style: TextStyle(
                                color: goal.isCompleted
                                    ? Colors.green[300]
                                    : Colors.orange[300],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 20,
                              backgroundColor: Colors.grey[800],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                goal.isCompleted ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${goal.progressPercentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'Đã tiết kiệm',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${NumberFormat('#,###').format(goal.currentAmount)}₫',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    'Mục tiêu',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${NumberFormat('#,###').format(goal.targetAmount)}₫',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    'Còn lại',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${NumberFormat('#,###').format(goal.remainingAmount)}₫',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[300],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (goal.deadline != null) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16, color: Colors.grey[400]),
                                const SizedBox(width: 8),
                                Text(
                                  'Hạn chót: ${DateFormat('dd/MM/yyyy').format(goal.deadline!)}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (goal.autoDepositAmount != null) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.repeat, size: 16, color: Colors.blue[300]),
                                const SizedBox(width: 8),
                                Text(
                                  'Tự động nạp: ${NumberFormat('#,###').format(goal.autoDepositAmount)}₫/tháng',
                                  style: TextStyle(
                                    color: Colors.blue[300],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!goal.isCompleted) ...[
                      const SizedBox(height: 24),
                      TechCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Nạp Tiền',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _depositController,
                              decoration: const InputDecoration(
                                labelText: 'Số Tiền',
                                prefixText: '₫ ',
                                prefixIcon: Icon(Icons.add_circle),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _deposit,
                              icon: const Icon(Icons.add),
                              label: const Text('Nạp Tiền'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (goal.currentAmount > 0) ...[
                      const SizedBox(height: 16),
                      TechCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Rút Tiền',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _withdrawController,
                              decoration: const InputDecoration(
                                labelText: 'Số Tiền',
                                prefixText: '₫ ',
                                prefixIcon: Icon(Icons.remove_circle),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _withdraw,
                              icon: const Icon(Icons.remove),
                              label: const Text('Rút Tiền'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa Mục Tiêu'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa mục tiêu này? Lưu ý: Tiền trong mục tiêu sẽ không tự động trả về ví.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context
                    .read<SavingsGoalProvider>()
                    .deleteSavingsGoal(widget.goalId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Xóa mục tiêu thành công'),
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
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

