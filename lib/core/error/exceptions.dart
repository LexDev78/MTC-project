/// Typed exceptions thrown by data-layer sources — controllers surface these
/// directly (typically via `AsyncValue.guard`, read back off `state.error`
/// in the UI), no separate `Failure` mapping layer.
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

final class AccountDeletedException extends AppException {
  const AccountDeletedException() : super('Ce compte a été supprimé.');
}
