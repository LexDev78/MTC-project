import 'exceptions.dart';

/// Structured, user-facing error categories. Kept intentionally small —
/// most errors just need [AsyncError] to carry the exception's message via
/// `toString()`; a [Failure] is only worth minting when the UI must render
/// genuinely different copy or affordances per case (e.g. a "create account"
/// link on invalid credentials).
sealed class Failure {
  const Failure(this.message);

  final String message;
}

final class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure() : super('Identifiants incorrects');
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([
    super.message = "Une erreur inattendue s'est produite",
  ]);
}

Failure mapExceptionToFailure(Object error) {
  return switch (error) {
    InvalidCredentialsException() => const InvalidCredentialsFailure(),
    AppException(:final message) => ValidationFailure(message),
    _ => const UnknownFailure(),
  };
}
