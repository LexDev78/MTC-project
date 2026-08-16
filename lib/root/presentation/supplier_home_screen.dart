import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/repositories/product_repository.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/supplier_product_providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart'
    show ProductCategoryIcon, ProductImage;
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/supplier_onboarding/presentation/providers/supplier_kyc_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

/// "Tableau de bord" tab — the first branch of `SupplierShell`, shared by
/// both supplier roles. Content is role-specific (verification state for a
/// fournisseur tiers, the KYC review entry point for MTC staff); the other
/// five tabs stay identical between roles, see `SupplierShell`.
class SupplierHomeScreen extends ConsumerWidget {
  const SupplierHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final supplierId = ref.watch(operatingSupplierIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [if (supplierId != null) _NotificationBellButton(supplierId: supplierId)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: switch (user) {
          SupplierTiersUser() => _TiersHome(user: user, supplierId: supplierId),
          SupplierPrincipalUser() => _PrincipalHome(user: user, supplierId: supplierId),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _TiersHome extends StatelessWidget {
  const _TiersHome({required this.user, required this.supplierId});

  final SupplierTiersUser user;
  final String? supplierId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenue, ${user.businessName}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        _VerificationBadge(status: user.verificationStatus),
        const SizedBox(height: AppSpacing.sm),
        MtcRatingStars(rating: user.ratingAverage, ratingCount: user.ratingCount),
        // `unverified` never reaches this screen — the router forces it
        // straight to the onboarding wizard (see `route_guards.dart`). Only
        // `rejected` needs a way back in.
        if (user.verificationStatus == VerificationStatus.rejected) ...[
          const SizedBox(height: AppSpacing.md),
          MtcPrimaryButton(
            label: 'Corriger mon dossier',
            onPressed: () => context.push(AppRoutes.supplierOnboarding),
          ),
        ],
        if (supplierId != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _MyProductsSection(supplierId: supplierId!),
        ],
      ],
    );
  }
}

class _PrincipalHome extends ConsumerWidget {
  const _PrincipalHome({required this.user, required this.supplierId});

  final SupplierPrincipalUser user;
  final String? supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenue, ${user.displayName}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        RoleBadge(
          label: user.staffRole == StaffRole.admin ? 'Administrateur' : 'Agent',
          color: Theme.of(context).colorScheme.primary,
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        const _KycQueueButton(),
        // MTC staff also manage the shared "MTC Officiel" storefront's own
        // products, via the same `operatingSupplierIdProvider` resolution
        // as a fournisseur tiers (see that provider's doc comment) — same
        // section, same data source, just reached from the staff home.
        if (supplierId != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _MyProductsSection(supplierId: supplierId!),
        ],
      ],
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      VerificationStatus.verified => RoleBadge(
        label: 'Identité vérifiée',
        color: scheme.primary,
        icon: Icons.verified_rounded,
      ),
      VerificationStatus.pending => RoleBadge(
        label: 'Vérification en cours',
        color: scheme.tertiary,
        icon: Icons.hourglass_top_rounded,
      ),
      VerificationStatus.rejected => RoleBadge(
        label: 'Vérification refusée',
        color: scheme.error,
        icon: Icons.error_outline_rounded,
      ),
      VerificationStatus.unverified => RoleBadge(
        label: 'Non vérifié',
        color: scheme.onSurfaceVariant,
        icon: Icons.help_outline_rounded,
      ),
    };
  }
}

class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton({required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider(supplierId));

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push(
        '${ref.read(supplierRoutePrefixProvider)}/notifications',
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _KycQueueButton extends ConsumerWidget {
  const _KycQueueButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(kycReviewQueueProvider).valueOrNull ?? const [];
    return OutlinedButton.icon(
      onPressed: () => context.push(AppRoutes.supplierPrincipalKycQueue),
      icon: const Icon(Icons.fact_check_outlined),
      label: Text(
        queue.isEmpty
            ? 'Vérification des fournisseurs'
            : 'Vérification des fournisseurs (${queue.length})',
      ),
    );
  }
}

/// The operating supplier's own products as tappable stat cards — every
/// status/verification state included (`myProductsProvider`, unlike the
/// client-facing catalog), each showing views/likes/orders/stock and
/// pushing to the same product form screen `SupplierProductListScreen`'s
/// own tile does, for a quick glance without leaving the dashboard.
class _MyProductsSection extends ConsumerWidget {
  const _MyProductsSection({required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(myProductsProvider(supplierId));
    final statsAsync = ref.watch(productStatsProvider(supplierId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mes produits', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        productsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (products) {
            if (products.isEmpty) {
              return const MtcEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Aucun produit pour le moment',
              );
            }
            // `.valueOrNull` — stats are a `FutureProvider` fetched once
            // per dashboard visit, not blocking the cards themselves: they
            // just show 0 for an instant while that request is in flight,
            // rather than holding up the whole list/stock/price info.
            final stats = statsAsync.valueOrNull ?? const {};
            return Column(
              children: [
                for (final product in products)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ProductStatCard(
                      product: product,
                      stats: stats[product.id],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProductStatCard extends ConsumerWidget {
  const _ProductStatCard({required this.product, required this.stats});

  final Product product;
  final ProductStats? stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lowStock =
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: ProductImage(
                        imageUrl: product.imageUrls.isEmpty
                            ? null
                            : product.imageUrls.first,
                        icon: product.category.icon,
                      ),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        CurrencyText(
                          product.priceFcfa,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  RoleBadge(
                    label: '${product.viewCount} vues',
                    color: scheme.onSurfaceVariant,
                    icon: Icons.visibility_outlined,
                  ),
                  RoleBadge(
                    label: "${stats?.favoriteCount ?? 0} j'aime",
                    color: scheme.onSurfaceVariant,
                    icon: Icons.favorite_outline,
                  ),
                  RoleBadge(
                    label: '${stats?.orderCount ?? 0} commandes',
                    color: scheme.onSurfaceVariant,
                    icon: Icons.shopping_bag_outlined,
                  ),
                  RoleBadge(
                    label: '${product.stockQuantity} en stock',
                    color: lowStock ? scheme.error : scheme.onSurfaceVariant,
                    icon: Icons.inventory_2_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
