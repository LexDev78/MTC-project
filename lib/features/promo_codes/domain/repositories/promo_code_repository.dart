import '../entities/promo_code.dart';

/// Ce dont l'app a besoin des codes promo, sans rien savoir de Supabase.
abstract interface class PromoCodeRepository {
  /// Les codes du fournisseur connecté, avec leurs utilisations.
  Stream<List<PromoCode>> watchMine();

  /// Crée un code. Le fournisseur propriétaire est posé côté serveur depuis
  /// la session ; [productIds] vide signifie « tous mes produits ».
  Future<void> create({
    required String code,
    required int percent,
    String? label,
    DateTime? startsAt,
    DateTime? endsAt,
    int? maxUses,
    int maxUsesPerClient,
    int? minOrderFcfa,
    List<String> productIds,
  });

  /// Arrête ou reprend un code sans le supprimer : son historique
  /// d'utilisation reste lisible.
  /// Corrige un code existant, couverture comprise. Le code lui-même n'est
  /// pas modifiable — voir la couche données pour le pourquoi.
  Future<void> update({
    required String id,
    required int percent,
    String? label,
    DateTime? endsAt,
    int? maxUses,
    int maxUsesPerClient,
    int? minOrderFcfa,
    required List<String> productIds,
  });

  Future<void> setActive({required String id, required bool isActive});

  Future<void> delete(String id);

  /// Les codes utilisés sur une commande, indexés par groupe fournisseur —
  /// pour que le client relise ce qu'il a appliqué.
  Future<Map<String, ({String code, int discountFcfa})>> fetchForOrder(
    String orderId,
  );

  /// Ce qu'un code vaut sur ces lignes de panier, sans le consommer.
  /// Y a-t-il, pour ces produits, un code que ce client pourrait encore
  /// utiliser ? Sert à n'afficher le champ de saisie que quand il peut
  /// servir — jamais à montrer les codes eux-mêmes.
  Future<bool> existsForProducts(List<String> productIds);

  Future<PromoCodePreview> preview({
    required String code,
    required List<({String productId, String? variantId, int quantity})> lines,
  });
}
