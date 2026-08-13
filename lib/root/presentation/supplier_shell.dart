import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/curved_icon_nav_bar.dart';

/// Bottom navigation shell shared by both supplier roles (fournisseur tiers
/// and fournisseur principal) — mirrors `ClientShell` exactly. The two
/// roles get their own `StatefulShellRoute` in `app_router.dart` (so their
/// URLs and back-stacks stay separate, under `/supplier-tiers` and
/// `/supplier-principal`), but both point at this same widget and the same
/// six destination screens: what differs between the roles is the content
/// those screens render (see `operatingSupplierIdProvider`), not the shell
/// or the navigation structure itself.
class SupplierShell extends ConsumerWidget {
  const SupplierShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: CurvedIconNavBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavBarDestination(
            icon: Icons.space_dashboard_outlined,
            selectedIcon: Icons.space_dashboard_rounded,
            label: 'Tableau de bord',
          ),
          NavBarDestination(
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2_rounded,
            label: 'Produits',
          ),
          NavBarDestination(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: 'Commandes',
          ),
          NavBarDestination(
            icon: Icons.chat_bubble_outline_rounded,
            selectedIcon: Icons.chat_bubble_rounded,
            label: 'Messages',
          ),
          NavBarDestination(
            icon: Icons.account_balance_wallet_outlined,
            selectedIcon: Icons.account_balance_wallet_rounded,
            label: 'Finances',
          ),
          NavBarDestination(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
