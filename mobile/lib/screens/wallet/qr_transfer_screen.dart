import 'package:flutter/material.dart';
import '../../services/qr_service.dart';
import '../../services/api_service.dart';
import '../../utils/jwt_helper.dart';

class QRTransferScreen extends StatefulWidget {
  const QRTransferScreen({super.key});

  @override
  State<QRTransferScreen> createState() => _QRTransferScreenState();
}

class _QRTransferScreenState extends State<QRTransferScreen> {
  String? _qrData;
  String? _userEmail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    try {
      final apiService = ApiService();
      final token = await apiService.getAccessToken();
      
      if (token != null) {
        // Decode JWT to get email
        final email = JwtHelper.getEmailFromToken(token);
        setState(() {
          _userEmail = email;
          _isLoading = false;
          // Auto-generate QR if email is available
          if (email != null && email.isNotEmpty) {
            _qrData = QRService.generateUserQRData(email: email);
          }
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _generateQR() {
    if (_userEmail == null || _userEmail!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lấy email của bạn. Vui lòng đăng nhập lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _qrData = QRService.generateUserQRData(email: _userEmail!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mã QR Của Tôi'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.qr_code_2, size: 60, color: Colors.teal),
                  const SizedBox(height: 16),
                  Text(
                    'Chia Sẻ Mã QR Của Bạn',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Để người khác quét mã này để gửi tiền cho bạn',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  if (_qrData == null) ...[
                    if (_userEmail == null || _userEmail!.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Không thể lấy email của bạn. Vui lòng đăng nhập lại.',
                                style: TextStyle(color: Colors.orange.shade900),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _generateQR,
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('Tạo Mã QR Của Tôi'),
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          QRService.generateQRCode(data: _qrData!, size: 250),
                          const SizedBox(height: 24),
                          if (_userEmail != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 16,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _userEmail!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            'Share this QR code with others',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'They can scan it to send you money',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _qrData = null;
                          _userEmail = null;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Generate New QR Code'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
