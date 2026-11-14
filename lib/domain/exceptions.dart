/// Errors with a message that is safe to show to the user.
class AppException implements Exception {
  const AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class PermissionDeniedException extends AppException {
  const PermissionDeniedException([super.message = 'You do not have permission to do this.']);
}

class AuthFailedException extends AppException {
  const AuthFailedException([super.message = 'Incorrect email or password.']);
}

/// Turns any error into a short, friendly sentence.
String friendlyError(Object error) {
  if (error is AppException) return error.message;
  final text = error.toString();
  // Supabase/Postgres errors: keep the human part.
  final match = RegExp(r'message: ([^,}]+)').firstMatch(text);
  if (match != null) return match.group(1)!.trim();
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'No internet connection. Please check your network and try again.';
  }
  if (text.contains('Invalid login credentials')) return 'Incorrect email or password.';
  return text.replaceFirst('Exception: ', '');
}
