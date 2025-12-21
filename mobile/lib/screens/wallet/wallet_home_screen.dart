import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/inactivity_wrapper.dart';
import '../../widgets/tech_card.dart';
import '../../widgets/tech_background.dart';
import 'deposit_screen.dart';
import 'withdraw_screen.dart';
import 'transfer_screen.dart';
import 'qr_transfer_screen.dart';
import 'scan_qr_screen.dart';
import 'transaction_charts_screen.dart';
import 'quick_pay_screen.dart';
import '../contacts/contact_list_screen.dart';
import '../bank_cards/bank_card_list_screen.dart';
import '../bills/bill_provider_list_screen.dart';
import '../auth/login_screen.dart';
import '../settings/change_password_screen.dart';
import '../settings/settings_screen.dart';
import '../budgets/budget_list_screen.dart';
import '../savings_goals/savings_goal_list_screen.dart';
import '../analytics/spending_analytics_screen.dart';
import '../notifications/notification_list_screen.dart';
import '../alerts/alert_list_screen.dart';
import '../../services/fcm_service.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().loadWallet(context);
      context.read<WalletProvider>().loadTransactions();
      context.read<NotificationProvider>().refreshUnreadCount();
      
      // Initialize FCM after user is authenticated
      FCMService().initialize(context);
    });
  }

  Future<void> _refresh() async {
    await context.read<WalletProvider>().loadWallet(context);
    await context.read<WalletProvider>().loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return InactivityWrapper(
      timeout: const Duration(minutes: 10),
      child: TechBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
        appBar: AppBar(
        title: const Text('Ví Của Tôi'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                  break;
                case 'change_password':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  );
                  break;
                case 'logout':
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 12),
                    Text('Cài Đặt'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'change_password',
                child: Row(
                  children: [
                    Icon(Icons.lock_outline),
                    SizedBox(width: 12),
                    Text('Đổi Mật Khẩu'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Đăng Xuất', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Consumer<WalletProvider>(
          builder: (context, walletProvider, _) {
            if (walletProvider.wallet == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final wallet = walletProvider.wallet!;
            final transactions = walletProvider.transactions;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildBalanceCard(wallet),
                const SizedBox(height: 16),
                _buildActionButtons(),
                const SizedBox(height: 24),
                _buildChartsButton(),
                const SizedBox(height: 24),
                _buildBudgetAndSavingsSection(),
                const SizedBox(height: 24),
                const SizedBox(height: 24),
                _buildNotificationsSection(),
                const SizedBox(height: 24),
                _buildTransactionsList(transactions),
              ],
            );
          },
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildBalanceCard(Wallet wallet) {
    final formatter = NumberFormat.currency(symbol: '₫', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00D4FF).withOpacity(0.2),
            const Color(0xFF00FF88).withOpacity(0.1),
            const Color(0xFF00D4FF).withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00D4FF).withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF00FF88).withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00D4FF).withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Color(0xFF00D4FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'SỐ DƯ TỔNG',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            formatter.format(wallet.balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              shadows: [
                Shadow(
                  color: Color(0xFF00D4FF),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF88).withOpacity(0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                wallet.currency,
                style: TextStyle(
                  color: const Color(0xFF00FF88),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // First row: Deposit, Withdraw, Transfer
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.add_circle_outline,
                label: 'Nạp Tiền',
                color: const Color(0xFF00FF88),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DepositScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.remove_circle_outline,
                label: 'Rút Tiền',
                color: const Color(0xFFFFB84D),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WithdrawScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.send_outlined,
                label: 'Chuyển Tiền',
                color: const Color(0xFF00D4FF),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransferScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row: QR Scan and Generate
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.qr_code_scanner,
                label: 'Quét QR',
                color: const Color(0xFF9D4EDD),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanQRScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.qr_code_2,
                label: 'Tạo QR',
                color: const Color(0xFF00FF88),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QRTransferScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Third row: Quick Pay and Contacts
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.flash_on,
                label: 'Thanh Toán Nhanh',
                color: const Color(0xFFFFB84D),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuickPayScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.contacts,
                label: 'Danh Bạ',
                color: const Color(0xFF00D4FF),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactListScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Fourth row: Bank Cards and Bills
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.credit_card,
                label: 'Thẻ Ngân Hàng',
                color: const Color(0xFF9D4EDD),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BankCardListScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.receipt_long,
                label: 'Hóa Đơn',
                color: const Color(0xFFFFB84D),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BillProviderListScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartsButton() {
    return TechCard(
      glowColor: const Color(0xFF00D4FF),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TransactionChartsScreen(),
          ),
        );
      },
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00D4FF).withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.bar_chart,
              color: Color(0xFF00D4FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PHÂN TÍCH GIAO DỊCH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Xem biểu đồ và thống kê',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF00FF88),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetAndSavingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quản Lý Tài Chính',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TechCard(
                glowColor: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BudgetListScreen(),
                    ),
                  );
                },
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.account_balance_wallet,
                        color: Colors.blue, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Ngân Sách',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Theo dõi chi tiêu',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TechCard(
                glowColor: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SavingsGoalListScreen(),
                    ),
                  );
                },
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.savings, color: Colors.orange, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Mục Tiêu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tiết kiệm mục tiêu',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TechCard(
                glowColor: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SpendingAnalyticsScreen(),
                    ),
                  );
                },
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.analytics, color: Colors.purple, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Phân Tích',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Báo cáo chi tiêu',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thông Báo & Cảnh Báo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (notificationProvider.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${notificationProvider.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TechCard(
                    glowColor: const Color(0xFF00D4FF),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationListScreen(),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.notifications,
                            color: Color(0xFF00D4FF), size: 32),
                        const SizedBox(height: 8),
                        const Text(
                          'Thông Báo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Xem thông báo',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TechCard(
                    glowColor: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AlertListScreen(),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 32),
                        const SizedBox(height: 8),
                        const Text(
                          'Cảnh Báo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Xem cảnh báo',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionsList(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Chưa có giao dịch nào'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Giao Dịch Gần Đây',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...transactions.map((tx) => _TransactionItem(transaction: tx)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final Transaction transaction;

  const _TransactionItem({required this.transaction});

  String _getTransactionTypeLabel(String type) {
    switch (type) {
      case 'deposit':
        return 'NẠP TIỀN';
      case 'withdraw':
        return 'RÚT TIỀN';
      case 'transfer_in':
        return 'NHẬN TIỀN';
      case 'transfer_out':
        return 'CHUYỂN TIỀN';
      case 'deposit_from_card':
        return 'NẠP TỪ THẺ';
      case 'withdraw_to_card':
        return 'RÚT VỀ THẺ';
      case 'bill_payment':
        return 'THANH TOÁN HÓA ĐƠN';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _getTransactionTypeDescription(String type) {
    switch (type) {
      case 'deposit':
        return 'Nạp tiền';
      case 'withdraw':
        return 'Rút tiền';
      case 'transfer_in':
        return 'Nhận tiền';
      case 'transfer_out':
        return 'Chuyển tiền';
      case 'deposit_from_card':
        return 'Nạp từ thẻ';
      case 'withdraw_to_card':
        return 'Rút về thẻ';
      case 'bill_payment':
        return 'Thanh toán hóa đơn';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(symbol: '₫', decimalDigits: 0);
    final dateFormatter = DateFormat('MMM dd, HH:mm');

    IconData icon;
    Color color;

    if (transaction.isDeposit) {
      icon = Icons.add_circle;
      color = Colors.green;
    } else if (transaction.isWithdraw) {
      icon = Icons.remove_circle;
      color = Colors.orange;
    } else if (transaction.isTransferIn) {
      icon = Icons.arrow_downward;
      color = Colors.blue;
    } else {
      icon = Icons.arrow_upward;
      color = Colors.red;
    }

    final isPositive = transaction.isDeposit || transaction.isTransferIn;

    return TechCard(
      glowColor: color,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTransactionTypeLabel(transaction.type),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getTransactionTypeDescription(transaction.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                if (transaction.note?.isNotEmpty ?? false)
                  Text(
                    transaction.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  dateFormatter.format(transaction.timestamp),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isPositive ? const Color(0xFF00FF88) : const Color(0xFFFF3B5C))
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isPositive ? const Color(0xFF00FF88) : const Color(0xFFFF3B5C))
                    .withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Text(
              '${isPositive ? '+' : '-'}${formatter.format(transaction.amount)}',
              style: TextStyle(
                color: isPositive ? const Color(0xFF00FF88) : const Color(0xFFFF3B5C),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
