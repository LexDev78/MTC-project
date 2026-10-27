import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/home_catalog.dart';
import 'package:mtc_app/features/catalog/presentation/screens/on_sale_screen.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';
import 'package:mtc_app/root/presentation/client_home_screen.dart';
import 'package:mtc_app/root/presentation/client_shell.dart';

import '../support/shop_capture.dart';
import '../support/shop_fixtures.dart';

/// La vraie coquille client autour de [accueil], dans un routeur minimal.
Widget _coquille(Widget accueil) {
  final routeur = GoRouter(
    initialLocation: AppRoutes.clientHome,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ClientShell(navigationShell: shell),
        branches: [
          for (final chemin in [
            AppRoutes.clientHome,
            AppRoutes.clientCatalogue,
            AppRoutes.clientFavorites,
            AppRoutes.clientCart,
            AppRoutes.clientProfile,
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: chemin,
                  builder: (_, _) => chemin == AppRoutes.clientHome
                      ? accueil
                      : const SizedBox(),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  return Router.withConfig(config: routeur);
}

List<Override> _donnees() => [
  currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
  notificationsProvider('client-awa').overrideWith((ref) => Stream.value(const [])),
  cartItemCountProvider.overrideWithValue(2),
  homeProductsProvider.overrideWith((ref) => Stream.value(catalogueDemo())),
  recommendedFeedProvider.overrideWith(
    (ref) async => [
      for (final p in catalogueDemo().reversed) (product: p, reason: null),
    ],
  ),
];

void main() {
  capturerEcran('accueil', () => _coquille(const ClientHomeScreen()), overrides: _donnees);
  capturerEcran('promotions', () => const OnSaleScreen(), overrides: _donnees);
  capturerEcran(
    'accueil_page',
    () => _coquille(const ClientHomeScreen()),
    overrides: _donnees,
    hauteur: 2300,
  );
  capturerEcran(
    'promotions_page',
    () => const OnSaleScreen(),
    overrides: _donnees,
    hauteur: 1500,
  );
}
