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
  Future<void> setActive({required String id, required bool isActive});

  Future<void> delete(String id);

  /// Ce qu'un code vaut sur ces lignes de panier, sans le consommer.
  Future<PromoCodePreview> preview({
    required String code,
    required List<({String productId, String? variantId, int quantity})> lines,
  });
}
