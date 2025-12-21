import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/api_wrapper.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/tech_card.dart';

class SecurityHistoryScreen extends StatefulWidget {
  const SecurityHistoryScreen({super.key});

  @override
  State<SecurityHistoryScreen> createState() => _SecurityHistoryScreenState();
}

class _SecurityHistoryScreenState extends State<SecurityHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<SecurityHistory> _history = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedActionType;

  final List<String> _actionTypes = [
    'Tất cả',
    'LOGIN',
    'LOGOUT',
    'PASSWORD_CHANGE',
    'PIN_CHANGE',
    '2FA_ENABLE',
    '2FA_DISABLE',
    'SETTINGS_CHANGE',
  ];

  @override
  void initState() {
    super.initState();
    _selectedActionType = 'Tất cả';
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await handleApiCall(
        context,
        () => _apiService.getSecurityHistory(
          actionType: _selectedActionType == 'Tất cả' ? null : _selectedActionType,
        ),
      );
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Vừa xong';
        }
        return '${difference.inMinutes} phút trước';
      }
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays == 1) {
      return 'Hôm qua ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TechBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Lịch Sử Bảo Mật'),
        ),
        body: Column(
          children: [
            // Filter dropdown
            Container(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                value: _selectedActionType,
                decoration: InputDecoration(
                  labelText: 'Lọc theo loại',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _actionTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type == 'Tất cả' ? type : _getActionTypeDisplayName(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedActionType = value;
                  });
                  _loadHistory();
                },
              ),
            ),
            // History list
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadHistory,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadHistory,
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          )
                        : _history.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Chưa có lịch sử',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _history.length,
                                itemBuilder: (context, index) {
                                  final item = _history[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TechCard(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00D4FF).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              item.actionIcon,
                                              style: const TextStyle(fontSize: 24),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.actionTypeDisplayName,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                if (item.description != null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.description!,
                                                    style: TextStyle(
                                                      color: Colors.grey[400],
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 8),
                                                if (item.deviceName != null)
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.devices,
                                                        size: 14,
                                                        color: Colors.grey[500],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        item.deviceName!,
                                                        style: TextStyle(
                                                          color: Colors.grey[500],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                if (item.ipAddress != null) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.location_on,
                                                        size: 14,
                                                        color: Colors.grey[500],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        item.ipAddress!,
                                                        style: TextStyle(
                                                          color: Colors.grey[500],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatDate(item.createdAt),
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getActionTypeDisplayName(String actionType) {
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
}

