import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import 'widgets/curved_icon_nav_bar.dart';

/// Bottom navigation shell shared by both supplier roles (fournisseur tiers
/// and fournisseur principal) — mirrors `ClientShell` exactly. The two
/// roles get their own `StatefulShellRoute` in `app_router.dart` (so their
/// URLs and back-stacks stay separate, under `/supplier-tiers` and
/// `/supplier-principal`), but both point at this same widget and the same
/// six destination screens: what differs between the roles is the content
/// those screens render (see `operatingSupplierIdProvider`), not the shell
/// or the navigation structure itself.
/// Les six onglets, et la permission que chacun demande.
///
/// L'ordre **doit** suivre celui des branches déclarées dans
/// `app_router.dart` : `goBranch` travaille sur l'indice de branche, pas
/// sur ce que l'écran affiche. Masquer un onglet sans traduire les indices
/// enverrait vers le mauvais écran — le genre de défaut qui ne se voit
/// qu'en cliquant.
const _onglets = [
  (
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
    label: 'Tableau de bord',
    permission: null,
  ),
  (
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    label: 'Produits',
    permission: 'products',
  ),
  (
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    label: 'Commandes',
    permission: 'orders',
  ),
  (
    icon: Icons.chat_bubble_outline_rounded,
    selectedIcon: Icons.chat_bubble_rounded,
    label: 'Messages',
    permission: 'messages',
  ),
  (
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    label: 'Finances',
    // L'argent ne se délègue jamais : réservé au propriétaire, quoi qu'il
    // décide d'accorder par ailleurs (`0093`).
    permission: '__owner__',
  ),
  (
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront_rounded,
    label: 'Profil',
    permission: null,
  ),
];

class SupplierShell extends ConsumerWidget {
  const SupplierShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estProprietaire = ref.watch(isSupplierOwnerProvider);

    // Les indices de branche que ce compte a le droit d'ouvrir, dans
    // l'ordre. Un collaborateur sans le droit « produits » ne doit pas
    // seulement échouer à modifier un article : il ne doit pas voir
    // l'onglet, ni pouvoir y arriver.
    final visibles = <int>[
      for (var i = 0; i < _onglets.length; i++)
        if (_onglets[i].permission == null ||
            (_onglets[i].permission == '__owner__'
                ? estProprietaire
                : ref.watch(supplierCanProvider(_onglets[i].permission!))))
          i,
    ];

    // La branche courante peut ne plus être visible — un accès retiré
    // pendant que l'écran est ouvert, par exemple. On montre alors le
    // premier onglet permis plutôt qu'un indice hors liste.
    final positionCourante = visibles.indexOf(navigationShell.currentIndex);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: CurvedIconNavBar(
        selectedIndex: positionCourante < 0 ? 0 : positionCourante,
        onDestinationSelected: (position) => navigationShell.goBranch(
          visibles[position],
          initialLocation: visibles[position] == navigationShell.currentIndex,
        ),
        destinations: [
          for (final indice in visibles)
            NavBarDestination(
              icon: _onglets[indice].icon,
              selectedIcon: _onglets[indice].selectedIcon,
              label: _onglets[indice].label,
            ),
        ],
      ),
    );
  }
}
