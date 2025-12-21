import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:crypto/crypto.dart';

class CertificatePinningService {
  // SHA-256 fingerprint of your server's certificate
  // You need to replace this with your actual certificate fingerprint
  // Get it using: openssl s_client -connect your-domain.com:443 -servername your-domain.com < /dev/null 2>/dev/null | openssl x509 -fingerprint -sha256 -noout -in /dev/stdin
  static const List<String> _allowedFingerprints = [
    // Example: 'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99',
    // Add your actual certificate fingerprints here
  ];

  /// Create Dio client with certificate pinning
  static Dio createPinnedDio() {
    final dio = Dio();
    
    // Only enable pinning if fingerprints are configured
    if (_allowedFingerprints.isNotEmpty) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) {
          return _verifyCertificate(cert);
        };
        return client;
      };
    }
    
    return dio;
  }

  /// Verify certificate fingerprint
  static bool _verifyCertificate(X509Certificate cert) {
    try {
      // Get certificate in DER format
      final der = cert.der;
      
      // Calculate SHA-256 fingerprint
      final bytes = sha256.convert(der).bytes;
      final fingerprint = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
      
      // Check if fingerprint matches any allowed fingerprint
      for (final allowedFingerprint in _allowedFingerprints) {
        if (fingerprint == allowedFingerprint.toUpperCase()) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get certificate fingerprint from URL (for setup)
  static Future<String?> getCertificateFingerprint(String host, int port) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://$host:$port'));
      final response = await request.close();
      
      final certificate = response.certificate;
      if (certificate != null) {
        final der = certificate.der;
        final bytes = sha256.convert(der).bytes;
        return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}

