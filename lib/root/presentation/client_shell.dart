import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:mtc_app/features/favorites/presentation/providers/favorite_providers.dart';

import 'widgets/curved_icon_nav_bar.dart';

/// Bottom navigation shell for the Client role. Each destination is a
/// `StatefulShellBranch` (see `app_router.dart`), so switching tabs preserves
/// each branch's own navigation stack and scroll position. Icon-only, on a
/// brand-colored bar whose top edge dips into a notch under the selected
/// icon, which floats above the bar in a translucent gradient bubble.
class ClientShell extends ConsumerWidget {
  const ClientShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartItemCountProvider);
    final favoriteCount =
        ref.watch(favoriteProductIdsProvider).valueOrNull?.length ?? 0;
    final unreadCount = ref.watch(totalUnreadCountProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: CurvedIconNavBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          const NavBarDestination(
            icon: Icons.storefront_outlined,
            selectedIcon: Icons.storefront_rounded,
            label: 'Accueil',
          ),
          NavBarDestination(
            icon: Icons.favorite_border_rounded,
            selectedIcon: Icons.favorite_rounded,
            label: 'Favoris',
            badgeCount: favoriteCount,
          ),
          NavBarDestination(
            icon: Icons.shopping_cart_outlined,
            selectedIcon: Icons.shopping_cart_rounded,
            label: 'Panier',
            badgeCount: cartCount,
          ),
          const NavBarDestination(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: 'Commandes',
          ),
          NavBarDestination(
            icon: Icons.chat_bubble_outline_rounded,
            selectedIcon: Icons.chat_bubble_rounded,
            label: 'Messages',
            badgeCount: unreadCount,
          ),
          const NavBarDestination(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
