import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../utils/auth_exception.dart';
import '../utils/navigation_helper.dart';

// Import Contact and ContactStats
import '../utils/constants.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();

  // Auth Methods
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Registration failed');
    }
  }

  Future<void> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp_code': otpCode}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'OTP verification failed');
    }
  }

  Future<void> resendOtp(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/resend-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to resend OTP');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to change password');
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Save tokens
      await _storage.write(key: 'access_token', value: data['access_token']);
      await _storage.write(key: 'refresh_token', value: data['refresh_token']);
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Login failed');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Check response status and handle 401 Unauthorized
  /// Throws UnauthorizedException if status is 401
  /// Automatically logs out and navigates to login screen
  Future<void> _handleResponse(http.Response response) async {
    if (response.statusCode == 401) {
      // Clear tokens on 401
      await logout();
      // Automatically handle logout and navigation
      await handleUnauthorized(null);
      throw UnauthorizedException('Phiên đã hết hạn. Vui lòng đăng nhập lại.');
    }
  }

  // Wallet Methods
  Future<Wallet> getWallet() async {
    try {
      final headers = await _getHeaders();
      final token = await getAccessToken();

      // Check if token exists
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found. Please login again.');
      }

      final response = await http
          .get(Uri.parse('$baseUrl/wallets/me'), headers: headers)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Request timeout. Please check if the backend server is running at $baseUrl',
              );
            },
          );

      if (response.statusCode == 200) {
        try {
          return Wallet.fromJson(jsonDecode(response.body));
        } catch (e) {
          throw Exception('Failed to parse wallet data: $e');
        }
      } else {
        // Parse error message from response
        String errorMessage = 'Failed to fetch wallet';
        try {
          if (response.body.isNotEmpty) {
            final errorBody = jsonDecode(response.body);
            if (errorBody is Map && errorBody.containsKey('detail')) {
              errorMessage = errorBody['detail'].toString();
            } else {
              errorMessage =
                  'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
            }
          } else {
            errorMessage =
                'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
          }
        } catch (e) {
          // If parsing fails, use status code
          errorMessage =
              'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
          if (response.body.isNotEmpty) {
            errorMessage += '\nResponse: ${response.body}';
          }
        }

        // Check for authentication errors
        await _handleResponse(response);

        if (response.statusCode == 403) {
          errorMessage = 'Không có quyền truy cập.';
        } else if (response.statusCode == 404) {
          errorMessage = 'Wallet not found. Please contact support.';
        } else if (response.statusCode >= 500) {
          errorMessage = 'Server error. Please try again later.';
        }

        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      throw Exception(
        'Network error: Unable to connect to server at $baseUrl. Please check if the backend is running.\nError: ${e.message}',
      );
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
      final headers = await _getHeaders();
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

      final response = await http
          .post(
            Uri.parse('$baseUrl/wallets/deposit'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Request timeout. Please check if the backend server is running at $baseUrl',
              );
            },
          );

      if (response.statusCode == 200) {
        try {
          return Wallet.fromJson(jsonDecode(response.body));
        } catch (e) {
          throw Exception('Failed to parse wallet data: $e');
        }
      } else {
        // Parse error message from response
        String errorMessage = 'Deposit failed';
        try {
          if (response.body.isNotEmpty) {
            final errorBody = jsonDecode(response.body);
            if (errorBody is Map && errorBody.containsKey('detail')) {
              errorMessage = errorBody['detail'].toString();
            } else {
              errorMessage =
                  'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
            }
          } else {
            errorMessage =
                'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
          }
        } catch (e) {
          errorMessage =
              'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
          if (response.body.isNotEmpty) {
            errorMessage += '\nResponse: ${response.body}';
          }
        }

        // Check for authentication errors
        await _handleResponse(response);

        if (response.statusCode == 403) {
          errorMessage = 'Không có quyền truy cập.';
        } else if (response.statusCode == 400) {
          // Keep the detailed error message from server
        } else if (response.statusCode >= 500) {
          errorMessage = 'Server error. Please try again later.';
        }

        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      throw Exception(
        'Network error: Unable to connect to server at $baseUrl. Please check if the backend is running.\nError: ${e.message}',
      );
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
      final headers = await _getHeaders();
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

      final response = await http
          .post(
            Uri.parse('$baseUrl/wallets/withdraw'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Request timeout. Please check if the backend server is running at $baseUrl',
              );
            },
          );

      if (response.statusCode == 200) {
        try {
          return Wallet.fromJson(jsonDecode(response.body));
        } catch (e) {
          throw Exception('Failed to parse wallet data: $e');
        }
      } else {
        // Parse error message from response
        String errorMessage = 'Withdrawal failed';
        try {
          if (response.body.isNotEmpty) {
            final errorBody = jsonDecode(response.body);
            if (errorBody is Map && errorBody.containsKey('detail')) {
              errorMessage = errorBody['detail'].toString();
            } else {
              errorMessage =
                  'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
            }
          } else {
            errorMessage =
                'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
          }
        } catch (e) {
          errorMessage =
              'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
          if (response.body.isNotEmpty) {
            errorMessage += '\nResponse: ${response.body}';
          }
        }

        // Check for authentication errors
        await _handleResponse(response);

        if (response.statusCode == 403) {
          errorMessage = 'Không có quyền truy cập.';
        } else if (response.statusCode == 400) {
          // Keep the detailed error message from server (e.g., "Insufficient funds")
        } else if (response.statusCode >= 500) {
          errorMessage = 'Server error. Please try again later.';
        }

        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      throw Exception(
        'Network error: Unable to connect to server at $baseUrl. Please check if the backend is running.\nError: ${e.message}',
      );
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
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/wallets/transfer/request-otp'),
      headers: headers,
      body: jsonEncode({
        'receiver_email': receiverEmail,
        'amount': amount,
        'transaction_pin': transactionPin,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to request OTP');
    }
  }

  Future<Transaction> transfer({
    required String receiverEmail,
    required double amount,
    required String transactionPin,
    required String otpCode,
    String? note,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/wallets/transfer'),
      headers: headers,
      body: jsonEncode({
        'receiver_email': receiverEmail,
        'amount': amount,
        'transaction_pin': transactionPin,
        'otp_code': otpCode,
        if (note != null) 'note': note,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return Transaction.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Transfer failed');
    }
  }

  Future<void> setTransactionPin({
    required String currentPassword,
    required String transactionPin,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/transaction-pin/set'),
      headers: headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'transaction_pin': transactionPin,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to set PIN');
    }
  }

  Future<void> verifyTransactionPin(String transactionPin) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/transaction-pin/verify'),
      headers: headers,
      body: jsonEncode({'transaction_pin': transactionPin}),
    );

    await _handleResponse(response);

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Invalid transaction PIN');
    }
  }

  Future<List<Transaction>> getTransactions() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/wallets/transactions'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Transaction.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch transactions');
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
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/contacts'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        if (phone != null) 'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (notes != null) 'notes': notes,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 201) {
      return Contact.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to create contact');
    }
  }

  Future<List<Contact>> getContacts({String? search}) async {
    final headers = await _getHeaders();
    final uri = search != null && search.isNotEmpty
        ? Uri.parse('$baseUrl/contacts?search=$search')
        : Uri.parse('$baseUrl/contacts');

    final response = await http.get(uri, headers: headers);

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Contact.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch contacts');
    }
  }

  Future<Contact> getContact(String contactId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/contacts/$contactId'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return Contact.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to fetch contact');
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
    final headers = await _getHeaders();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (notes != null) body['notes'] = notes;

    final response = await http.put(
      Uri.parse('$baseUrl/contacts/$contactId'),
      headers: headers,
      body: jsonEncode(body),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return Contact.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update contact');
    }
  }

  Future<void> deleteContact(String contactId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/contacts/$contactId'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to delete contact');
    }
  }

  Future<ContactStats> getContactStats(String contactId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/contacts/$contactId/stats'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return ContactStats.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to fetch contact stats');
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
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/cards'),
      headers: headers,
      body: jsonEncode({
        'card_number': cardNumber,
        'card_holder_name': cardHolderName,
        'expiry_date': expiryDate,
        'cvv': cvv,
        'bank_name': bankName,
        'card_type': cardType,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 201) {
      return BankCard.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to create bank card');
    }
  }

  Future<List<BankCard>> getBankCards() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/cards'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BankCard.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch bank cards');
    }
  }

  Future<BankCard> getBankCard(String cardId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/cards/$cardId'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return BankCard.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to fetch bank card');
    }
  }

  Future<BankCard> updateBankCard({
    required String cardId,
    String? cardHolderName,
    String? bankName,
  }) async {
    final headers = await _getHeaders();
    final body = <String, dynamic>{};
    if (cardHolderName != null) body['card_holder_name'] = cardHolderName;
    if (bankName != null) body['bank_name'] = bankName;

    final response = await http.put(
      Uri.parse('$baseUrl/cards/$cardId'),
      headers: headers,
      body: jsonEncode(body),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return BankCard.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update bank card');
    }
  }

  Future<void> deleteBankCard(String cardId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/cards/$cardId'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to delete bank card');
    }
  }

  Future<BankCard> verifyBankCard({
    required String cardId,
    required String otpCode,
  }) async {
    print('[API] verifyBankCard called: cardId=$cardId, otpCode=$otpCode');
    final headers = await _getHeaders();
    final url = '$baseUrl/cards/$cardId/verify';
    print('[API] POST $url');
    print('[API] Headers: ${headers.keys}');
    print('[API] Body: {"otp_code": "$otpCode"}');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({'otp_code': otpCode}),
      );

      print('[API] Response status: ${response.statusCode}');
      print('[API] Response body: ${response.body}');

      await _handleResponse(response);

      if (response.statusCode == 200) {
        return BankCard.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        final errorMsg = error['detail'] ?? 'Failed to verify bank card';
        print('[API] Error: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('[API] Exception in verifyBankCard: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resendCardVerificationOtp(String cardId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/cards/$cardId/resend-otp'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to resend OTP');
    }
  }

  Future<Wallet> depositFromCard({
    required String cardId,
    required double amount,
    required String transactionPin,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/wallets/deposit-from-card'),
      headers: headers,
      body: jsonEncode({
        'card_id': cardId,
        'amount': amount,
        'transaction_pin': transactionPin,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return Wallet.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to deposit from card');
    }
  }

  Future<Wallet> withdrawToCard({
    required String cardId,
    required double amount,
    required String transactionPin,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/wallets/withdraw-to-card'),
      headers: headers,
      body: jsonEncode({
        'card_id': cardId,
        'amount': amount,
        'transaction_pin': transactionPin,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return Wallet.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to withdraw to card');
    }
  }

  // ==================== Bill Methods ====================

  Future<List<BillProvider>> getBillProviders() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/bills/providers'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BillProvider.fromJson(json)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get bill providers');
    }
  }

  Future<BillCheckResponse> checkBill({
    required String providerId,
    required String customerCode,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/bills/check'),
      headers: headers,
      body: jsonEncode({
        'provider_id': providerId,
        'customer_code': customerCode,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return BillCheckResponse.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to check bill');
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
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/bills/pay'),
      headers: headers,
      body: jsonEncode({
        'provider_id': providerId,
        'customer_code': customerCode,
        'amount': amount,
        'transaction_pin': transactionPin,
        'save_bill': saveBill,
        if (alias != null) 'alias': alias,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to pay bill');
    }
  }

  Future<List<SavedBill>> getSavedBills() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/bills/saved'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => SavedBill.fromJson(json)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get saved bills');
    }
  }

  Future<SavedBill> createSavedBill({
    required String providerId,
    required String customerCode,
    String? customerName,
    String? alias,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/bills/saved'),
      headers: headers,
      body: jsonEncode({
        'provider_id': providerId,
        'customer_code': customerCode,
        if (customerName != null) 'customer_name': customerName,
        if (alias != null) 'alias': alias,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 201) {
      return SavedBill.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to save bill');
    }
  }

  Future<SavedBill> updateSavedBill({
    required String savedBillId,
    String? customerName,
    String? alias,
  }) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/bills/saved/$savedBillId'),
      headers: headers,
      body: jsonEncode({
        if (customerName != null) 'customer_name': customerName,
        if (alias != null) 'alias': alias,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return SavedBill.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update saved bill');
    }
  }

  Future<void> deleteSavedBill(String savedBillId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/bills/saved/$savedBillId'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to delete saved bill');
    }
  }

  Future<List<BillHistory>> getBillHistory() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/bills/history'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => BillHistory.fromJson(json)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get bill history');
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
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/budgets'),
      headers: headers,
      body: jsonEncode({
        'category': category,
        'amount': amount,
        'period': period,
        if (month != null) 'month': month,
        'year': year,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 201) {
      return Budget.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to create budget');
    }
  }

  Future<List<Budget>> getBudgets({
    int? year,
    int? month,
    String? category,
  }) async {
    final headers = await _getHeaders();
    final queryParams = <String, String>{};
    if (year != null) queryParams['year'] = year.toString();
    if (month != null) queryParams['month'] = month.toString();
    if (category != null) queryParams['category'] = category;

    final uri = Uri.parse(
      '$baseUrl/budgets',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Budget.fromJson(json)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get budgets');
    }
  }

  Future<BudgetStatus> getBudget(String budgetId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/budgets/$budgetId'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return BudgetStatus.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get budget');
    }
  }

  Future<BudgetStatus> getBudgetStatus(String budgetId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/budgets/$budgetId/status'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return BudgetStatus.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get budget status');
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
    final headers = await _getHeaders();
    final body = <String, dynamic>{};
    if (category != null) body['category'] = category;
    if (amount != null) body['amount'] = amount;
    if (period != null) body['period'] = period;
    if (month != null) body['month'] = month;
    if (year != null) body['year'] = year;

    final response = await http.put(
      Uri.parse('$baseUrl/budgets/$budgetId'),
      headers: headers,
      body: jsonEncode(body),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return Budget.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update budget');
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/budgets/$budgetId'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to delete budget');
    }
  }

  // ==================== Savings Goals Methods ====================

  Future<SavingsGoal> createSavingsGoal({
    required String name,
    required double targetAmount,
    DateTime? deadline,
    double? autoDepositAmount,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/savings-goals'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'target_amount': targetAmount,
        if (deadline != null)
          'deadline': deadline.toIso8601String().split('T')[0],
        if (autoDepositAmount != null) 'auto_deposit_amount': autoDepositAmount,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 201) {
      return SavingsGoal.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to create savings goal');
    }
  }

  Future<List<SavingsGoal>> getSavingsGoals({
    bool includeCompleted = false,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/savings-goals').replace(
      queryParameters: {'include_completed': includeCompleted.toString()},
    );
    final response = await http.get(uri, headers: headers);

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => SavingsGoal.fromJson(json)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get savings goals');
    }
  }

  Future<SavingsGoal> getSavingsGoal(String goalId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/savings-goals/$goalId'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return SavingsGoal.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get savings goal');
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
    final headers = await _getHeaders();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (targetAmount != null) body['target_amount'] = targetAmount;
    if (deadline != null)
      body['deadline'] = deadline.toIso8601String().split('T')[0];
    if (autoDepositAmount != null)
      body['auto_deposit_amount'] = autoDepositAmount;
    if (isCompleted != null) body['is_completed'] = isCompleted;

    final response = await http.put(
      Uri.parse('$baseUrl/savings-goals/$goalId'),
      headers: headers,
      body: jsonEncode(body),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return SavingsGoal.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update savings goal');
    }
  }

  Future<void> deleteSavingsGoal(String goalId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/savings-goals/$goalId'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to delete savings goal');
    }
  }

  Future<SavingsGoal> depositToSavingsGoal({
    required String goalId,
    required double amount,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/savings-goals/$goalId/deposit'),
      headers: headers,
      body: jsonEncode({'amount': amount}),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return SavingsGoal.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to deposit to savings goal');
    }
  }

  Future<SavingsGoal> withdrawFromSavingsGoal({
    required String goalId,
    required double amount,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/savings-goals/$goalId/withdraw'),
      headers: headers,
      body: jsonEncode({'amount': amount}),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return SavingsGoal.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
        error['detail'] ?? 'Failed to withdraw from savings goal',
      );
    }
  }

  // ==================== Analytics Methods ====================

  Future<SpendingAnalytics> getSpendingAnalytics({
    String period = 'month',
    int? year,
    int? month,
    String? category,
  }) async {
    final headers = await _getHeaders();
    final queryParams = <String, String>{'period': period};
    if (year != null) queryParams['year'] = year.toString();
    if (month != null) queryParams['month'] = month.toString();
    if (category != null) queryParams['category'] = category;

    final uri = Uri.parse(
      '$baseUrl/analytics/spending',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return SpendingAnalytics.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get spending analytics');
    }
  }

  Future<SpendingTrends> getSpendingTrends({String period = 'month'}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse(
      '$baseUrl/analytics/trends',
    ).replace(queryParameters: {'period': period});
    final response = await http.get(uri, headers: headers);

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return SpendingTrends.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get spending trends');
    }
  }

  // ==================== Notification Methods ====================

  Future<void> registerDevice({
    required String deviceToken,
    required String deviceType, // IOS, ANDROID, WEB
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/notifications/register');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'device_token': deviceToken,
        'device_type': deviceType,
      }),
    );

    await _handleResponse(response);
  }

  Future<List<Notification>> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    final headers = await _getHeaders();
    final queryParams = <String, String>{
      'unread_only': unreadOnly.toString(),
      'limit': limit.toString(),
    };
    final uri = Uri.parse(
      '$baseUrl/notifications',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Notification.fromJson(json)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get notifications');
    }
  }

  Future<int> getUnreadNotificationCount() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/notifications/unread-count');
    final response = await http.get(uri, headers: headers);

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['unread_count'] ?? 0;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
        error['detail'] ?? 'Failed to get unread notification count',
      );
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/notifications/$notificationId/read');
    final response = await http.put(uri, headers: headers);

    await _handleResponse(response);
  }

  Future<void> markAllNotificationsRead() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/notifications/read-all');
    final response = await http.put(uri, headers: headers);

    await _handleResponse(response);
  }

  Future<void> deleteNotification(String notificationId) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/notifications/$notificationId');
    final response = await http.delete(uri, headers: headers);

    await _handleResponse(response);
  }

  Future<NotificationSettings> getNotificationSettings() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/notifications/settings');
    final response = await http.get(uri, headers: headers);

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return NotificationSettings.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get notification settings');
    }
  }

  Future<NotificationSettings> updateNotificationSettings({
    bool? enableTransactionNotifications,
    bool? enablePromotionNotifications,
    bool? enableSecurityNotifications,
    bool? enableAlertNotifications,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/notifications/settings');
    final body = <String, dynamic>{};
    if (enableTransactionNotifications != null) {
      body['enable_transaction_notifications'] = enableTransactionNotifications;
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

    final response = await http.put(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return NotificationSettings.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
        error['detail'] ?? 'Failed to update notification settings',
      );
    }
  }

  // ==================== Alert Methods ====================

  Future<List<Alert>> getAlerts({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    final headers = await _getHeaders();
    final queryParams = <String, String>{
      'unread_only': unreadOnly.toString(),
      'limit': limit.toString(),
    };
    final uri = Uri.parse(
      '$baseUrl/alerts',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Alert.fromJson(json)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get alerts');
    }
  }

  Future<int> getUnreadAlertCount() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/alerts/unread-count');
    final response = await http.get(uri, headers: headers);

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['unread_count'] ?? 0;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get unread alert count');
    }
  }

  Future<void> markAlertRead(String alertId) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/alerts/$alertId/read');
    final response = await http.put(uri, headers: headers);

    await _handleResponse(response);
  }

  Future<void> markAllAlertsRead() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/alerts/read-all');
    final response = await http.put(uri, headers: headers);

    await _handleResponse(response);
  }

  Future<void> deleteAlert(String alertId) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/alerts/$alertId');
    final response = await http.delete(uri, headers: headers);

    await _handleResponse(response);
  }

  Future<AlertSettings> getAlertSettings() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/alerts/settings');
    final response = await http.get(uri, headers: headers);

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return AlertSettings.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get alert settings');
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
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/alerts/settings');
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

    final response = await http.put(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return AlertSettings.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update alert settings');
    }
  }

  // ==================== Device Methods ====================

  Future<List<UserDevice>> getDevices() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/devices'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => UserDevice.fromJson(json)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get devices');
    }
  }

  Future<UserDevice> createDevice({
    required String deviceName,
    required String deviceType,
    String? deviceToken,
    String? ipAddress,
    String? userAgent,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/devices'),
      headers: headers,
      body: jsonEncode({
        'device_name': deviceName,
        'device_type': deviceType,
        if (deviceToken != null) 'device_token': deviceToken,
        if (ipAddress != null) 'ip_address': ipAddress,
        if (userAgent != null) 'user_agent': userAgent,
      }),
    );

    await _handleResponse(response);

    if (response.statusCode == 201) {
      return UserDevice.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to create device');
    }
  }

  Future<UserDevice> renameDevice({
    required String deviceId,
    required String deviceName,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/devices/$deviceId/rename'),
      headers: headers,
      body: jsonEncode({'device_name': deviceName}),
    );

    await _handleResponse(response);

    if (response.statusCode == 200) {
      return UserDevice.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to rename device');
    }
  }

  Future<void> deleteDevice(String deviceId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/devices/$deviceId'),
      headers: headers,
    );

    await _handleResponse(response);

    if (response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to delete device');
    }
  }

  // ==================== Security History Methods ====================

  Future<List<SecurityHistory>> getSecurityHistory({
    int limit = 50,
    int offset = 0,
    String? actionType,
  }) async {
    final headers = await _getHeaders();
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (actionType != null) {
      queryParams['action_type'] = actionType;
    }

    final uri = Uri.parse(
      '$baseUrl/security/history',
    ).replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: headers);

    await _handleResponse(response);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => SecurityHistory.fromJson(json)).toList();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get security history');
    }
  }
}
