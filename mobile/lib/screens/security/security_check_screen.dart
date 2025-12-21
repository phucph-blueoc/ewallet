import 'package:flutter/material.dart';
import '../../services/security_service.dart';

class SecurityCheckScreen extends StatefulWidget {
  final Widget child;
  final bool showWarning;

  const SecurityCheckScreen({
    super.key,
    required this.child,
    this.showWarning = true,
  });

  @override
  State<SecurityCheckScreen> createState() => _SecurityCheckScreenState();
}

class _SecurityCheckScreenState extends State<SecurityCheckScreen> {
  final SecurityService _securityService = SecurityService();
  bool _isChecking = true;
  bool _isCompromised = false;
  Map<String, dynamic>? _securityStatus;

  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    final status = await _securityService.getSecurityStatus();
    
    setState(() {
      _isCompromised = status['isCompromised'] == true || status['hasDeveloperOptions'] == true;
      _securityStatus = status;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Đang kiểm tra bảo mật thiết bị...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_isCompromised && widget.showWarning) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  'Cảnh Báo Bảo Mật',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Thiết bị của bạn có vẻ đã bị xâm phạm:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_securityStatus?['isCompromised'] == true)
                        Text(
                          '• Thiết bị đã ${_securityStatus?['platform'] == 'android' ? 'root' : 'jailbreak'}',
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      if (_securityStatus?['hasDeveloperOptions'] == true)
                        Text(
                          '• Tùy chọn nhà phát triển đã được bật',
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sử dụng ứng dụng này trên thiết bị đã bị xâm phạm có thể làm lộ dữ liệu tài chính của bạn với các rủi ro bảo mật.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Quay Lại'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          // Continue anyway (user accepts risk)
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => widget.child),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Tiếp Tục Dù Vậy'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Device is secure, show app
    return widget.child;
  }
}

