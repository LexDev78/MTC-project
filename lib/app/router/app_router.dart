import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/auth/presentation/screens/loading_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/login_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/sign_up_details_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/welcome_screen.dart';
import 'package:mtc_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:mtc_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:mtc_app/features/catalog/presentation/screens/search_screen.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/chat/presentation/screens/chat_thread_screen.dart';
import 'package:mtc_app/features/chat/presentation/screens/conversation_list_screen.dart';
import 'package:mtc_app/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/checkout_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/order_list_screen.dart';
import 'package:mtc_app/features/profile/presentation/screens/client_profile_screen.dart';
import 'package:mtc_app/features/profile/presentation/screens/manage_addresses_screen.dart';
import 'package:mtc_app/features/profile/presentation/screens/settings_screen.dart';
import 'package:mtc_app/features/ratings/presentation/screens/submit_review_screen.dart';
import 'package:mtc_app/features/supplier_placeholder/presentation/screens/supplier_principal_dashboard_screen.dart';
import 'package:mtc_app/features/supplier_placeholder/presentation/screens/supplier_tiers_dashboard_screen.dart';
import 'package:mtc_app/features/suppliers/presentation/screens/supplier_profile_screen.dart';
import 'package:mtc_app/features/tracking/presentation/screens/live_tracking_screen.dart';
import 'package:mtc_app/root/presentation/client_home_screen.dart';
import 'package:mtc_app/root/presentation/client_shell.dart';

import 'app_routes.dart';
import 'route_guards.dart';

/// Wraps [child] in a fade + subtle horizontal slide, used as every route's
/// `pageBuilder` so navigating anywhere in the app feels like one continuous,
/// fluid motion rather than the platform's default abrupt page swap.
CustomTransitionPage<void> _fluidPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Zoom-in variant of [_fluidPage] used for the product detail route: the
/// page scales up from slightly smaller than full size while fading in, so
/// opening a product photo reads as "zooming into" it rather than the
/// generic side-slide used elsewhere. Deliberately not a shared-element
/// (Hero) zoom from the tapped card: the catalog grid and the product
/// detail route can sit in different go_router navigators (the grid lives
/// inside the client shell's nested tab navigator, the detail route is
/// pushed on the root navigator), so cross-navigator Hero flights don't
/// animate — and a product can legitimately appear twice at once in the
/// same navigator (e.g. its own "Voir aussi" list, or two stacked detail
/// pushes), which crashed Hero's tag-matching with a stack overflow. This
/// whole-page scale gives the same "zoom" feel without either problem.
CustomTransitionPage<void> _zoomPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  // `ref.listen` on the provider itself (not a second, independent
  // subscription to the repository's raw stream) so the refresh signal and
  // `ref.read(currentUserProvider)` inside `authRedirect` are always in
  // sync — two separate subscriptions to the same broadcast source can fire
  // in either order, letting the redirect read stale state.
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(currentUserProvider, (previous, next) => refreshNotifier.notify());
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) => authRedirect(ref, state),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _fluidPage(state, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (context, state) =>
            _fluidPage(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _fluidPage(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.loading,
        pageBuilder: (context, state) =>
            _fluidPage(state, const LoadingScreen()),
      ),
      GoRoute(
        path: AppRoutes.signUpRole,
        pageBuilder: (context, state) =>
            _fluidPage(state, const RoleSelectionScreen()),
      ),
      GoRoute(
        path: AppRoutes.signUpDetails,
        pageBuilder: (context, state) => _fluidPage(
          state,
          SignUpDetailsScreen(role: state.extra! as UserRole),
        ),
      ),
      GoRoute(
        path: AppRoutes.clientProductDetail,
        pageBuilder: (context, state) => _zoomPage(
          state,
          ProductDetailScreen(productId: state.pathParameters['productId']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.clientSearch,
        pageBuilder: (context, state) => _fluidPage(state, const SearchScreen()),
      ),
      GoRoute(
        path: AppRoutes.clientSupplierProfile,
        pageBuilder: (context, state) => _fluidPage(
          state,
          SupplierProfileScreen(
            supplierId: state.pathParameters['supplierId']!,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.clientProfileEdit,
        pageBuilder: (context, state) =>
            _fluidPage(state, const ManageAddressesScreen()),
      ),
      GoRoute(
        path: AppRoutes.clientSettings,
        pageBuilder: (context, state) =>
            _fluidPage(state, const SettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.clientCheckout,
        pageBuilder: (context, state) =>
            _fluidPage(state, const CheckoutScreen()),
      ),
      GoRoute(
        path: AppRoutes.clientOrderDetail,
        pageBuilder: (context, state) => _fluidPage(
          state,
          OrderDetailScreen(orderId: state.pathParameters['orderId']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.clientOrderTrack,
        pageBuilder: (context, state) => _fluidPage(
          state,
          LiveTrackingScreen(orderId: state.pathParameters['orderId']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.clientOrderReview,
        pageBuilder: (context, state) => _fluidPage(
          state,
          SubmitReviewScreen(orderId: state.pathParameters['orderId']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.clientChatThread,
        pageBuilder: (context, state) => _fluidPage(
          state,
          ChatThreadScreen(
            conversationId: state.pathParameters['conversationId']!,
            initialProduct: state.extra as Product?,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.supplierTiersDashboard,
        pageBuilder: (context, state) =>
            _fluidPage(state, const SupplierTiersDashboardScreen()),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalDashboard,
        pageBuilder: (context, state) =>
            _fluidPage(state, const SupplierPrincipalDashboardScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ClientShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.clientHome,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const ClientHomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.clientFavorites,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const FavoritesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.clientCart,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const CartScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.clientOrders,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const OrderListScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.clientChat,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const ConversationListScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.clientProfile,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const ClientProfileScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
