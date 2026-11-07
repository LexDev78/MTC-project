import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_status.dart';
import '../../domain/entities/promotion.dart';
import '../providers/supplier_product_providers.dart';
import 'supplier_stock_adjust_sheet.dart';

/// "Produits" tab of `SupplierShell` — shared by both supplier roles via
/// `operatingSupplierIdProvider`. Shows every one of the operating
/// supplier's own listings, including drafts/paused/archived ones that a
/// client would never see (`ProductRepository.watchMyProducts`).
class SupplierProductListScreen extends ConsumerWidget {
  const SupplierProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierId = ref.watch(operatingSupplierIdProvider);

    if (supplierId == null) {
      return const Scaffold(body: MtcLoadingView());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Commentaires produits',
            onPressed: () => context.push(
              '${ref.read(supplierRoutePrefixProvider)}/products/comments',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: MtcTextField(
              label: 'Rechercher un produit',
              prefixIcon: Icons.search_rounded,
              onChanged: (value) => ref
                  .read(myProductsQueryProvider(supplierId).notifier)
                  .state = value,
            ),
          ),
          _StatusFilterRow(supplierId: supplierId),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: AsyncValueWidget(
              value: ref.watch(filteredMyProductsProvider(supplierId)),
              data: (products) {
                if (products.isEmpty) {
                  // « Aucun produit » et « aucun produit **qui corresponde** »
                  // ne se disent pas pareil. Inviter quelqu'un qui a cent
                  // articles à « ajouter son premier » parce qu'il a mal
                  // tapé un nom le laisse croire que son catalogue a
                  // disparu — constaté en parcours visuel sur une recherche
                  // qui ne ramenait rien.
                  final filtre =
                      ref.watch(myProductsQueryProvider(supplierId)).trim();
                  final statut =
                      ref.watch(myProductsStatusFilterProvider(supplierId));
                  if (filtre.isNotEmpty || statut != null) {
                    return MtcEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucun résultat',
                      subtitle: filtre.isEmpty
                          ? 'Aucun produit dans cet état. Choisissez « Tous » '
                                'pour revoir tout votre catalogue.'
                          : 'Aucun de vos produits ne correspond à '
                                '« $filtre ».',
                    );
                  }
                  return const MtcEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Aucun produit',
                    subtitle:
                        'Ajoutez votre premier article avec le bouton ci-dessous.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    96,
                  ),
                  itemCount: products.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _SupplierProductTile(product: products[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '${ref.read(supplierRoutePrefixProvider)}/products/form',
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
    );
  }
}

class _StatusFilterRow extends ConsumerWidget {
  const _StatusFilterRow({required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(myProductsStatusFilterProvider(supplierId));

    Widget chip(String label, ProductStatus? status) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: ChoiceChip(
          label: Text(label),
          selected: selected == status,
          onSelected: (_) => ref
              .read(myProductsStatusFilterProvider(supplierId).notifier)
              .state = status,
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          chip('Tous', null),
          for (final status in ProductStatus.values) chip(status.label, status),
        ],
      ),
    );
  }
}

class _SupplierProductTile extends ConsumerWidget {
  const _SupplierProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isLowStock =
        product.lowStockThreshold != null &&
        product.stockQuantity <= product.lowStockThreshold!;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          '${ref.read(supplierRoutePrefixProvider)}/products/form',
          extra: product,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: _SupplierProductThumbnail(product: product),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    product.hasVariants &&
                            product.maxPriceFcfa != null &&
                            product.maxPriceFcfa != product.priceFcfa
                        ? Text(
                            '${CurrencyFormatter.formatFcfa(product.priceFcfa)} – '
                            '${CurrencyFormatter.formatFcfa(product.maxPriceFcfa!)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : CurrencyText(
                            product.priceFcfa,
                            compareAtAmountFcfa: product.compareAtPriceFcfa,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: 4,
                      children: [
                        RoleBadge(
                          label: product.status.label,
                          color: _statusColor(product.status, scheme),
                          icon: Icons.circle,
                        ),
                        // Les remises en cours, s'il y en a : le fournisseur
                        // doit voir d'un coup d'œil lesquels de ses produits
                        // sont en promotion, sans ouvrir chaque fiche.
                        for (final promotion in product.promotions)
                          if (promotion.isRunningAt())
                            RoleBadge(
                              label: switch (promotion.kind) {
                                PromotionKind.percentage => '-${promotion.value}%',
                                PromotionKind.fixedAmount =>
                                  '-${promotion.value} F',
                              },
                              color: scheme.error,
                              icon: Icons.local_offer_outlined,
                            ),
                        RoleBadge(
                          label: [
                            if (isLowStock)
                              '${product.stockQuantity} en stock — faible'
                            else
                              '${product.stockQuantity} en stock',
                            if (product.hasVariants)
                              '(${product.variantCount} variantes)',
                          ].join(' '),
                          color: isLowStock ? scheme.error : scheme.onSurfaceVariant,
                          icon: isLowStock
                              ? Icons.warning_amber_rounded
                              : Icons.inventory_2_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Ajuster le stock',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SupplierStockAdjustSheet(product: product),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ProductStatus status, ColorScheme scheme) {
    return switch (status) {
      ProductStatus.draft => scheme.onSurfaceVariant,
      ProductStatus.active => scheme.primary,
      ProductStatus.paused => scheme.tertiary,
      ProductStatus.archived => scheme.error,
    };
  }
}

class _SupplierProductThumbnail extends StatelessWidget {
  const _SupplierProductThumbnail({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (product.imageUrls.isEmpty) {
      return Container(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        child: Icon(Icons.inventory_2_outlined, color: scheme.primary),
      );
    }

    return ResolvedImage(
      path: product.imageUrls.first,
      bucket: 'product-images',
      errorBuilder: (context, error, stackTrace) => Container(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        child: Icon(Icons.inventory_2_outlined, color: scheme.primary),
      ),
    );
  }
}
