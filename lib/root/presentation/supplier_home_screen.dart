import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';
import 'package:mtc_app/features/suppliers/domain/entities/supplier_dashboard_stats.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/repositories/product_repository.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/characteristic_type_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/supplier_product_providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_image.dart'
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
      body: RefreshIndicator(
        // Both product providers below are `autoDispose` but this tab
        // usually stays mounted (just offstage) while switching bottom-nav
        // tabs, so nothing naturally re-triggers them on every visit — a
        // pull-to-refresh gives a guaranteed way to pull fresh
        // views/j'aime/commandes counts logged from someone else's session
        // (a client favoriting/ordering/viewing) without waiting on a full
        // app restart.
        onRefresh: () async {
          if (supplierId == null) return;
          ref.invalidate(productStatsProvider(supplierId));
          ref.invalidate(myProductsProvider(supplierId));
          await ref.read(myProductsProvider(supplierId).future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (user) {
            SupplierTiersUser() => _TiersHome(user: user, supplierId: supplierId),
            SupplierPrincipalUser() => _PrincipalHome(user: user, supplierId: supplierId),
            _ => const SizedBox.shrink(),
          },
        ),
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
          const _StatsSection(),
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
        const SizedBox(height: AppSpacing.sm),
        const _CharacteristicTypeQueueButton(),
        const SizedBox(height: AppSpacing.sm),
        const _CourierQueueButton(),
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

class _CourierQueueButton extends ConsumerWidget {
  const _CourierQueueButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(pendingCouriersProvider).valueOrNull ?? const [];
    return OutlinedButton.icon(
      onPressed: () => context.push(AppRoutes.supplierPrincipalCourierQueue),
      icon: const Icon(Icons.delivery_dining_outlined),
      label: Text(
        queue.isEmpty
            ? 'Validation des livreurs'
            : 'Validation des livreurs (${queue.length})',
      ),
    );
  }
}

class _CharacteristicTypeQueueButton extends ConsumerWidget {
  const _CharacteristicTypeQueueButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(characteristicTypeQueueProvider).valueOrNull ?? const [];
    return OutlinedButton.icon(
      onPressed: () =>
          context.push(AppRoutes.supplierPrincipalCharacteristicTypeQueue),
      icon: const Icon(Icons.tune_rounded),
      label: Text(
        queue.isEmpty
            ? 'Types de caractéristiques'
            : 'Types de caractéristiques (${queue.length})',
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

/// Les chiffres de la boutique, en tête du tableau de bord.
///
/// L'écran disait bonjour et listait les produits. Pour savoir ce qui s'était
/// vendu, ce qui avait été gagné, ou si les fiches étaient seulement
/// regardées, il fallait ouvrir trois écrans et additionner de tête.
///
/// Tout vient d'une seule requête (`fetch_supplier_dashboard_stats`,
/// `0092`) : Postgres compte, le téléphone affiche. Rapatrier toutes les
/// commandes pour les additionner en Dart aurait fait payer l'ouverture de
/// l'écran d'accueil à chaque démarrage.
class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(supplierDashboardStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Mon activité',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            const MtcHelpHint(
              title: 'D\'où viennent ces chiffres',
              message:
                  'Les ventes et les gains ne comptent que les commandes '
                  '**livrées**. Une commande en cours n\'y figure pas encore : '
                  'elle peut encore être annulée.\n\n'
                  'Les frais de livraison ne vous reviennent pas quand c\'est '
                  'MTC qui livre — ils ne sont donc jamais comptés dans votre '
                  'chiffre d\'affaires.\n\n'
                  'Les vues comptent les ouvertures de vos fiches produit. '
                  'Beaucoup de vues et peu de ventes est un signal : le prix, '
                  'les photos ou la description méritent peut-être un regard.',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AsyncValueWidget(
          value: statsAsync,
          loading: (context) => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          data: (stats) => _StatsBody(stats: stats),
        ),
      ],
    );
  }
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody({required this.stats});

  final SupplierDashboardStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(supplierDashboardSummaryProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Deux par ligne : quatre chiffres côte à côte sur un écran de
        // téléphone deviennent illisibles, et ces quatre-là se lisent par
        // paires — ce qui s'est vendu, ce qui a été regardé.
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.shopping_bag_outlined,
                label: 'Ventes livrées',
                value: '${stats.ordersDelivered}',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                icon: Icons.local_shipping_outlined,
                label: 'En cours',
                value: '${stats.ordersInProgress}',
                highlight: stats.ordersInProgress > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.visibility_outlined,
                label: 'Vues de vos fiches',
                value: '${stats.viewsTotal}',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                icon: Icons.inventory_2_outlined,
                label: 'Produits actifs',
                value: '${stats.productsActive} / ${stats.productsTotal}',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Gains',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                _MoneyRow(
                  label: 'Chiffre d\'affaires livré',
                  amountFcfa: stats.grossFcfa,
                ),
                _MoneyRow(
                  label: 'Dont 30 derniers jours',
                  amountFcfa: stats.grossLast30DaysFcfa,
                  muted: true,
                ),
                _MoneyRow(
                  label: 'Dont 7 derniers jours',
                  amountFcfa: stats.grossLast7DaysFcfa,
                  muted: true,
                ),
                // L'argent ne se délègue jamais : un collaborateur voit
                // ce qui s'est vendu, pas ce qui reste à retirer. La
                // commission et le solde disponible sont l'affaire du
                // propriétaire, comme l'onglet Finances qu'il est seul à
                // voir.
                if (summary != null && ref.watch(isSupplierOwnerProvider)) ...[
                  const Divider(),
                  _MoneyRow(
                    label: 'Commission MTC',
                    amountFcfa: -summary.commissionFcfa,
                    muted: true,
                  ),
                  _MoneyRow(
                    label: 'Déjà versé',
                    amountFcfa: -summary.paidOutFcfa,
                    muted: true,
                  ),
                  const Divider(),
                  _MoneyRow(
                    label: 'Disponible au retrait',
                    amountFcfa: summary.availableFcfa,
                    strong: true,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (stats.bestSellers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Ce qui part le mieux',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final article in stats.bestSellers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      article.name,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${article.quantity} vendu'
                    '${article.quantity > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    CurrencyFormatter.formatFcfa(article.amountFcfa),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Met en avant ce qui demande une action — des commandes à traiter, par
  /// exemple. Un chiffre à zéro n'a aucune raison d'attirer l'œil.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: highlight ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: highlight ? scheme.onPrimaryContainer : scheme.primary,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: highlight ? scheme.onPrimaryContainer : null,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: highlight
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amountFcfa,
    this.muted = false,
    this.strong = false,
  });

  final String label;
  final int amountFcfa;
  final bool muted;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = strong
        ? theme.textTheme.titleMedium
        : muted
        ? theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )
        : theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            // Le signe est porté par le montant : une commission et un
            // versement se **retranchent** du disponible, et l'afficher en
            // positif ferait lire une addition.
            '${amountFcfa < 0 ? '-' : ''}'
            '${CurrencyFormatter.formatFcfa(amountFcfa.abs())}',
            style: style,
          ),
        ],
      ),
    );
  }
}
