import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart'
    show ProductImage;

/// One product line item, shown identically wherever one appears — the
/// checkout screen (still a `CartItem`, before the order exists), and both
/// the client's and the supplier's order detail screens (an `OrderItem`,
/// after placing) — photo (the ordered variant's own, falling back to the
/// base product's), product name, the exact variant ordered (from
/// [variantNameSnapshot], so it stays correct even if the product's
/// characteristics change later), quantity and line total.
///
/// Takes the snapshot fields directly rather than an `OrderItem`/`CartItem`
/// object: those two types carry the exact same relevant fields under the
/// same names (see `place_order`'s `p_groups[].items[]` shape, which is
/// built from a `CartItem` and becomes an `OrderItem` on arrival), so one
/// row serves both without this widget needing to know about either type.
/// [trailing] lets the supplier screen append its "contact about this item"
/// button without duplicating this layout.
class OrderItemRow extends ConsumerWidget {
  const OrderItemRow({
    super.key,
    required this.productId,
    required this.productNameSnapshot,
    required this.unitPriceFcfaSnapshot,
    required this.quantity,
    this.variantId,
    this.variantNameSnapshot,
    this.trailing,
  });

  final String productId;
  final String productNameSnapshot;
  final int unitPriceFcfaSnapshot;
  final int quantity;
  final String? variantId;
  final String? variantNameSnapshot;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final product = ref.watch(productDetailProvider(productId)).valueOrNull;
    final variant = product?.variants.firstWhereOrNull((v) => v.id == variantId);
    final imageUrl = variant?.imageUrls.firstOrNull ?? product?.imageUrls.firstOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: SizedBox(
              width: 44,
              height: 44,
              child: ProductImage(
                imageUrl: imageUrl,
                icon: Icons.inventory_2_outlined,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$quantity × $productNameSnapshot',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (variantNameSnapshot != null)
                  Text(
                    variantNameSnapshot!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          CurrencyText(
            unitPriceFcfaSnapshot * quantity,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
