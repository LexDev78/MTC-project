/// Quelqu'un qui travaille dans la boutique d'un autre
/// (`supplier_collaborators`, `0093`).
///
/// Une classe ordinaire et non un `freezed` : modèle de lecture, assemblé à
/// la main depuis `fetch_my_collaborators`, jamais renvoyé au serveur tel
/// quel — les écritures passent par des RPC qui prennent les champs un par
/// un.
class SupplierCollaborator {
  const SupplierCollaborator({
    required this.userId,
    required this.displayName,
    required this.usernameOrPhone,
    required this.permissions,
    required this.mustChangePassword,
    required this.createdAt,
    this.phoneNumber,
    this.deactivatedAt,
  });

  final String userId;
  final String displayName;

  /// Ce que le patron lui a remis pour se connecter.
  final String usernameOrPhone;
  final String? phoneNumber;

  final Set<String> permissions;

  /// Vrai tant que le code à usage unique dicté par le patron n'a pas été
  /// remplacé. Le dire sur la fiche n'est pas décoratif : tant que c'est
  /// vrai, quiconque a entendu ce code peut ouvrir ce compte.
  final bool mustChangePassword;

  final DateTime createdAt;

  /// Quand le patron lui a retiré l'accès (`0110`) ; `null` s'il l'a.
  ///
  /// Un collaborateur retiré reste dans la liste : le patron peut rétablir
  /// son accès d'un geste, au lieu de recréer un compte et de lui dicter un
  /// nouveau mot de passe.
  final DateTime? deactivatedAt;

  bool get isActive => deactivatedAt == null;

  factory SupplierCollaborator.fromRow(Map<String, dynamic> row) {
    return SupplierCollaborator(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String? ?? '',
      usernameOrPhone: row['username_or_phone'] as String? ?? '',
      phoneNumber: row['phone_number'] as String?,
      permissions: {
        for (final p in (row['permissions'] as List? ?? const []))
          p as String,
      },
      mustChangePassword: row['must_change_password'] as bool? ?? false,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      deactivatedAt: row['deactivated_at'] == null
          ? null
          : DateTime.parse(row['deactivated_at'] as String).toLocal(),
    );
  }
}

/// Les accès qu'un patron peut accorder, et ce qu'ils veulent dire.
///
/// Quatre gestes n'y figurent pas, et c'est délibéré : l'argent, le dossier
/// de vérification, la suppression du compte et la gestion de l'équipe
/// restent au propriétaire, quoi qu'il décide. Un employé ne vide pas la
/// caisse, et celui qu'on vient de faire entrer n'évince pas celui qui l'a
/// fait entrer.
enum CollaboratorPermission {
  products('products', 'Produits', 'Créer et modifier les articles, le stock'),
  orders('orders', 'Commandes', 'Voir et traiter les commandes reçues'),
  promotions(
    'promotions',
    'Remises et codes promo',
    'Poser des remises et créer des codes',
  ),
  storefront(
    'storefront',
    'Vitrine',
    'Nom, description, horaires, localisation',
  ),
  messages('messages', 'Messages', 'Répondre aux clients'),
  reviews('reviews', 'Avis', 'Répondre aux avis laissés sur la boutique');

  const CollaboratorPermission(this.code, this.label, this.description);

  /// Le même mot que la base (`permissions_connues`, `0093`).
  final String code;
  final String label;
  final String description;
}
