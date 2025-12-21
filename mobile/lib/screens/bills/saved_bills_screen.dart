import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/tech_card.dart';
import 'bill_pay_screen.dart';

class SavedBillsScreen extends StatefulWidget {
  const SavedBillsScreen({super.key});

  @override
  State<SavedBillsScreen> createState() => _SavedBillsScreenState();
}

class _SavedBillsScreenState extends State<SavedBillsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillProviderProvider>().loadSavedBills();
    });
  }

  Future<void> _refresh() async {
    await context.read<BillProviderProvider>().loadSavedBills();
  }

  Future<void> _deleteSavedBill(SavedBill savedBill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa hóa đơn đã lưu'),
        content: Text('Bạn có chắc chắn muốn xóa "${savedBill.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await context.read<BillProviderProvider>().deleteSavedBill(savedBill.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa hóa đơn đã lưu'),
              backgroundColor: Colors.green,
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
      }
    }
  }

  Future<void> _paySavedBill(SavedBill savedBill) async {
    // First check for bill
    try {
      final checkResult = await context.read<BillProviderProvider>().checkBill(
            providerId: savedBill.providerId,
            customerCode: savedBill.customerCode,
          );

      if (checkResult.hasBill && checkResult.billInfo != null) {
        // Get provider info
        await context.read<BillProviderProvider>().loadBillProviders();
        final provider = context.read<BillProviderProvider>().providers.firstWhere(
              (p) => p.id == savedBill.providerId,
              orElse: () => BillProvider(
                id: savedBill.providerId,
                name: savedBill.providerName,
                code: '',
                isActive: true,
              ),
            );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BillPayScreen(
                provider: provider,
                customerCode: savedBill.customerCode,
                billInfo: checkResult.billInfo!,
                savedBill: savedBill,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy hóa đơn chưa thanh toán'),
              backgroundColor: Colors.orange,
            ),
          );
        }
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
          title: const Text('Hóa Đơn Đã Lưu'),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: Consumer<BillProviderProvider>(
            builder: (context, billProvider, _) {
              if (billProvider.isLoading && billProvider.savedBills.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (billProvider.savedBills.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có hóa đơn nào được lưu',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...billProvider.savedBills.map((savedBill) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TechCard(
                        glowColor: const Color(0xFF00D4FF),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        savedBill.displayName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        savedBill.providerName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Mã KH: ${savedBill.customerCode}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'pay') {
                                      _paySavedBill(savedBill);
                                    } else if (value == 'delete') {
                                      _deleteSavedBill(savedBill);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'pay',
                                      child: Row(
                                        children: [
                                          Icon(Icons.payment, size: 20),
                                          SizedBox(width: 12),
                                          Text('Thanh toán'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 12),
                                          Text('Xóa', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _paySavedBill(savedBill),
                                icon: const Icon(Icons.payment),
                                label: const Text('Thanh Toán'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00D4FF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

