/// Custom exception for authentication errors (401)
class UnauthorizedException implements Exception {
  final String message;
  
  UnauthorizedException(this.message);
  
  @override
  String toString() => message;
}

