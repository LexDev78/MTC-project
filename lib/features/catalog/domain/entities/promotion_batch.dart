import 'promotion.dart';

/// Une remise telle que le fournisseur l'a pensée : une décision, et les
/// produits qu'elle couvre.
///
/// La base, elle, stocke une ligne par produit (`product_promotions`,
/// `0062`) — c'est ce dont le calcul du prix a besoin. `batch_id` (`0090`)
/// retient lesquelles ont été créées ensemble, et
/// `fetch_my_promotion_batches` les recompose sous cette forme.
///
/// Une classe ordinaire et non un `freezed` : c'est un modèle de **lecture**,
/// assemblé à la main depuis une RPC qui rend un objet taillé pour un seul
/// écran, et jamais renvoyé au serveur. Il n'a besoin ni de `copyWith` ni de
/// sérialisation.
class PromotionBatch {
  const PromotionBatch({
    required this.key,
    required this.batchId,
    required this.kind,
    required this.value,
    required this.minQuantity,
    required this.isActive,
    required this.productCount,
    required this.productNames,
    required this.productIds,
    this.startsAt,
    this.endsAt,
    this.label,
  });

  /// De quoi désigner cette remise. C'est `batch_id` quand il y en a un,
  /// sinon l'identifiant de l'unique ligne — les remises posées depuis la
  /// feuille d'un produit n'ont pas de lot, et doivent quand même
  /// apparaître ici.
  final String key;

  /// `null` pour une remise posée produit par produit. L'arrêt et la
  /// suppression groupés n'ont alors rien à grouper.
  final String? batchId;

  final PromotionKind kind;
  final int value;
  final int minQuantity;
  final bool isActive;
  final int productCount;

  /// Les noms des produits couverts, triés. Sert à l'affichage seulement :
  /// « Pagne, Boubou, Sac » se lit, « 3 produits » ne dit pas lesquels.
  final List<String> productNames;

  /// Les identifiants correspondants, dans le même ordre. Sert à rouvrir la
  /// remise avec sa couverture déjà cochée.
  final List<String> productIds;

  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? label;

  bool get isGrouped => batchId != null;

  /// En cours à [now] : active, et dans sa fenêtre. Même règle que
  /// `Promotion.isRunningAt`, sur laquelle le prix se calcule.
  bool isRunningAt([DateTime? now]) {
    if (!isActive) return false;
    final moment = now ?? DateTime.now();
    if (startsAt != null && moment.isBefore(startsAt!)) return false;
    if (endsAt != null && !moment.isBefore(endsAt!)) return false;
    return true;
  }

  factory PromotionBatch.fromRow(Map<String, dynamic> row) {
    return PromotionBatch(
      key: row['key'] as String,
      batchId: row['batch_id'] as String?,
      kind: row['kind'] == 'fixed_amount'
          ? PromotionKind.fixedAmount
          : PromotionKind.percentage,
      value: (row['value'] as num).toInt(),
      minQuantity: (row['min_quantity'] as num?)?.toInt() ?? 1,
      isActive: row['is_active'] as bool? ?? true,
      productCount: (row['product_count'] as num?)?.toInt() ?? 0,
      productNames: [
        for (final name in (row['product_names'] as List? ?? const []))
          name as String,
      ],
      productIds: [
        for (final id in (row['product_ids'] as List? ?? const []))
          id as String,
      ],
      startsAt: row['starts_at'] == null
          ? null
          : DateTime.parse(row['starts_at'] as String).toLocal(),
      endsAt: row['ends_at'] == null
          ? null
          : DateTime.parse(row['ends_at'] as String).toLocal(),
      label: row['label'] as String?,
    );
  }
}
