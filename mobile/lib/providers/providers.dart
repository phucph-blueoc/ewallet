import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart' hide Notification;
import '../models/models.dart' as models show Notification;
import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../utils/api_wrapper.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isAuthenticated = false;
  User? _currentUser;

  bool get isAuthenticated => _isAuthenticated;
  User? get currentUser => _currentUser;

  Future<void> checkAuth() async {
    final token = await _apiService.getAccessToken();
    if (token == null) {
      _isAuthenticated = false;
      notifyListeners();
      return;
    }

    // Validate token by making an API call
    try {
      await _apiService.getWallet();
      _isAuthenticated = true;
    } catch (e) {
      // Token is invalid or expired
      await _apiService.logout();
      _isAuthenticated = false;
    }
    notifyListeners();
  }

  Future<void> register(String email, String password, String fullName) async {
    await _apiService.register(
      email: email,
      password: password,
      fullName: fullName,
    );
  }

  Future<void> verifyOtp(String email, String otpCode) async {
    await _apiService.verifyOtp(email: email, otpCode: otpCode);
  }

  Future<void> resendOtp(String email) async {
    await _apiService.resendOtp(email);
  }

  Future<void> login(String email, String password) async {
    await _apiService.login(email: email, password: password);
    _isAuthenticated = true;

    // Save email for next login
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_login_email', email);

    notifyListeners();

    // Register FCM token after successful login
    try {
      final savedToken = await prefs.getString('fcm_token');
      if (savedToken != null && savedToken.isNotEmpty) {
        final fcmService = FCMService();
        final deviceType = fcmService.getDeviceType();
        await _apiService.registerDevice(
          deviceToken: savedToken,
          deviceType: deviceType,
        );
        debugPrint('FCM token registered after login');
      }
    } catch (e) {
      debugPrint('Failed to register FCM token after login: $e');
      // Don't fail login if FCM registration fails
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    _isAuthenticated = false;
    _currentUser = null;

    // Delete FCM token on logout
    try {
      await FCMService().deleteToken();
    } catch (e) {
      debugPrint('Error deleting FCM token on logout: $e');
    }

    // Optionally clear saved email on logout (or keep it for convenience)
    // Uncomment the next 2 lines if you want to clear email on logout
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.remove('last_login_email');

    notifyListeners();
  }

  /// Get last login email from storage
  Future<String?> getLastLoginEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_login_email');
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _apiService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}

class WalletProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  Wallet? _wallet;
  List<Transaction> _transactions = [];
  bool _isLoading = false;

  Wallet? get wallet => _wallet;
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> loadWallet([BuildContext? context]) async {
    setLoading(true);
    try {
      _wallet = await handleApiCall(context, () => _apiService.getWallet());
      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  Future<void> loadTransactions() async {
    setLoading(true);
    try {
      _transactions = await _apiService.getTransactions();
      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  Future<void> deposit({
    required double amount,
    String sourceType = 'manual',
    String? sourceId,
    String? transactionPin,
  }) async {
    _wallet = await _apiService.deposit(
      amount: amount,
      sourceType: sourceType,
      sourceId: sourceId,
      transactionPin: transactionPin,
    );
    notifyListeners();
    await loadTransactions();
  }

  Future<void> withdraw({
    required double amount,
    String destinationType = 'manual',
    String? destinationId,
    String? transactionPin,
  }) async {
    _wallet = await _apiService.withdraw(
      amount: amount,
      destinationType: destinationType,
      destinationId: destinationId,
      transactionPin: transactionPin,
    );
    notifyListeners();
    await loadTransactions();
  }

  Future<Map<String, dynamic>> requestTransferOtp(
    String receiverEmail,
    double amount,
    String transactionPin,
  ) async {
    return await _apiService.requestTransferOtp(
      receiverEmail: receiverEmail,
      amount: amount,
      transactionPin: transactionPin,
    );
  }

  Future<void> transfer(
    String receiverEmail,
    double amount,
    String? note, {
    required String transactionPin,
    required String otpCode,
  }) async {
    await _apiService.transfer(
      receiverEmail: receiverEmail,
      amount: amount,
      note: note,
      transactionPin: transactionPin,
      otpCode: otpCode,
    );
    await loadWallet(null);
    await loadTransactions();
  }

  Future<void> depositFromCard({
    required String cardId,
    required double amount,
    required String transactionPin,
  }) async {
    _wallet = await _apiService.depositFromCard(
      cardId: cardId,
      amount: amount,
      transactionPin: transactionPin,
    );
    notifyListeners();
    await loadTransactions();
  }

  Future<void> withdrawToCard({
    required String cardId,
    required double amount,
    required String transactionPin,
  }) async {
    _wallet = await _apiService.withdrawToCard(
      cardId: cardId,
      amount: amount,
      transactionPin: transactionPin,
    );
    notifyListeners();
    await loadTransactions();
  }
}

extension TransactionPinActions on AuthProvider {
  Future<void> setTransactionPin(
    String currentPassword,
    String transactionPin,
  ) async {
    await _apiService.setTransactionPin(
      currentPassword: currentPassword,
      transactionPin: transactionPin,
    );
  }

  Future<void> verifyTransactionPin(String transactionPin) async {
    await _apiService.verifyTransactionPin(transactionPin);
  }
}

class ContactProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Contact> _contacts = [];
  bool _isLoading = false;
  String? _error;

  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool loading) {
    _isLoading = loading;
    _error = null;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadContacts({String? search}) async {
    setLoading(true);
    try {
      _contacts = await _apiService.getContacts(search: search);
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
    }
  }

  Future<Contact> createContact({
    required String name,
    required String email,
    String? phone,
    String? avatarUrl,
    String? notes,
  }) async {
    try {
      final contact = await _apiService.createContact(
        name: name,
        email: email,
        phone: phone,
        avatarUrl: avatarUrl,
        notes: notes,
      );
      await loadContacts();
      return contact;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<Contact> updateContact({
    required String contactId,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? notes,
  }) async {
    try {
      final contact = await _apiService.updateContact(
        contactId: contactId,
        name: name,
        email: email,
        phone: phone,
        avatarUrl: avatarUrl,
        notes: notes,
      );
      await loadContacts();
      return contact;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await _apiService.deleteContact(contactId);
      await loadContacts();
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<ContactStats> getContactStats(String contactId) async {
    try {
      return await _apiService.getContactStats(contactId);
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }
}

class BankCardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<BankCard> _bankCards = [];
  bool _isLoading = false;
  String? _error;

  List<BankCard> get bankCards => _bankCards;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool loading) {
    _isLoading = loading;
    _error = null;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadBankCards() async {
    setLoading(true);
    try {
      _bankCards = await _apiService.getBankCards();
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
    }
  }

  Future<BankCard> createBankCard({
    required String cardNumber,
    required String cardHolderName,
    required String expiryDate,
    required String cvv,
    required String bankName,
    required String cardType,
  }) async {
    try {
      final card = await _apiService.createBankCard(
        cardNumber: cardNumber,
        cardHolderName: cardHolderName,
        expiryDate: expiryDate,
        cvv: cvv,
        bankName: bankName,
        cardType: cardType,
      );
      await loadBankCards();
      return card;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<BankCard> updateBankCard({
    required String cardId,
    String? cardHolderName,
    String? bankName,
  }) async {
    try {
      final card = await _apiService.updateBankCard(
        cardId: cardId,
        cardHolderName: cardHolderName,
        bankName: bankName,
      );
      await loadBankCards();
      return card;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> deleteBankCard(String cardId) async {
    try {
      await _apiService.deleteBankCard(cardId);
      await loadBankCards();
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<BankCard> verifyBankCard({
    required String cardId,
    required String otpCode,
  }) async {
    try {
      final card = await _apiService.verifyBankCard(
        cardId: cardId,
        otpCode: otpCode,
      );
      await loadBankCards();
      return card;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resendCardVerificationOtp(String cardId) async {
    try {
      return await _apiService.resendCardVerificationOtp(cardId);
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }
}

class BillProviderProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<BillProvider> _providers = [];
  List<SavedBill> _savedBills = [];
  List<BillHistory> _billHistory = [];
  bool _isLoading = false;
  String? _error;

  List<BillProvider> get providers => _providers;
  List<SavedBill> get savedBills => _savedBills;
  List<BillHistory> get billHistory => _billHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool loading) {
    _isLoading = loading;
    _error = null;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadBillProviders() async {
    setLoading(true);
    try {
      _providers = await _apiService.getBillProviders();
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
    }
  }

  Future<BillCheckResponse> checkBill({
    required String providerId,
    required String customerCode,
  }) async {
    try {
      return await _apiService.checkBill(
        providerId: providerId,
        customerCode: customerCode,
      );
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>> payBill({
    required String providerId,
    required String customerCode,
    required double amount,
    required String transactionPin,
    bool saveBill = false,
    String? alias,
  }) async {
    try {
      return await _apiService.payBill(
        providerId: providerId,
        customerCode: customerCode,
        amount: amount,
        transactionPin: transactionPin,
        saveBill: saveBill,
        alias: alias,
      );
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> loadSavedBills() async {
    setLoading(true);
    try {
      _savedBills = await _apiService.getSavedBills();
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
    }
  }

  Future<SavedBill> createSavedBill({
    required String providerId,
    required String customerCode,
    String? customerName,
    String? alias,
  }) async {
    try {
      final savedBill = await _apiService.createSavedBill(
        providerId: providerId,
        customerCode: customerCode,
        customerName: customerName,
        alias: alias,
      );
      await loadSavedBills();
      return savedBill;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<SavedBill> updateSavedBill({
    required String savedBillId,
    String? customerName,
    String? alias,
  }) async {
    try {
      final savedBill = await _apiService.updateSavedBill(
        savedBillId: savedBillId,
        customerName: customerName,
        alias: alias,
      );
      await loadSavedBills();
      return savedBill;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> deleteSavedBill(String savedBillId) async {
    try {
      await _apiService.deleteSavedBill(savedBillId);
      await loadSavedBills();
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> loadBillHistory() async {
    setLoading(true);
    try {
      _billHistory = await _apiService.getBillHistory();
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
    }
  }
}

class BudgetProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Budget> _budgets = [];
  BudgetStatus? _selectedBudget;
  bool _isLoading = false;
  String? _error;

  List<Budget> get budgets => _budgets;
  BudgetStatus? get selectedBudget => _selectedBudget;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool loading) {
    _isLoading = loading;
    _error = null;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadBudgets({int? year, int? month, String? category}) async {
    setLoading(true);
    try {
      _budgets = await _apiService.getBudgets(
        year: year,
        month: month,
        category: category,
      );
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
    }
  }

  Future<Budget> createBudget({
    required String category,
    required double amount,
    required String period,
    int? month,
    required int year,
  }) async {
    try {
      final budget = await _apiService.createBudget(
        category: category,
        amount: amount,
        period: period,
        month: month,
        year: year,
      );
      await loadBudgets();
      return budget;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<BudgetStatus> getBudgetStatus(String budgetId) async {
    setLoading(true);
    try {
      _selectedBudget = await _apiService.getBudgetStatus(budgetId);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return _selectedBudget!;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<Budget> updateBudget({
    required String budgetId,
    String? category,
    double? amount,
    String? period,
    int? month,
    int? year,
  }) async {
    try {
      final budget = await _apiService.updateBudget(
        budgetId: budgetId,
        category: category,
        amount: amount,
        period: period,
        month: month,
        year: year,
      );
      await loadBudgets();
      return budget;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    try {
      await _apiService.deleteBudget(budgetId);
      await loadBudgets();
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }
}

class SavingsGoalProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<SavingsGoal> _goals = [];
  SavingsGoal? _selectedGoal;
  bool _isLoading = false;
  String? _error;

  List<SavingsGoal> get goals => _goals;
  SavingsGoal? get selectedGoal => _selectedGoal;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool loading) {
    _isLoading = loading;
    _error = null;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSavingsGoals({bool includeCompleted = false}) async {
    setLoading(true);
    try {
      _goals = await _apiService.getSavingsGoals(
        includeCompleted: includeCompleted,
      );
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
    }
  }

  Future<SavingsGoal> createSavingsGoal({
    required String name,
    required double targetAmount,
    DateTime? deadline,
    double? autoDepositAmount,
  }) async {
    try {
      final goal = await _apiService.createSavingsGoal(
        name: name,
        targetAmount: targetAmount,
        deadline: deadline,
        autoDepositAmount: autoDepositAmount,
      );
      await loadSavingsGoals();
      return goal;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<SavingsGoal> getSavingsGoal(String goalId) async {
    setLoading(true);
    try {
      _selectedGoal = await _apiService.getSavingsGoal(goalId);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return _selectedGoal!;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<SavingsGoal> updateSavingsGoal({
    required String goalId,
    String? name,
    double? targetAmount,
    DateTime? deadline,
    double? autoDepositAmount,
    bool? isCompleted,
  }) async {
    try {
      final goal = await _apiService.updateSavingsGoal(
        goalId: goalId,
        name: name,
        targetAmount: targetAmount,
        deadline: deadline,
        autoDepositAmount: autoDepositAmount,
        isCompleted: isCompleted,
      );
      await loadSavingsGoals();
      return goal;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> deleteSavingsGoal(String goalId) async {
    try {
      await _apiService.deleteSavingsGoal(goalId);
      await loadSavingsGoals();
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<SavingsGoal> depositToSavingsGoal({
    required String goalId,
    required double amount,
  }) async {
    try {
      final goal = await _apiService.depositToSavingsGoal(
        goalId: goalId,
        amount: amount,
      );
      await loadSavingsGoals();
      // Reload wallet to update balance
      return goal;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<SavingsGoal> withdrawFromSavingsGoal({
    required String goalId,
    required double amount,
  }) async {
    try {
      final goal = await _apiService.withdrawFromSavingsGoal(
        goalId: goalId,
        amount: amount,
      );
      await loadSavingsGoals();
      // Reload wallet to update balance
      return goal;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }
}

class AnalyticsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  SpendingAnalytics? _spendingAnalytics;
  SpendingTrends? _spendingTrends;
  bool _isLoading = false;
  String? _error;

  SpendingAnalytics? get spendingAnalytics => _spendingAnalytics;
  SpendingTrends? get spendingTrends => _spendingTrends;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool loading) {
    _isLoading = loading;
    _error = null;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSpendingAnalytics({
    String period = 'month',
    int? year,
    int? month,
    String? category,
  }) async {
    setLoading(true);
    try {
      _spendingAnalytics = await _apiService.getSpendingAnalytics(
        period: period,
        year: year,
        month: month,
        category: category,
      );
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
    }
  }

  Future<void> loadSpendingTrends({String period = 'month'}) async {
    setLoading(true);
    try {
      _spendingTrends = await _apiService.getSpendingTrends(period: period);
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      setError(e.toString());
    }
  }
}

// ==================== Notification Provider ====================

class NotificationProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<models.Notification> _notifications = [];
  NotificationSettings? _settings;
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<models.Notification> get notifications => _notifications;
  NotificationSettings? get settings => _settings;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadNotifications({bool unreadOnly = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _notifications = await _apiService.getNotifications(
        unreadOnly: unreadOnly,
      );
      _unreadCount = await _apiService.getUnreadNotificationCount();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await _apiService.getNotificationSettings();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _apiService.getUnreadNotificationCount();
      notifyListeners();
    } catch (e) {
      // Silent fail for background refresh
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiService.markNotificationRead(notificationId);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = models.Notification(
          id: _notifications[index].id,
          userId: _notifications[index].userId,
          title: _notifications[index].title,
          message: _notifications[index].message,
          type: _notifications[index].type,
          isRead: true,
          data: _notifications[index].data,
          createdAt: _notifications[index].createdAt,
        );
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.markAllNotificationsRead();
      _notifications = _notifications
          .map(
            (n) => models.Notification(
              id: n.id,
              userId: n.userId,
              title: n.title,
              message: n.message,
              type: n.type,
              isRead: true,
              data: n.data,
              createdAt: n.createdAt,
            ),
          )
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _apiService.deleteNotification(notificationId);
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateSettings({
    bool? enableTransactionNotifications,
    bool? enablePromotionNotifications,
    bool? enableSecurityNotifications,
    bool? enableAlertNotifications,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await _apiService.updateNotificationSettings(
        enableTransactionNotifications: enableTransactionNotifications,
        enablePromotionNotifications: enablePromotionNotifications,
        enableSecurityNotifications: enableSecurityNotifications,
        enableAlertNotifications: enableAlertNotifications,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> registerDevice({
    required String deviceToken,
    required String deviceType,
  }) async {
    try {
      await _apiService.registerDevice(
        deviceToken: deviceToken,
        deviceType: deviceType,
      );
      // Reload settings to get updated device token
      await loadSettings();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}

// ==================== Alert Provider ====================

class AlertProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Alert> _alerts = [];
  AlertSettings? _settings;
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<Alert> get alerts => _alerts;
  AlertSettings? get settings => _settings;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAlerts({bool unreadOnly = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _alerts = await _apiService.getAlerts(unreadOnly: unreadOnly);
      _unreadCount = await _apiService.getUnreadAlertCount();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await _apiService.getAlertSettings();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _apiService.getUnreadAlertCount();
      notifyListeners();
    } catch (e) {
      // Silent fail for background refresh
    }
  }

  Future<void> markAsRead(String alertId) async {
    try {
      await _apiService.markAlertRead(alertId);
      final index = _alerts.indexWhere((a) => a.id == alertId);
      if (index != -1) {
        _alerts[index] = Alert(
          id: _alerts[index].id,
          userId: _alerts[index].userId,
          type: _alerts[index].type,
          title: _alerts[index].title,
          message: _alerts[index].message,
          severity: _alerts[index].severity,
          isRead: true,
          data: _alerts[index].data,
          createdAt: _alerts[index].createdAt,
        );
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.markAllAlertsRead();
      _alerts = _alerts
          .map(
            (a) => Alert(
              id: a.id,
              userId: a.userId,
              type: a.type,
              title: a.title,
              message: a.message,
              severity: a.severity,
              isRead: true,
              data: a.data,
              createdAt: a.createdAt,
            ),
          )
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteAlert(String alertId) async {
    try {
      await _apiService.deleteAlert(alertId);
      _alerts.removeWhere((a) => a.id == alertId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateSettings({
    double? largeTransactionThreshold,
    double? lowBalanceThreshold,
    double? budgetWarningPercentage,
    bool? enableLargeTransactionAlert,
    bool? enableLowBalanceAlert,
    bool? enableBudgetAlert,
    bool? enableNewDeviceAlert,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await _apiService.updateAlertSettings(
        largeTransactionThreshold: largeTransactionThreshold,
        lowBalanceThreshold: lowBalanceThreshold,
        budgetWarningPercentage: budgetWarningPercentage,
        enableLargeTransactionAlert: enableLargeTransactionAlert,
        enableLowBalanceAlert: enableLowBalanceAlert,
        enableBudgetAlert: enableBudgetAlert,
        enableNewDeviceAlert: enableNewDeviceAlert,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
