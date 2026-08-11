/// Typed exceptions thrown by data-layer sources (in-memory today, Firebase
/// later). Controllers catch these and, where a distinct user-facing message
/// matters, map them to a [Failure] via `mapExceptionToFailure`.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException() : super('Identifiants incorrects');
}

final class UsernameAlreadyTakenException extends AppException {
  const UsernameAlreadyTakenException()
    : super("Ce nom d'utilisateur ou numéro est déjà utilisé");
}

final class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

final class ValidationException extends AppException {
  const ValidationException(super.message);
}

final class InsufficientStockException extends AppException {
  const InsufficientStockException(super.message);
}

final class NotAuthenticatedException extends AppException {
  const NotAuthenticatedException() : super('Vous devez être connecté');
}
