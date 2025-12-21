class User {
  final String id;
  final String email;
  final String fullName;
  final bool isVerified;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isVerified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      isVerified: json['is_verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'is_verified': isVerified,
    };
  }
}

class Wallet {
  final String id;
  final String userId;
  final double balance;
  final String currency;

  Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    this.currency = 'VND',
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'],
      userId: json['user_id'],
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] ?? 'VND',
    );
  }
}

class Transaction {
  final String id;
  final String? senderId;
  final String? receiverId;
  final double amount;
  final DateTime timestamp;
  final String? note;
  final String type;

  Transaction({
    required this.id,
    this.senderId,
    this.receiverId,
    required this.amount,
    required this.timestamp,
    this.note,
    required this.type,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      amount: (json['amount'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      note: json['note'],
      type: json['type'],
    );
  }

  bool get isDeposit => type == 'deposit';
  bool get isWithdraw => type == 'withdraw';
  bool get isTransferIn => type == 'transfer_in';
  bool get isTransferOut => type == 'transfer_out';
}

class Contact {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Contact({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (notes != null) 'notes': notes,
    };
  }

  String get initials {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
}

class ContactStats {
  final String contactId;
  final String contactName;
  final int totalTransactions;
  final double totalAmountSent;
  final double totalAmountReceived;
  final DateTime? lastTransactionDate;

  ContactStats({
    required this.contactId,
    required this.contactName,
    required this.totalTransactions,
    required this.totalAmountSent,
    required this.totalAmountReceived,
    this.lastTransactionDate,
  });

  factory ContactStats.fromJson(Map<String, dynamic> json) {
    return ContactStats(
      contactId: json['contact_id'],
      contactName: json['contact_name'],
      totalTransactions: json['total_transactions'],
      totalAmountSent: (json['total_amount_sent'] as num).toDouble(),
      totalAmountReceived: (json['total_amount_received'] as num).toDouble(),
      lastTransactionDate: json['last_transaction_date'] != null
          ? DateTime.parse(json['last_transaction_date'])
          : null,
    );
  }
}

class BankCard {
  final String id;
  final String userId;
  final String cardHolderName;
  final String bankName;
  final String cardType; // VISA, MASTERCARD, ATM
  final String cardNumberMasked; // Last 4 digits only
  final String expiryDateMasked; // MM/YY
  final bool isVerified;
  final DateTime createdAt;

  BankCard({
    required this.id,
    required this.userId,
    required this.cardHolderName,
    required this.bankName,
    required this.cardType,
    required this.cardNumberMasked,
    required this.expiryDateMasked,
    required this.isVerified,
    required this.createdAt,
  });

  factory BankCard.fromJson(Map<String, dynamic> json) {
    return BankCard(
      id: json['id'],
      userId: json['user_id'],
      cardHolderName: json['card_holder_name'],
      bankName: json['bank_name'],
      cardType: json['card_type'],
      cardNumberMasked: json['card_number_masked'],
      expiryDateMasked: json['expiry_date_masked'],
      isVerified: json['is_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'card_holder_name': cardHolderName,
      'bank_name': bankName,
      'card_type': cardType,
    };
  }

  String get displayName {
    return '$bankName •••• ${cardNumberMasked.substring(cardNumberMasked.length - 4)}';
  }

  String get cardTypeIcon {
    switch (cardType.toUpperCase()) {
      case 'VISA':
        return '💳';
      case 'MASTERCARD':
        return '💳';
      case 'ATM':
        return '🏦';
      default:
        return '💳';
    }
  }
}

class BillProvider {
  final String id;
  final String name;
  final String code;
  final String? logoUrl;
  final bool isActive;

  BillProvider({
    required this.id,
    required this.name,
    required this.code,
    this.logoUrl,
    required this.isActive,
  });

  factory BillProvider.fromJson(Map<String, dynamic> json) {
    return BillProvider(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      logoUrl: json['logo_url'],
      isActive: json['is_active'] ?? true,
    );
  }

  String get icon {
    switch (code.toUpperCase()) {
      case 'EVN':
        return '⚡';
      case 'SAVACO':
        return '💧';
      case 'FPT':
      case 'VIETTEL':
      case 'VINAPHONE':
      case 'MOBIFONE':
        return '📡';
      default:
        return '📄';
    }
  }
}

class SavedBill {
  final String id;
  final String userId;
  final String providerId;
  final String providerName;
  final String customerCode;
  final String? customerName;
  final String? alias;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedBill({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.providerName,
    required this.customerCode,
    this.customerName,
    this.alias,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavedBill.fromJson(Map<String, dynamic> json) {
    return SavedBill(
      id: json['id'],
      userId: json['user_id'],
      providerId: json['provider_id'],
      providerName: json['provider_name'],
      customerCode: json['customer_code'],
      customerName: json['customer_name'],
      alias: json['alias'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  String get displayName {
    return alias ?? customerName ?? customerCode;
  }
}

class BillInfo {
  final String customerCode;
  final String? customerName;
  final double amount;
  final String? billPeriod;
  final DateTime? dueDate;
  final String? description;

  BillInfo({
    required this.customerCode,
    this.customerName,
    required this.amount,
    this.billPeriod,
    this.dueDate,
    this.description,
  });

  factory BillInfo.fromJson(Map<String, dynamic> json) {
    return BillInfo(
      customerCode: json['customer_code'],
      customerName: json['customer_name'],
      amount: (json['amount'] as num).toDouble(),
      billPeriod: json['bill_period'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      description: json['description'],
    );
  }
}

class BillCheckResponse {
  final bool hasBill;
  final BillInfo? billInfo;
  final String? message;

  BillCheckResponse({
    required this.hasBill,
    this.billInfo,
    this.message,
  });

  factory BillCheckResponse.fromJson(Map<String, dynamic> json) {
    return BillCheckResponse(
      hasBill: json['has_bill'] ?? false,
      billInfo: json['bill_info'] != null ? BillInfo.fromJson(json['bill_info']) : null,
      message: json['message'],
    );
  }
}

class BillHistory {
  final String id;
  final String providerId;
  final String providerName;
  final String customerCode;
  final double amount;
  final String? billPeriod;
  final String transactionId;
  final DateTime createdAt;

  BillHistory({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.customerCode,
    required this.amount,
    this.billPeriod,
    required this.transactionId,
    required this.createdAt,
  });

  factory BillHistory.fromJson(Map<String, dynamic> json) {
    return BillHistory(
      id: json['id'],
      providerId: json['provider_id'],
      providerName: json['provider_name'],
      customerCode: json['customer_code'],
      amount: (json['amount'] as num).toDouble(),
      billPeriod: json['bill_period'],
      transactionId: json['transaction_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class Budget {
  final String id;
  final String userId;
  final String category;
  final double amount;
  final String period; // MONTH, YEAR
  final int? month; // 1-12 for monthly budgets
  final int year;
  final DateTime createdAt;
  final DateTime updatedAt;

  Budget({
    required this.id,
    required this.userId,
    required this.category,
    required this.amount,
    required this.period,
    this.month,
    required this.year,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'],
      userId: json['user_id'],
      category: json['category'],
      amount: (json['amount'] as num).toDouble(),
      period: json['period'],
      month: json['month'],
      year: json['year'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'amount': amount,
      'period': period,
      if (month != null) 'month': month,
      'year': year,
    };
  }

  String get categoryDisplayName {
    switch (category) {
      case 'FOOD':
        return 'Ăn uống';
      case 'SHOPPING':
        return 'Mua sắm';
      case 'BILLS':
        return 'Hóa đơn';
      case 'TRANSPORT':
        return 'Giao thông';
      case 'ENTERTAINMENT':
        return 'Giải trí';
      case 'HEALTH':
        return 'Sức khỏe';
      case 'EDUCATION':
        return 'Giáo dục';
      default:
        return 'Khác';
    }
  }

  String get periodDisplayName {
    if (period == 'MONTH' && month != null) {
      final months = [
        '', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
        'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
      ];
      return '${months[month!]} $year';
    }
    return 'Năm $year';
  }
}

class BudgetStatus extends Budget {
  final double spentAmount;
  final double remainingAmount;
  final double percentageUsed;
  final bool isOverBudget;

  BudgetStatus({
    required super.id,
    required super.userId,
    required super.category,
    required super.amount,
    required super.period,
    super.month,
    required super.year,
    required super.createdAt,
    required super.updatedAt,
    required this.spentAmount,
    required this.remainingAmount,
    required this.percentageUsed,
    required this.isOverBudget,
  });

  factory BudgetStatus.fromJson(Map<String, dynamic> json) {
    return BudgetStatus(
      id: json['id'],
      userId: json['user_id'],
      category: json['category'],
      amount: (json['amount'] as num).toDouble(),
      period: json['period'],
      month: json['month'],
      year: json['year'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      spentAmount: (json['spent_amount'] as num).toDouble(),
      remainingAmount: (json['remaining_amount'] as num).toDouble(),
      percentageUsed: (json['percentage_used'] as num).toDouble(),
      isOverBudget: json['is_over_budget'] ?? false,
    );
  }
}

class SavingsGoal {
  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final double? autoDepositAmount;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavingsGoal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    this.autoDepositAmount,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      autoDepositAmount: json['auto_deposit_amount'] != null
          ? (json['auto_deposit_amount'] as num).toDouble()
          : null,
      isCompleted: json['is_completed'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'target_amount': targetAmount,
      if (deadline != null) 'deadline': deadline!.toIso8601String().split('T')[0],
      if (autoDepositAmount != null) 'auto_deposit_amount': autoDepositAmount,
    };
  }

  double get progressPercentage {
    if (targetAmount == 0) return 0;
    return (currentAmount / targetAmount * 100).clamp(0, 100);
  }

  double get remainingAmount {
    return (targetAmount - currentAmount).clamp(0, double.infinity);
  }

  String get statusText {
    if (isCompleted) return 'Hoàn thành';
    if (deadline != null && DateTime.now().isAfter(deadline!)) {
      return 'Quá hạn';
    }
    return 'Đang tiết kiệm';
  }
}

class SpendingCategorySummary {
  final String category;
  final double totalAmount;
  final int transactionCount;
  final double percentage;

  SpendingCategorySummary({
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentage,
  });

  factory SpendingCategorySummary.fromJson(Map<String, dynamic> json) {
    return SpendingCategorySummary(
      category: json['category'],
      totalAmount: (json['total_amount'] as num).toDouble(),
      transactionCount: json['transaction_count'],
      percentage: (json['percentage'] as num).toDouble(),
    );
  }

  String get categoryDisplayName {
    switch (category) {
      case 'FOOD':
        return 'Ăn uống';
      case 'SHOPPING':
        return 'Mua sắm';
      case 'BILLS':
        return 'Hóa đơn';
      case 'TRANSPORT':
        return 'Giao thông';
      case 'ENTERTAINMENT':
        return 'Giải trí';
      case 'HEALTH':
        return 'Sức khỏe';
      case 'EDUCATION':
        return 'Giáo dục';
      default:
        return 'Khác';
    }
  }
}

class Notification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // TRANSACTION, PROMOTION, SECURITY, ALERT
  final bool isRead;
  final String? data; // JSON string
  final DateTime createdAt;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.data,
    required this.createdAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      message: json['message'],
      type: json['type'],
      isRead: json['is_read'] ?? false,
      data: json['data'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get typeDisplayName {
    switch (type) {
      case 'TRANSACTION':
        return 'Giao dịch';
      case 'PROMOTION':
        return 'Khuyến mãi';
      case 'SECURITY':
        return 'Bảo mật';
      case 'ALERT':
        return 'Cảnh báo';
      default:
        return 'Thông báo';
    }
  }
}

class NotificationSettings {
  final String id;
  final String userId;
  final bool enableTransactionNotifications;
  final bool enablePromotionNotifications;
  final bool enableSecurityNotifications;
  final bool enableAlertNotifications;
  final String? deviceToken;
  final String? deviceType;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationSettings({
    required this.id,
    required this.userId,
    required this.enableTransactionNotifications,
    required this.enablePromotionNotifications,
    required this.enableSecurityNotifications,
    required this.enableAlertNotifications,
    this.deviceToken,
    this.deviceType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      id: json['id'],
      userId: json['user_id'],
      enableTransactionNotifications: json['enable_transaction_notifications'] ?? true,
      enablePromotionNotifications: json['enable_promotion_notifications'] ?? true,
      enableSecurityNotifications: json['enable_security_notifications'] ?? true,
      enableAlertNotifications: json['enable_alert_notifications'] ?? true,
      deviceToken: json['device_token'],
      deviceType: json['device_type'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class Alert {
  final String id;
  final String userId;
  final String type; // LARGE_TRANSACTION, LOW_BALANCE, BUDGET_WARNING, NEW_DEVICE
  final String title;
  final String message;
  final String severity; // INFO, WARNING, CRITICAL
  final bool isRead;
  final String? data; // JSON string
  final DateTime createdAt;

  Alert({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    required this.isRead,
    this.data,
    required this.createdAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      title: json['title'],
      message: json['message'],
      severity: json['severity'] ?? 'INFO',
      isRead: json['is_read'] ?? false,
      data: json['data'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get typeDisplayName {
    switch (type) {
      case 'LARGE_TRANSACTION':
        return 'Giao dịch lớn';
      case 'LOW_BALANCE':
        return 'Số dư thấp';
      case 'BUDGET_WARNING':
        return 'Cảnh báo ngân sách';
      case 'NEW_DEVICE':
        return 'Thiết bị mới';
      default:
        return 'Cảnh báo';
    }
  }
}

class AlertSettings {
  final String id;
  final String userId;
  final double? largeTransactionThreshold;
  final double? lowBalanceThreshold;
  final double budgetWarningPercentage;
  final bool enableLargeTransactionAlert;
  final bool enableLowBalanceAlert;
  final bool enableBudgetAlert;
  final bool enableNewDeviceAlert;
  final DateTime createdAt;
  final DateTime updatedAt;

  AlertSettings({
    required this.id,
    required this.userId,
    this.largeTransactionThreshold,
    this.lowBalanceThreshold,
    this.budgetWarningPercentage = 80.0,
    this.enableLargeTransactionAlert = true,
    this.enableLowBalanceAlert = true,
    this.enableBudgetAlert = true,
    this.enableNewDeviceAlert = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AlertSettings.fromJson(Map<String, dynamic> json) {
    return AlertSettings(
      id: json['id'],
      userId: json['user_id'],
      largeTransactionThreshold: json['large_transaction_threshold'] != null
          ? (json['large_transaction_threshold'] as num).toDouble()
          : null,
      lowBalanceThreshold: json['low_balance_threshold'] != null
          ? (json['low_balance_threshold'] as num).toDouble()
          : null,
      budgetWarningPercentage: (json['budget_warning_percentage'] as num?)?.toDouble() ?? 80.0,
      enableLargeTransactionAlert: json['enable_large_transaction_alert'] ?? true,
      enableLowBalanceAlert: json['enable_low_balance_alert'] ?? true,
      enableBudgetAlert: json['enable_budget_alert'] ?? true,
      enableNewDeviceAlert: json['enable_new_device_alert'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class DailyBreakdownItem {
  final String date; // ISO date string
  final double amount;

  DailyBreakdownItem({
    required this.date,
    required this.amount,
  });

  factory DailyBreakdownItem.fromJson(Map<String, dynamic> json) {
    return DailyBreakdownItem(
      date: json['date'],
      amount: (json['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'amount': amount,
    };
  }
}

class SpendingAnalytics {
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final double totalSpending;
  final double totalIncome;
  final double netAmount;
  final int transactionCount;
  final List<SpendingCategorySummary> categories;
  final List<DailyBreakdownItem>? dailyBreakdown;

  SpendingAnalytics({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalSpending,
    required this.totalIncome,
    required this.netAmount,
    required this.transactionCount,
    required this.categories,
    this.dailyBreakdown,
  });

  factory SpendingAnalytics.fromJson(Map<String, dynamic> json) {
    return SpendingAnalytics(
      period: json['period'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      totalSpending: (json['total_spending'] as num).toDouble(),
      totalIncome: (json['total_income'] as num).toDouble(),
      netAmount: (json['net_amount'] as num).toDouble(),
      transactionCount: json['transaction_count'],
      categories: (json['categories'] as List)
          .map((c) => SpendingCategorySummary.fromJson(c))
          .toList(),
      dailyBreakdown: json['daily_breakdown'] != null
          ? (json['daily_breakdown'] as List)
              .map((d) => DailyBreakdownItem.fromJson(d))
              .toList()
          : null,
    );
  }
}

class SpendingTrends {
  final String period;
  final double currentPeriodAmount;
  final double previousPeriodAmount;
  final double changePercentage;
  final String trend; // up, down, stable

  SpendingTrends({
    required this.period,
    required this.currentPeriodAmount,
    required this.previousPeriodAmount,
    required this.changePercentage,
    required this.trend,
  });

  factory SpendingTrends.fromJson(Map<String, dynamic> json) {
    return SpendingTrends(
      period: json['period'],
      currentPeriodAmount: (json['current_period_amount'] as num).toDouble(),
      previousPeriodAmount: (json['previous_period_amount'] as num).toDouble(),
      changePercentage: (json['change_percentage'] as num).toDouble(),
      trend: json['trend'],
    );
  }

  String get trendDisplayName {
    switch (trend) {
      case 'up':
        return 'Tăng';
      case 'down':
        return 'Giảm';
      default:
        return 'Ổn định';
    }
  }

  bool get isPositive => trend == 'down'; // Spending down is positive
}

class UserDevice {
  final String id;
  final String userId;
  final String? deviceToken;
  final String deviceName;
  final String deviceType; // IOS, ANDROID, WEB
  final String? ipAddress;
  final String? userAgent;
  final DateTime lastLogin;
  final DateTime createdAt;
  final bool isActive;

  UserDevice({
    required this.id,
    required this.userId,
    this.deviceToken,
    required this.deviceName,
    required this.deviceType,
    this.ipAddress,
    this.userAgent,
    required this.lastLogin,
    required this.createdAt,
    required this.isActive,
  });

  factory UserDevice.fromJson(Map<String, dynamic> json) {
    return UserDevice(
      id: json['id'],
      userId: json['user_id'],
      deviceToken: json['device_token'],
      deviceName: json['device_name'],
      deviceType: json['device_type'],
      ipAddress: json['ip_address'],
      userAgent: json['user_agent'],
      lastLogin: DateTime.parse(json['last_login']),
      createdAt: DateTime.parse(json['created_at']),
      isActive: json['is_active'] ?? true,
    );
  }

  String get deviceTypeDisplayName {
    switch (deviceType.toUpperCase()) {
      case 'IOS':
        return 'iOS';
      case 'ANDROID':
        return 'Android';
      case 'WEB':
        return 'Web';
      default:
        return deviceType;
    }
  }

  String get deviceIcon {
    switch (deviceType.toUpperCase()) {
      case 'IOS':
        return '📱';
      case 'ANDROID':
        return '🤖';
      case 'WEB':
        return '💻';
      default:
        return '📱';
    }
  }
}

class SecurityHistory {
  final String id;
  final String userId;
  final String actionType; // LOGIN, LOGOUT, PASSWORD_CHANGE, PIN_CHANGE, 2FA_ENABLE, 2FA_DISABLE, SETTINGS_CHANGE
  final String? description;
  final String? ipAddress;
  final String? userAgent;
  final String? deviceId;
  final String? deviceName;
  final DateTime createdAt;

  SecurityHistory({
    required this.id,
    required this.userId,
    required this.actionType,
    this.description,
    this.ipAddress,
    this.userAgent,
    this.deviceId,
    this.deviceName,
    required this.createdAt,
  });

  factory SecurityHistory.fromJson(Map<String, dynamic> json) {
    return SecurityHistory(
      id: json['id'],
      userId: json['user_id'],
      actionType: json['action_type'],
      description: json['description'],
      ipAddress: json['ip_address'],
      userAgent: json['user_agent'],
      deviceId: json['device_id'],
      deviceName: json['device_name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get actionTypeDisplayName {
    switch (actionType) {
      case 'LOGIN':
        return 'Đăng nhập';
      case 'LOGOUT':
        return 'Đăng xuất';
      case 'PASSWORD_CHANGE':
        return 'Đổi mật khẩu';
      case 'PIN_CHANGE':
        return 'Đổi mã PIN';
      case '2FA_ENABLE':
        return 'Bật xác thực 2 bước';
      case '2FA_DISABLE':
        return 'Tắt xác thực 2 bước';
      case 'SETTINGS_CHANGE':
        return 'Thay đổi cài đặt';
      default:
        return actionType;
    }
  }

  String get actionIcon {
    switch (actionType) {
      case 'LOGIN':
        return '🔓';
      case 'LOGOUT':
        return '🔒';
      case 'PASSWORD_CHANGE':
        return '🔑';
      case 'PIN_CHANGE':
        return '🔐';
      case '2FA_ENABLE':
        return '✅';
      case '2FA_DISABLE':
        return '❌';
      case 'SETTINGS_CHANGE':
        return '⚙️';
      default:
        return '📝';
    }
  }
}
