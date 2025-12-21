import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';

class TransactionChartsScreen extends StatefulWidget {
  const TransactionChartsScreen({super.key});

  @override
  State<TransactionChartsScreen> createState() => _TransactionChartsScreenState();
}

class _TransactionChartsScreenState extends State<TransactionChartsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().loadTransactions();
    });
  }

  Map<String, double> _getTransactionDataByType(List<Transaction> transactions) {
    Map<String, double> data = {
      'Nạp Tiền': 0,
      'Rút Tiền': 0,
      'Nhận Tiền': 0,
      'Chuyển Tiền': 0,
    };

    for (var tx in transactions) {
      if (tx.type == 'deposit') {
        data['Nạp Tiền'] = (data['Nạp Tiền'] ?? 0) + tx.amount;
      } else if (tx.type == 'withdraw') {
        data['Rút Tiền'] = (data['Rút Tiền'] ?? 0) + tx.amount;
      } else if (tx.type == 'transfer_in') {
        data['Nhận Tiền'] = (data['Nhận Tiền'] ?? 0) + tx.amount;
      } else if (tx.type == 'transfer_out') {
        data['Chuyển Tiền'] = (data['Chuyển Tiền'] ?? 0) + tx.amount;
      }
    }

    return data;
  }

  Map<String, double> _getTransactionDataByMonth(List<Transaction> transactions) {
    Map<String, double> data = {};

    for (var tx in transactions) {
      final monthKey = DateFormat('MMM yyyy').format(tx.timestamp);
      data[monthKey] = (data[monthKey] ?? 0) + tx.amount;
    }

    return data;
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, double> data) {
    final total = data.values.fold(0.0, (sum, value) => sum + value);
    if (total == 0) {
      return [];
    }

    final colors = [
      Colors.green,
      Colors.orange,
      Colors.blue,
      Colors.red,
    ];

    int index = 0;
    return data.entries
        .where((entry) => entry.value > 0)
        .map((entry) {
      final percentage = (entry.value / total * 100);
      final color = colors[index % colors.length];
      index++;

      return PieChartSectionData(
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        color: color,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân Tích Giao Dịch'),
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, _) {
          final transactions = walletProvider.transactions;

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart_outlined,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có giao dịch nào',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final byTypeData = _getTransactionDataByType(transactions);
          final byMonthData = _getTransactionDataByMonth(transactions);
          final pieSections = _buildPieChartSections(byTypeData);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pie Chart - By Type
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giao Dịch Theo Loại',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 24),
                        if (pieSections.isEmpty)
                          const Center(
                            child: Text('Không có dữ liệu để hiển thị'),
                          )
                        else
                          SizedBox(
                            height: 250,
                            child: Row(
                              children: [
                                Expanded(
                                  child: PieChart(
                                    PieChartData(
                                      sections: pieSections,
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 40,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: byTypeData.entries
                                        .where((entry) => entry.value > 0)
                                        .map((entry) {
                                      final index = byTypeData.keys.toList().indexOf(entry.key);
                                      final colors = [
                                        Colors.green,
                                        Colors.orange,
                                        Colors.blue,
                                        Colors.red,
                                      ];
                                      final color = colors[index % colors.length];
                                      final formatter = NumberFormat.currency(symbol: '₫', decimalDigits: 0);
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                entry.key,
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                            Text(
                                              formatter.format(entry.value),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Bar Chart - By Month
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giao Dịch Theo Tháng',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 24),
                        if (byMonthData.isEmpty)
                          const Center(
                            child: Text('Không có dữ liệu để hiển thị'),
                          )
                        else
                          SizedBox(
                            height: 300,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: byMonthData.values.reduce((a, b) => a > b ? a : b) * 1.2,
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipColor: (_) => Colors.grey[800]!,
                                    tooltipRoundedRadius: 8,
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final entries = byMonthData.entries.toList();
                                        if (value.toInt() >= entries.length) {
                                          return const Text('');
                                        }
                                        final date = entries[value.toInt()].key;
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            date.split(' ').first,
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        );
                                      },
                                      reservedSize: 30,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 50,
                                      getTitlesWidget: (value, meta) {
                                        if (value == 0) return const Text('');
                                        return Text(
                                          '${(value / 1000000).toStringAsFixed(1)}M',
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: byMonthData.entries.toList().asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final value = entry.value.value;
                                  return BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: value,
                                        color: Theme.of(context).colorScheme.primary,
                                        width: 20,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

