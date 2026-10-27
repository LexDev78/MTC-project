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

/// Un collaborateur dont le patron a retiré l'accès (`0110`).
///
/// Sa ligne de rattachement existe encore — le patron peut la rétablir —,
/// mais elle ne lui ouvre plus rien. La connexion le lui dit, avec le nom de
/// la boutique, au lieu de laisser remonter l'erreur de la base qu'il
/// recevait auparavant (`PGRST116`, « JSON object requested, multiple (or
/// no) rows returned »).
final class CollaboratorAccessRevokedException extends AppException {
  CollaboratorAccessRevokedException(String? boutique)
    : super(
        boutique == null || boutique.isEmpty
            ? 'Votre accès à la boutique a été retiré par son responsable. '
                  'Contactez-le pour le rétablir.'
            : 'Votre accès à « $boutique » a été retiré par son responsable. '
                  'Contactez-le pour le rétablir.',
      );
}

/// Un compte fournisseur qui n'a ni boutique à son nom, ni rattachement à
/// celle d'un autre — un collaborateur retiré avant `0110`, quand le retrait
/// effaçait la ligne.
final class AccountNotAttachedException extends AppException {
  const AccountNotAttachedException()
    : super(
        'Ce compte n\'est rattaché à aucune boutique. Contactez le '
        'responsable qui vous l\'a créé.',
      );
}

