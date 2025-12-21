import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/providers.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/tech_card.dart';

class SpendingAnalyticsScreen extends StatefulWidget {
  const SpendingAnalyticsScreen({super.key});

  @override
  State<SpendingAnalyticsScreen> createState() =>
      _SpendingAnalyticsScreenState();
}

class _SpendingAnalyticsScreenState extends State<SpendingAnalyticsScreen> {
  String _selectedPeriod = 'month';
  int? _selectedYear;
  int? _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnalytics();
      context.read<AnalyticsProvider>().loadSpendingTrends(period: _selectedPeriod);
    });
  }

  Future<void> _loadAnalytics() async {
    await context.read<AnalyticsProvider>().loadSpendingAnalytics(
          period: _selectedPeriod,
          year: _selectedYear,
          month: _selectedMonth,
        );
  }

  Future<void> _refresh() async {
    await _loadAnalytics();
    await context.read<AnalyticsProvider>().loadSpendingTrends(period: _selectedPeriod);
  }

  @override
  Widget build(BuildContext context) {
    return TechBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Phân Tích Chi Tiêu'),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterDialog(),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: Consumer<AnalyticsProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && provider.spendingAnalytics == null) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        provider.error!,
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

              final analytics = provider.spendingAnalytics;
              final trends = provider.spendingTrends;

              if (analytics == null) {
                return const Center(
                  child: Text('Chưa có dữ liệu phân tích'),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: TechCard(
                            glowColor: Colors.red,
                            child: Column(
                              children: [
                                const Icon(Icons.trending_down,
                                    color: Colors.red, size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  'Chi tiêu',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${NumberFormat('#,###').format(analytics.totalSpending)}₫',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TechCard(
                            glowColor: Colors.green,
                            child: Column(
                              children: [
                                const Icon(Icons.trending_up,
                                    color: Colors.green, size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  'Thu nhập',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${NumberFormat('#,###').format(analytics.totalIncome)}₫',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TechCard(
                      glowColor: analytics.netAmount >= 0 ? Colors.green : Colors.red,
                      child: Column(
                        children: [
                          Text(
                            'Số dư',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${NumberFormat('#,###').format(analytics.netAmount)}₫',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: analytics.netAmount >= 0
                                  ? Colors.green[300]
                                  : Colors.red[300],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Trends
                    if (trends != null) ...[
                      const SizedBox(height: 24),
                      TechCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Xu Hướng',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      'Kỳ này',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${NumberFormat('#,###').format(trends.currentPeriodAmount)}₫',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'Kỳ trước',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${NumberFormat('#,###').format(trends.previousPeriodAmount)}₫',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'Thay đổi',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          trends.trend == 'down'
                                              ? Icons.arrow_downward
                                              : trends.trend == 'up'
                                                  ? Icons.arrow_upward
                                                  : Icons.remove,
                                          color: trends.isPositive
                                              ? Colors.green[300]
                                              : trends.trend == 'up'
                                                  ? Colors.red[300]
                                                  : Colors.grey[300],
                                          size: 16,
                                        ),
                                        Text(
                                          '${trends.changePercentage.abs().toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: trends.isPositive
                                                ? Colors.green[300]
                                                : trends.trend == 'up'
                                                    ? Colors.red[300]
                                                    : Colors.grey[300],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Category Breakdown
                    const SizedBox(height: 24),
                    TechCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chi Tiêu Theo Danh Mục',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (analytics.categories.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Chưa có dữ liệu chi tiêu',
                                style: TextStyle(color: Colors.grey[400]),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else ...[
                            SizedBox(
                              height: 200,
                              child: PieChart(
                                PieChartData(
                                  sections: analytics.categories.map((cat) {
                                    final colors = [
                                      Colors.blue,
                                      Colors.green,
                                      Colors.orange,
                                      Colors.purple,
                                      Colors.red,
                                      Colors.teal,
                                      Colors.pink,
                                      Colors.grey,
                                    ];
                                    final index = analytics.categories.indexOf(cat);
                                    return PieChartSectionData(
                                      value: cat.totalAmount,
                                      title: '${cat.percentage.toStringAsFixed(1)}%',
                                      color: colors[index % colors.length],
                                      radius: 80,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...analytics.categories.map((cat) {
                              final colors = [
                                Colors.blue,
                                Colors.green,
                                Colors.orange,
                                Colors.purple,
                                Colors.red,
                                Colors.teal,
                                Colors.pink,
                                Colors.grey,
                              ];
                              final index = analytics.categories.indexOf(cat);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: colors[index % colors.length],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        cat.categoryDisplayName,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    Text(
                                      '${NumberFormat('#,###').format(cat.totalAmount)}₫',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${cat.percentage.toStringAsFixed(1)}%)',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    // Daily Breakdown (if available)
                    if (analytics.dailyBreakdown != null &&
                        analytics.dailyBreakdown!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      TechCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chi Tiêu Theo Ngày',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: analytics.dailyBreakdown!
                                          .map((d) => d.amount)
                                          .reduce((a, b) => a > b ? a : b) *
                                      1.2,
                                  barTouchData: BarTouchData(
                                    enabled: false,
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          if (value.toInt() >=
                                              analytics.dailyBreakdown!.length) {
                                            return const Text('');
                                          }
                                          final dateStr =
                                              analytics.dailyBreakdown![value.toInt()]
                                                  .date;
                                          final date = DateTime.parse(dateStr);
                                          return Text(
                                            '${date.day}/${date.month}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                            ),
                                          );
                                        },
                                        reservedSize: 30,
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, meta) {
                                          return Text(
                                            '${(value / 1000).toStringAsFixed(0)}k',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                            ),
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
                                    getDrawingHorizontalLine: (value) {
                                      return FlLine(
                                        color: Colors.grey[800]!,
                                        strokeWidth: 1,
                                      );
                                    },
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups: analytics.dailyBreakdown!
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final data = entry.value;
                                    return BarChartGroupData(
                                      x: index,
                                      barRods: [
                                        BarChartRodData(
                                          toY: data.amount,
                                          color: Colors.blue,
                                          width: 12,
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lọc Dữ Liệu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: const InputDecoration(labelText: 'Kỳ'),
              items: const [
                DropdownMenuItem(value: 'day', child: Text('Ngày')),
                DropdownMenuItem(value: 'week', child: Text('Tuần')),
                DropdownMenuItem(value: 'month', child: Text('Tháng')),
                DropdownMenuItem(value: 'year', child: Text('Năm')),
              ],
              onChanged: (value) {
                setState(() => _selectedPeriod = value!);
              },
            ),
            if (_selectedPeriod == 'month' || _selectedPeriod == 'year') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: const InputDecoration(labelText: 'Năm'),
                items: List.generate(5, (index) {
                  final year = DateTime.now().year - 2 + index;
                  return DropdownMenuItem(value: year, child: Text('$year'));
                }),
                onChanged: (value) {
                  setState(() => _selectedYear = value);
                },
              ),
            ],
            if (_selectedPeriod == 'month') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedMonth,
                decoration: const InputDecoration(labelText: 'Tháng'),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _refresh();
            },
            child: const Text('Áp Dụng'),
          ),
        ],
      ),
    );
  }
}

