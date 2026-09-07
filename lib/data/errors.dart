/// Application-level exception with a user-facing Vietnamese message.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Shortcut for "no network / could not reach server".
class OfflineException extends AppException {
  const OfflineException([String? message])
      : super(message ??
            'Mất kết nối mạng. Vui lòng kiểm tra sóng / Wi-Fi rồi thử lại.');
}

/// Turns an unknown runtime error into a friendly message.
String friendlyError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('connection') ||
      text.contains('timed out') ||
      text.contains('network') ||
      text.contains('handshake') ||
      text.contains('econn')) {
    return 'Mất kết nối mạng. Vui lòng kiểm tra sóng / Wi-Fi rồi thử lại.';
  }
  return 'Có lỗi xảy ra. Vui lòng thử lại. (${error.toString().replaceAll(RegExp(r'^[a-zA-Z]+Exception: '), '')})';
}
