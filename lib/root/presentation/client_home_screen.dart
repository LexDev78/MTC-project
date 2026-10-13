import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/animated_count_badge.dart';
import 'package:mtc_app/core/widgets/screen_idle_detector.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/screens/catalog_tab_screen.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart'
    show ProductCategoryIcon;
import 'package:mtc_app/features/catalog/presentation/widgets/product_filter_sheet.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';
import 'package:mtc_app/features/recommendations/presentation/widgets/recommended_feed.dart';

import 'widgets/promo_hero_banner.dart';

/// Hosts the two catalog tabs — "Fournisseur principal" (shown first; the
/// aggregated MTC catalog, includes third-party products too) and
/// "Fournisseurs tiers" (third-party products only) — each with its own
/// scroll/filter state so browsing one never leaks into the other.
class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      // The category button reflects whichever tab is active, so it needs
      // to rebuild on every swipe/tap, not just when a category is picked.
      ..addListener(() => setState(() {}));
    // Accueil is the client shell's landing branch and stays mounted (via
    // the `IndexedStack`) for the whole logged-in session, so the header
    // bell's badge — `notificationsProvider`, not autoDispose, no Realtime
    // on that table — would otherwise only ever reflect whatever was true
    // the very first time this screen built. One fresh fetch per app open
    // keeps that badge honest without needing a live subscription; see
    // `NotificationCenterScreen`'s `initState` for the same fix on the
    // actual notification list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(currentUserProvider).valueOrNull?.id;
      if (userId != null) ref.invalidate(notificationsProvider(userId));
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// The category menu is a home-level shortcut, not tab-scoped UI, but the
  /// filter it drives lives per-[SupplierType] — so a pick applies to
  /// whichever catalog tab is currently in view. "Fournisseur principal" is
  /// the first tab, so it maps to index 0.
  SupplierType get _activeSupplierType =>
      _tabController.index == 0 ? SupplierType.principal : SupplierType.tiers;

  void _toggleCategory(ProductCategory category) {
    final provider = catalogCategoryProvider(_activeSupplierType);
    final current = ref.read(provider);
    final next = current == category ? null : category;
    ref.read(provider.notifier).state = next;
    // Choisir une catégorie est un signal d'intérêt ; la désélectionner, non.
    if (next != null) {
      unawaited(
        ref.read(recommendationRepositoryProvider).logCategoryOpen(next),
      );
    }
  }

  void _clearCategory() {
    ref.read(catalogCategoryProvider(_activeSupplierType).notifier).state =
        null;
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartItemCountProvider);
    final currentUserId = ref.watch(
      currentUserProvider.select((u) => u.valueOrNull?.id),
    );
    final unreadNotificationCount = currentUserId == null
        ? 0
        : ref.watch(unreadNotificationCountProvider(currentUserId));
    final selectedCategory = ref.watch(
      catalogCategoryProvider(_activeSupplierType),
    );
    final hasActiveFilter = ref.watch(
      catalogHasActiveFilterProvider(_activeSupplierType),
    );

    return ScreenIdleDetector(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: AppSpacing.md,
          title: _HomeHeader(
            onSearchTap: () => context.push(AppRoutes.clientSearch),
            onCartTap: () => context.go(AppRoutes.clientCart),
            onNotificationsTap: () =>
                context.push(AppRoutes.clientNotifications),
            cartCount: cartCount,
            notificationCount: unreadNotificationCount,
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Fournisseur principal'),
              Tab(text: 'Fournisseurs tiers'),
            ],
          ),
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            const SliverToBoxAdapter(child: PromoHeroBanner()),
            // Au-dessus des onglets et non dans chacun : les suggestions
            // mêlent les deux types de fournisseurs, et les répéter sous
            // chaque onglet les afficherait deux fois pour une seule liste.
            const SliverToBoxAdapter(child: RecommendedFeed()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CategoryMenuButton(
                      selected: selectedCategory,
                      onSelectCategory: _toggleCategory,
                      onClear: _clearCategory,
                    ),
                    _FilterIconButton(
                      active: hasActiveFilter,
                      onTap: () => showProductFilterSheet(
                        context,
                        supplierType: _activeSupplierType,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: const [
              CatalogTabScreen(supplierType: SupplierType.principal),
              CatalogTabScreen(supplierType: SupplierType.tiers),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.onSearchTap,
    required this.onCartTap,
    required this.onNotificationsTap,
    required this.cartCount,
    required this.notificationCount,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onCartTap;
  final VoidCallback onNotificationsTap;
  final int cartCount;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: scheme.primaryContainer,
          child: Icon(
            Icons.storefront_rounded,
            color: scheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _SearchBar(onTap: onSearchTap)),
        const SizedBox(width: AppSpacing.sm),
        // Bell sits immediately to the left of the cart — the two most
        // frequent "check something" actions grouped together, mirroring
        // the supplier dashboard's bell placement.
        _HeaderIconButton(
          icon: Icons.notifications_outlined,
          count: notificationCount,
          onTap: onNotificationsTap,
        ),
        const SizedBox(width: AppSpacing.sm),
        _HeaderIconButton(
          icon: Icons.shopping_cart_outlined,
          count: cartCount,
          onTap: onCartTap,
        ),
      ],
    );
  }
}

/// A circular icon button with a live count badge — used for both the cart
/// and notifications bell in [_HomeHeader], identical styling.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AnimatedCountBadge(
            count: count,
            child: Icon(icon, color: scheme.onSurface, size: 20),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Rechercher un produit...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The catalog filter/sort entry point — kept in the same row as the
/// category dropdown (rather than floating inside each tab's body) so the
/// two controls read as one aligned toolbar.
class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? scheme.primary : scheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 20,
              color: active ? scheme.onPrimary : scheme.onSurface,
            ),
            if (active)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.primary, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Collapses the category shortcuts into a single pill button + dropdown
/// menu (rather than a permanently-visible icon grid) so the home screen
/// stays compact regardless of how many categories exist.
class _CategoryMenuButton extends StatelessWidget {
  const _CategoryMenuButton({
    required this.selected,
    required this.onSelectCategory,
    required this.onClear,
  });

  final ProductCategory? selected;
  final void Function(ProductCategory category) onSelectCategory;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = selected != null;
    final foreground = active ? scheme.onPrimary : scheme.onSurface;

    return PopupMenuButton<ProductCategory?>(
      tooltip: 'Catégories',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      // PopupMenuButton treats a `null` popped value as "dismissed without
      // selecting" and never calls `onSelected` for it — so the "Toutes les
      // catégories" entry can't go through the value-based path below. Its
      // own `onTap` fires independently of that null-value quirk.
      onSelected: (category) {
        if (category != null) onSelectCategory(category);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: null,
          onTap: onClear,
          child: Text(
            'Toutes les catégories',
            style: TextStyle(
              fontWeight: selected == null ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        const PopupMenuDivider(),
        for (final category in ProductCategory.values)
          PopupMenuItem(
            value: category,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  category.icon,
                  size: 20,
                  color: category == selected
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  category.label,
                  style: TextStyle(
                    fontWeight: category == selected
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: category == selected ? scheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? scheme.primary : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected?.icon ?? Icons.category_rounded,
              size: 18,
              color: foreground,
            ),
            const SizedBox(width: 6),
            Text(
              selected?.label ?? 'Catégories',
              style: TextStyle(fontWeight: FontWeight.w600, color: foreground),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 18, color: foreground),
          ],
        ),
      ),
    );
  }
}
