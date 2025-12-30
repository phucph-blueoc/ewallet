import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../utils/auth_exception.dart';
import '../utils/navigation_helper.dart';
import 'certificate_pinning_service.dart';

// Import Contact and ContactStats
import '../utils/constants.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  ApiService() {
    // Initialize Dio with certificate pinning
    _dio = CertificatePinningService.createPinnedDio();
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  // Auth Methods
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {'email': email, 'password': password, 'full_name': fullName},
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Registration failed');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/verify-otp',
        data: {'email': email, 'otp_code': otpCode},
      );

      if (response.statusCode != 200) {
        final error = response.data;
        throw Exception(error['detail'] ?? 'OTP verification failed');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> resendOtp(String email) async {
    try {
      final response = await _dio.post(
        '/auth/resend-otp',
        data: {'email': email},
      );

      if (response.statusCode != 200) {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to resend OTP');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode != 200) {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to change password');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'username': email, 'password': password},
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        // Save tokens
        await _storage.write(key: 'access_token', value: data['access_token']);
        await _storage.write(
          key: 'refresh_token',
          value: data['refresh_token'],
        );
        return data;
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Login failed');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<Options> _getOptions({Map<String, dynamic>? extraHeaders}) async {
    final token = await getAccessToken();
    return Options(
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (extraHeaders != null) ...extraHeaders,
      },
    );
  }

  /// Check response status and handle 401 Unauthorized
  /// Throws UnauthorizedException if status is 401
  /// Automatically logs out and navigates to login screen
  Future<void> _handleResponse(Response response) async {
    if (response.statusCode == 401) {
      // Clear tokens on 401
      await logout();
      // Automatically handle logout and navigation
      await handleUnauthorized(null);
      throw UnauthorizedException('Phiên đã hết hạn. Vui lòng đăng nhập lại.');
    }
  }

  /// Handle Dio errors and convert to appropriate exceptions
  Exception _handleDioError(DioException error) {
    if (error.response != null) {
      // Server responded with error status
      final statusCode = error.response!.statusCode;
      final errorData = error.response!.data;

      String errorMessage = 'Request failed';
      if (errorData is Map && errorData.containsKey('detail')) {
        errorMessage = errorData['detail'].toString();
      } else if (errorData is String) {
        errorMessage = errorData;
      } else {
        errorMessage =
            'HTTP $statusCode: ${error.response?.statusMessage ?? 'Unknown error'}';
      }

      if (statusCode == 403) {
        errorMessage = 'Không có quyền truy cập.';
      } else if (statusCode == 404) {
        errorMessage = 'Resource not found.';
      } else if (statusCode != null && statusCode >= 500) {
        errorMessage = 'Server error. Please try again later.';
      }

      return Exception(errorMessage);
    } else if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return Exception(
        'Request timeout. Please check if the backend server is running at $baseUrl',
      );
    } else if (error.type == DioExceptionType.connectionError) {
      return Exception(
        'Network error: Unable to connect to server at $baseUrl. Please check if the backend is running.',
      );
    } else {
      return Exception('Unexpected error: ${error.message}');
    }
  }

  // Wallet Methods
  Future<Wallet> getWallet() async {
    try {
      final token = await getAccessToken();

      // Check if token exists
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found. Please login again.');
      }

      final options = await _getOptions();
      final response = await _dio.get('/wallets/me', options: options);

      if (response.statusCode == 200) {
        try {
          return Wallet.fromJson(response.data as Map<String, dynamic>);
        } catch (e) {
          throw Exception('Failed to parse wallet data: $e');
        }
      } else {
        await _handleResponse(response);
        throw Exception('Failed to fetch wallet');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Wallet> deposit({
    required double amount,
    String sourceType = 'manual',
    String? sourceId,
    String? transactionPin,
  }) async {
    try {
      final token = await getAccessToken();

      // Check if token exists
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found. Please login again.');
      }

      // Validate amount
      if (amount <= 0) {
        throw Exception('Deposit amount must be greater than 0');
      }

      final body = {
        'amount': amount,
        'source_type': sourceType,
        if (sourceId != null) 'source_id': sourceId,
        if (transactionPin != null) 'transaction_pin': transactionPin,
      };

      final options = await _getOptions();
      final response = await _dio.post(
        '/wallets/deposit',
        data: body,
        options: options,
      );

      if (response.statusCode == 200) {
        try {
          return Wallet.fromJson(response.data as Map<String, dynamic>);
        } catch (e) {
          throw Exception('Failed to parse wallet data: $e');
        }
      } else {
        await _handleResponse(response);
        throw Exception('Deposit failed');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Wallet> withdraw({
    required double amount,
    String destinationType = 'manual',
    String? destinationId,
    String? transactionPin,
  }) async {
    try {
      final token = await getAccessToken();

      // Check if token exists
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found. Please login again.');
      }

      // Validate amount
      if (amount <= 0) {
        throw Exception('Withdrawal amount must be greater than 0');
      }

      final body = {
        'amount': amount,
        'destination_type': destinationType,
        if (destinationId != null) 'destination_id': destinationId,
        if (transactionPin != null) 'transaction_pin': transactionPin,
      };

      final options = await _getOptions();
      final response = await _dio.post(
        '/wallets/withdraw',
        data: body,
        options: options,
      );

      if (response.statusCode == 200) {
        try {
          return Wallet.fromJson(response.data as Map<String, dynamic>);
        } catch (e) {
          throw Exception('Failed to parse wallet data: $e');
        }
      } else {
        await _handleResponse(response);
        throw Exception('Withdrawal failed');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> requestTransferOtp({
    required String receiverEmail,
    required double amount,
    required String transactionPin,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/wallets/transfer/request-otp',
        data: {
          'receiver_email': receiverEmail,
          'amount': amount,
          'transaction_pin': transactionPin,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to request OTP');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<Transaction> transfer({
    required String receiverEmail,
    required double amount,
    required String transactionPin,
    required String otpCode,
    String? note,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/wallets/transfer',
        data: {
          'receiver_email': receiverEmail,
          'amount': amount,
          'transaction_pin': transactionPin,
          'otp_code': otpCode,
          if (note != null) 'note': note,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return Transaction.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Transfer failed');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> setTransactionPin({
    required String currentPassword,
    required String transactionPin,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/auth/transaction-pin/set',
        data: {
          'current_password': currentPassword,
          'transaction_pin': transactionPin,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode != 200) {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to set PIN');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> verifyTransactionPin(String transactionPin) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/auth/transaction-pin/verify',
        data: {'transaction_pin': transactionPin},
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode != 200) {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Invalid transaction PIN');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<List<Transaction>> getTransactions() async {
    try {
      final options = await _getOptions();
      final response = await _dio.get(
        '/wallets/transactions',
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to fetch transactions');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  // Contact Methods
  Future<Contact> createContact({
    required String name,
    required String email,
    String? phone,
    String? avatarUrl,
    String? notes,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/contacts',
        data: {
          'name': name,
          'email': email,
          if (phone != null) 'phone': phone,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (notes != null) 'notes': notes,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 201) {
        return Contact.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to create contact');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<List<Contact>> getContacts({String? search}) async {
    try {
      final options = await _getOptions();
      final queryParams = search != null && search.isNotEmpty
          ? {'search': search}
          : null;
      final response = await _dio.get(
        '/contacts',
        queryParameters: queryParams,
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => Contact.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to fetch contacts');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<Contact> getContact(String contactId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.get('/contacts/$contactId', options: options);

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return Contact.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to fetch contact');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
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
      final options = await _getOptions();
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      if (avatarUrl != null) body['avatar_url'] = avatarUrl;
      if (notes != null) body['notes'] = notes;

      final response = await _dio.put(
        '/contacts/$contactId',
        data: body,
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return Contact.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to update contact');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.delete(
        '/contacts/$contactId',
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode != 204) {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to delete contact');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<ContactStats> getContactStats(String contactId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.get(
        '/contacts/$contactId/stats',
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return ContactStats.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to fetch contact stats');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  // Bank Card Methods
  Future<BankCard> createBankCard({
    required String cardNumber,
    required String cardHolderName,
    required String expiryDate,
    required String cvv,
    required String bankName,
    required String cardType,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/cards',
        data: {
          'card_number': cardNumber,
          'card_holder_name': cardHolderName,
          'expiry_date': expiryDate,
          'cvv': cvv,
          'bank_name': bankName,
          'card_type': cardType,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 201) {
        return BankCard.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to create bank card');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<List<BankCard>> getBankCards() async {
    try {
      final options = await _getOptions();
      final response = await _dio.get('/cards', options: options);

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => BankCard.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to fetch bank cards');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<BankCard> getBankCard(String cardId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.get('/cards/$cardId', options: options);

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return BankCard.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to fetch bank card');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<BankCard> updateBankCard({
    required String cardId,
    String? cardHolderName,
    String? bankName,
  }) async {
    try {
      final options = await _getOptions();
      final body = <String, dynamic>{};
      if (cardHolderName != null) body['card_holder_name'] = cardHolderName;
      if (bankName != null) body['bank_name'] = bankName;

      final response = await _dio.put(
        '/cards/$cardId',
        data: body,
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return BankCard.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to update bank card');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> deleteBankCard(String cardId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.delete('/cards/$cardId', options: options);

      await _handleResponse(response);

      if (response.statusCode != 204) {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to delete bank card');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<BankCard> verifyBankCard({
    required String cardId,
    required String otpCode,
  }) async {
    print('[API] verifyBankCard called: cardId=$cardId, otpCode=$otpCode');
    try {
      final options = await _getOptions();
      print('[API] POST /cards/$cardId/verify');
      print('[API] Headers: ${options.headers?.keys}');
      print('[API] Body: {"otp_code": "$otpCode"}');

      final response = await _dio.post(
        '/cards/$cardId/verify',
        data: {'otp_code': otpCode},
        options: options,
      );

      print('[API] Response status: ${response.statusCode}');
      print('[API] Response body: ${response.data}');

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return BankCard.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        final errorMsg = error['detail'] ?? 'Failed to verify bank card';
        print('[API] Error: $errorMsg');
        throw Exception(errorMsg);
      }
    } on DioException catch (e) {
      print('[API] Exception in verifyBankCard: $e');
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    } catch (e) {
      print('[API] Exception in verifyBankCard: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resendCardVerificationOtp(String cardId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/cards/$cardId/resend-otp',
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to resend OTP');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<Wallet> depositFromCard({
    required String cardId,
    required double amount,
    required String transactionPin,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/wallets/deposit-from-card',
        data: {
          'card_id': cardId,
          'amount': amount,
          'transaction_pin': transactionPin,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return Wallet.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to deposit from card');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<Wallet> withdrawToCard({
    required String cardId,
    required double amount,
    required String transactionPin,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/wallets/withdraw-to-card',
        data: {
          'card_id': cardId,
          'amount': amount,
          'transaction_pin': transactionPin,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return Wallet.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to withdraw to card');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  // ==================== Bill Methods ====================

  Future<List<BillProvider>> getBillProviders() async {
    try {
      final options = await _getOptions();
      final response = await _dio.get('/bills/providers', options: options);

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => BillProvider.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get bill providers');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<BillCheckResponse> checkBill({
    required String providerId,
    required String customerCode,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/bills/check',
        data: {'provider_id': providerId, 'customer_code': customerCode},
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return BillCheckResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to check bill');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
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
      final options = await _getOptions();
      final response = await _dio.post(
        '/bills/pay',
        data: {
          'provider_id': providerId,
          'customer_code': customerCode,
          'amount': amount,
          'transaction_pin': transactionPin,
          'save_bill': saveBill,
          if (alias != null) 'alias': alias,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to pay bill');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<List<SavedBill>> getSavedBills() async {
    try {
      final options = await _getOptions();
      final response = await _dio.get('/bills/saved', options: options);

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => SavedBill.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get saved bills');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<SavedBill> createSavedBill({
    required String providerId,
    required String customerCode,
    String? customerName,
    String? alias,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/bills/saved',
        data: {
          'provider_id': providerId,
          'customer_code': customerCode,
          if (customerName != null) 'customer_name': customerName,
          if (alias != null) 'alias': alias,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 201) {
        return SavedBill.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to save bill');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<SavedBill> updateSavedBill({
    required String savedBillId,
    String? customerName,
    String? alias,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.put(
        '/bills/saved/$savedBillId',
        data: {
          if (customerName != null) 'customer_name': customerName,
          if (alias != null) 'alias': alias,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return SavedBill.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to update saved bill');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> deleteSavedBill(String savedBillId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.delete(
        '/bills/saved/$savedBillId',
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode != 204) {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to delete saved bill');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<List<BillHistory>> getBillHistory() async {
    try {
      final options = await _getOptions();
      final response = await _dio.get('/bills/history', options: options);

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => BillHistory.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get bill history');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  // ==================== Budget Methods ====================

  Future<Budget> createBudget({
    required String category,
    required double amount,
    required String period,
    int? month,
    required int year,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/budgets',
        data: {
          'category': category,
          'amount': amount,
          'period': period,
          if (month != null) 'month': month,
          'year': year,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 201) {
        return Budget.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to create budget');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<List<Budget>> getBudgets({
    int? year,
    int? month,
    String? category,
  }) async {
    try {
      final options = await _getOptions();
      final queryParams = <String, dynamic>{};
      if (year != null) queryParams['year'] = year.toString();
      if (month != null) queryParams['month'] = month.toString();
      if (category != null) queryParams['category'] = category;

      final response = await _dio.get(
        '/budgets',
        queryParameters: queryParams,
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => Budget.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get budgets');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<BudgetStatus> getBudget(String budgetId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.get('/budgets/$budgetId', options: options);

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return BudgetStatus.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get budget');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<BudgetStatus> getBudgetStatus(String budgetId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.get(
        '/budgets/$budgetId/status',
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return BudgetStatus.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get budget status');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
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
      final options = await _getOptions();
      final body = <String, dynamic>{};
      if (category != null) body['category'] = category;
      if (amount != null) body['amount'] = amount;
      if (period != null) body['period'] = period;
      if (month != null) body['month'] = month;
      if (year != null) body['year'] = year;

      final response = await _dio.put(
        '/budgets/$budgetId',
        data: body,
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return Budget.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to update budget');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.delete(
        '/budgets/$budgetId',
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode != 204) {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to delete budget');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  // ==================== Savings Goals Methods ====================

  Future<SavingsGoal> createSavingsGoal({
    required String name,
    required double targetAmount,
    DateTime? deadline,
    double? autoDepositAmount,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/savings-goals',
        data: {
          'name': name,
          'target_amount': targetAmount,
          if (deadline != null)
            'deadline': deadline.toIso8601String().split('T')[0],
          if (autoDepositAmount != null)
            'auto_deposit_amount': autoDepositAmount,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 201) {
        return SavingsGoal.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to create savings goal');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<List<SavingsGoal>> getSavingsGoals({
    bool includeCompleted = false,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.get(
        '/savings-goals',
        queryParameters: {'include_completed': includeCompleted.toString()},
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => SavingsGoal.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get savings goals');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<SavingsGoal> getSavingsGoal(String goalId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.get(
        '/savings-goals/$goalId',
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return SavingsGoal.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get savings goal');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
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
      final options = await _getOptions();
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (targetAmount != null) body['target_amount'] = targetAmount;
      if (deadline != null)
        body['deadline'] = deadline.toIso8601String().split('T')[0];
      if (autoDepositAmount != null)
        body['auto_deposit_amount'] = autoDepositAmount;
      if (isCompleted != null) body['is_completed'] = isCompleted;

      final response = await _dio.put(
        '/savings-goals/$goalId',
        data: body,
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return SavingsGoal.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to update savings goal');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> deleteSavingsGoal(String goalId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.delete(
        '/savings-goals/$goalId',
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode != 204) {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to delete savings goal');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<SavingsGoal> depositToSavingsGoal({
    required String goalId,
    required double amount,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/savings-goals/$goalId/deposit',
        data: {'amount': amount},
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return SavingsGoal.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to deposit to savings goal');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<SavingsGoal> withdrawFromSavingsGoal({
    required String goalId,
    required double amount,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/savings-goals/$goalId/withdraw',
        data: {'amount': amount},
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return SavingsGoal.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(
          error['detail'] ?? 'Failed to withdraw from savings goal',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  // ==================== Analytics Methods ====================

  Future<SpendingAnalytics> getSpendingAnalytics({
    String period = 'month',
    int? year,
    int? month,
    String? category,
  }) async {
    try {
      final options = await _getOptions();
      final queryParams = <String, dynamic>{'period': period};
      if (year != null) queryParams['year'] = year.toString();
      if (month != null) queryParams['month'] = month.toString();
      if (category != null) queryParams['category'] = category;

      final response = await _dio.get(
        '/analytics/spending',
        queryParameters: queryParams,
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return SpendingAnalytics.fromJson(
          response.data as Map<String, dynamic>,
        );
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get spending analytics');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<SpendingTrends> getSpendingTrends({String period = 'month'}) async {
    try {
      final options = await _getOptions();
      final response = await _dio.get(
        '/analytics/trends',
        queryParameters: {'period': period},
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return SpendingTrends.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get spending trends');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  // ==================== Notification Methods ====================

  Future<void> registerDevice({
    required String deviceToken,
    required String deviceType, // IOS, ANDROID, WEB
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/notifications/register',
        data: {'device_token': deviceToken, 'device_type': deviceType},
        options: options,
      );

      await _handleResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<List<Notification>> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.get(
        '/notifications',
        queryParameters: {
          'unread_only': unreadOnly.toString(),
          'limit': limit.toString(),
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => Notification.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get notifications');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final options = await _getOptions();
      final response = await _dio.get(
        '/notifications/unread-count',
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['unread_count'] ?? 0;
      } else {
        final error = response.data;
        throw Exception(
          error['detail'] ?? 'Failed to get unread notification count',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.put(
        '/notifications/$notificationId/read',
        options: options,
      );

      await _handleResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      final options = await _getOptions();
      final response = await _dio.put(
        '/notifications/read-all',
        options: options,
      );

      await _handleResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.delete(
        '/notifications/$notificationId',
        options: options,
      );

      await _handleResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<NotificationSettings> getNotificationSettings() async {
    try {
      final options = await _getOptions();
      final response = await _dio.get(
        '/notifications/settings',
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return NotificationSettings.fromJson(
          response.data as Map<String, dynamic>,
        );
      } else {
        final error = response.data;
        throw Exception(
          error['detail'] ?? 'Failed to get notification settings',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<NotificationSettings> updateNotificationSettings({
    bool? enableTransactionNotifications,
    bool? enablePromotionNotifications,
    bool? enableSecurityNotifications,
    bool? enableAlertNotifications,
  }) async {
    try {
      final options = await _getOptions();
      final body = <String, dynamic>{};
      if (enableTransactionNotifications != null) {
        body['enable_transaction_notifications'] =
            enableTransactionNotifications;
      }
      if (enablePromotionNotifications != null) {
        body['enable_promotion_notifications'] = enablePromotionNotifications;
      }
      if (enableSecurityNotifications != null) {
        body['enable_security_notifications'] = enableSecurityNotifications;
      }
      if (enableAlertNotifications != null) {
        body['enable_alert_notifications'] = enableAlertNotifications;
      }

      final response = await _dio.put(
        '/notifications/settings',
        data: body,
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return NotificationSettings.fromJson(
          response.data as Map<String, dynamic>,
        );
      } else {
        final error = response.data;
        throw Exception(
          error['detail'] ?? 'Failed to update notification settings',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  // ==================== Alert Methods ====================

  Future<List<Alert>> getAlerts({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.get(
        '/alerts',
        queryParameters: {
          'unread_only': unreadOnly.toString(),
          'limit': limit.toString(),
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => Alert.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get alerts');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<int> getUnreadAlertCount() async {
    try {
      final options = await _getOptions();
      final response = await _dio.get('/alerts/unread-count', options: options);

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['unread_count'] ?? 0;
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get unread alert count');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> markAlertRead(String alertId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.put(
        '/alerts/$alertId/read',
        options: options,
      );

      await _handleResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> markAllAlertsRead() async {
    try {
      final options = await _getOptions();
      final response = await _dio.put('/alerts/read-all', options: options);

      await _handleResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> deleteAlert(String alertId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.delete('/alerts/$alertId', options: options);

      await _handleResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<AlertSettings> getAlertSettings() async {
    try {
      final options = await _getOptions();
      final response = await _dio.get('/alerts/settings', options: options);

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return AlertSettings.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get alert settings');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<AlertSettings> updateAlertSettings({
    double? largeTransactionThreshold,
    double? lowBalanceThreshold,
    double? budgetWarningPercentage,
    bool? enableLargeTransactionAlert,
    bool? enableLowBalanceAlert,
    bool? enableBudgetAlert,
    bool? enableNewDeviceAlert,
  }) async {
    try {
      final options = await _getOptions();
      final body = <String, dynamic>{};
      if (largeTransactionThreshold != null) {
        body['large_transaction_threshold'] = largeTransactionThreshold;
      }
      if (lowBalanceThreshold != null) {
        body['low_balance_threshold'] = lowBalanceThreshold;
      }
      if (budgetWarningPercentage != null) {
        body['budget_warning_percentage'] = budgetWarningPercentage;
      }
      if (enableLargeTransactionAlert != null) {
        body['enable_large_transaction_alert'] = enableLargeTransactionAlert;
      }
      if (enableLowBalanceAlert != null) {
        body['enable_low_balance_alert'] = enableLowBalanceAlert;
      }
      if (enableBudgetAlert != null) {
        body['enable_budget_alert'] = enableBudgetAlert;
      }
      if (enableNewDeviceAlert != null) {
        body['enable_new_device_alert'] = enableNewDeviceAlert;
      }

      final response = await _dio.put(
        '/alerts/settings',
        data: body,
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return AlertSettings.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to update alert settings');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  // ==================== Device Methods ====================

  Future<List<UserDevice>> getDevices() async {
    try {
      final options = await _getOptions();
      final response = await _dio.get('/devices', options: options);

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => UserDevice.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get devices');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<UserDevice> createDevice({
    required String deviceName,
    required String deviceType,
    String? deviceToken,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/devices',
        data: {
          'device_name': deviceName,
          'device_type': deviceType,
          if (deviceToken != null) 'device_token': deviceToken,
          if (ipAddress != null) 'ip_address': ipAddress,
          if (userAgent != null) 'user_agent': userAgent,
        },
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 201) {
        return UserDevice.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to create device');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<UserDevice> renameDevice({
    required String deviceId,
    required String deviceName,
  }) async {
    try {
      final options = await _getOptions();
      final response = await _dio.post(
        '/devices/$deviceId/rename',
        data: {'device_name': deviceName},
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return UserDevice.fromJson(response.data as Map<String, dynamic>);
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to rename device');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  Future<void> deleteDevice(String deviceId) async {
    try {
      final options = await _getOptions();
      final response = await _dio.delete(
        '/devices/$deviceId',
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode != 204) {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to delete device');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }

  // ==================== Security History Methods ====================

  Future<List<SecurityHistory>> getSecurityHistory({
    int limit = 50,
    int offset = 0,
    String? actionType,
  }) async {
    try {
      final options = await _getOptions();
      final queryParams = <String, dynamic>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (actionType != null) {
        queryParams['action_type'] = actionType;
      }

      final response = await _dio.get(
        '/security/history',
        queryParameters: queryParams,
        options: options,
      );

      await _handleResponse(response);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map(
              (json) => SecurityHistory.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to get security history');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _handleResponse(e.response!);
      }
      throw _handleDioError(e);
    }
  }
}
