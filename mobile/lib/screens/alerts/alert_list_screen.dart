import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';

class AlertListScreen extends StatefulWidget {
  const AlertListScreen({super.key});

  @override
  State<AlertListScreen> createState() => _AlertListScreenState();
}

class _AlertListScreenState extends State<AlertListScreen> {
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertProvider>().loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cảnh Báo'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'mark_all_read') {
                context.read<AlertProvider>().markAllAsRead();
              } else if (value == 'settings') {
                Navigator.pushNamed(context, '/alerts/settings');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 20),
                    SizedBox(width: 8),
                    Text('Đánh dấu tất cả đã đọc'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Cài đặt'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<AlertProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.alerts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Lỗi: ${provider.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadAlerts(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final alerts = _showUnreadOnly
              ? provider.alerts.where((a) => !a.isRead).toList()
              : provider.alerts;

          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    _showUnreadOnly ? 'Không có cảnh báo chưa đọc' : 'Không có cảnh báo',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tổng: ${alerts.length} cảnh báo',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Chưa đọc'),
                      selected: _showUnreadOnly,
                      onSelected: (selected) {
                        setState(() {
                          _showUnreadOnly = selected;
                        });
                        provider.loadAlerts(unreadOnly: selected);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.loadAlerts(),
                  child: ListView.builder(
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      return _AlertItem(
                        alert: alert,
                        onTap: () {
                          if (!alert.isRead) {
                            provider.markAsRead(alert.id);
                          }
                        },
                        onDelete: () {
                          provider.deleteAlert(alert.id);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  final Alert alert;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AlertItem({
    required this.alert,
    required this.onTap,
    required this.onDelete,
  });

  Color _getSeverityColor() {
    switch (alert.severity) {
      case 'CRITICAL':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      case 'INFO':
      default:
        return const Color(0xFF00D4FF);
    }
  }

  IconData _getSeverityIcon() {
    switch (alert.severity) {
      case 'CRITICAL':
        return Icons.error;
      case 'WARNING':
        return Icons.warning;
      case 'INFO':
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final severityColor = _getSeverityColor();
    
    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: alert.isRead
            ? const Color(0xFF0A0E27)
            : const Color(0xFF1A1F3A),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: severityColor.withOpacity(0.2),
            child: Icon(_getSeverityIcon(), color: severityColor, size: 20),
          ),
          title: Text(
            alert.title,
            style: TextStyle(
              fontWeight: alert.isRead ? FontWeight.normal : FontWeight.bold,
              color: Colors.white,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                alert.message,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      alert.typeDisplayName,
                      style: TextStyle(
                        color: severityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(alert.createdAt),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: alert.isRead
              ? null
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: severityColor,
                    shape: BoxShape.circle,
                  ),
                ),
          onTap: onTap,
        ),
      ),
    );
  }
}

