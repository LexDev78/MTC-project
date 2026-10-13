import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/auth/presentation/screens/loading_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/login_screen.dart';
import 'package:mtc_app/features/delivery/presentation/screens/courier_delivery_screen.dart';
import 'package:mtc_app/features/delivery/presentation/screens/courier_review_queue_screen.dart';
import 'package:mtc_app/features/delivery/presentation/screens/courier_history_screen.dart';
import 'package:mtc_app/features/delivery/presentation/screens/courier_home_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/sign_up_details_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/supplier_legal_type_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/welcome_screen.dart';
import 'package:mtc_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:mtc_app/features/catalog/presentation/screens/catalogue_screen.dart';
import 'package:mtc_app/features/catalog/presentation/screens/category_products_screen.dart';
import 'package:mtc_app/features/catalog/presentation/screens/characteristic_type_review_queue_screen.dart';
import 'package:mtc_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:mtc_app/features/catalog/presentation/screens/search_screen.dart';
import 'package:mtc_app/features/catalog/presentation/screens/supplier_product_form_screen.dart';
import 'package:mtc_app/features/catalog/presentation/screens/supplier_product_list_screen.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/chat/presentation/screens/chat_thread_screen.dart';
import 'package:mtc_app/features/comments/presentation/screens/supplier_comment_inbox_screen.dart';
import 'package:mtc_app/features/promo_codes/presentation/screens/supplier_promo_codes_screen.dart';
import 'package:mtc_app/features/ratings/presentation/screens/supplier_review_management_screen.dart';
import 'package:mtc_app/features/supplier_finance/presentation/screens/payout_review_queue_screen.dart';
import 'package:mtc_app/features/chat/presentation/screens/conversation_list_screen.dart';
import 'package:mtc_app/features/chat/presentation/screens/supplier_conversation_list_screen.dart';
import 'package:mtc_app/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:mtc_app/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/checkout_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/order_list_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/supplier_order_detail_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/supplier_order_list_screen.dart';
import 'package:mtc_app/features/profile/presentation/screens/client_profile_screen.dart';
import 'package:mtc_app/features/profile/presentation/screens/manage_addresses_screen.dart';
import 'package:mtc_app/features/profile/presentation/screens/settings_screen.dart';
import 'package:mtc_app/features/ratings/presentation/screens/submit_review_screen.dart';
import 'package:mtc_app/features/supplier_finance/presentation/screens/supplier_finance_screen.dart';
import 'package:mtc_app/features/supplier_onboarding/domain/entities/supplier_kyc.dart';
import 'package:mtc_app/features/supplier_onboarding/presentation/screens/kyc_review_detail_screen.dart';
import 'package:mtc_app/features/supplier_onboarding/presentation/screens/kyc_review_queue_screen.dart';
import 'package:mtc_app/features/supplier_onboarding/presentation/screens/supplier_kyc_wizard_screen.dart';
import 'package:mtc_app/features/suppliers/presentation/screens/supplier_account_screen.dart';
import 'package:mtc_app/features/suppliers/presentation/screens/supplier_profile_screen.dart';
import 'package:mtc_app/features/tracking/presentation/screens/live_tracking_screen.dart';
import 'package:mtc_app/root/presentation/client_home_screen.dart';
import 'package:mtc_app/root/presentation/client_shell.dart';
import 'package:mtc_app/root/presentation/supplier_home_screen.dart';
import 'package:mtc_app/root/presentation/supplier_shell.dart';

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
      // ---- livreur ---------------------------------------------------------
      // Des routes à plat, sans coquille à onglets : l'app livreur tourne
      // autour d'une liste, du détail d'une course, et d'un historique
      // qu'on ouvre de temps en temps. Une barre de navigation permanente
      // coûterait plus d'écran qu'elle n'en ferait gagner.
      GoRoute(
        path: AppRoutes.courierHome,
        pageBuilder: (context, state) =>
            _fluidPage(state, const CourierHomeScreen()),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (context, state) => _fluidPage(
              state,
              CourierDeliveryScreen(deliveryId: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.courierHistory,
        pageBuilder: (context, state) =>
            _fluidPage(state, const CourierHistoryScreen()),
      ),
      GoRoute(
        path: AppRoutes.signUpRole,
        pageBuilder: (context, state) =>
            _fluidPage(state, const RoleSelectionScreen()),
      ),
      GoRoute(
        path: AppRoutes.signUpSupplierLegalType,
        pageBuilder: (context, state) =>
            _fluidPage(state, const SupplierLegalTypeScreen()),
      ),
      GoRoute(
        path: AppRoutes.signUpDetails,
        pageBuilder: (context, state) => _fluidPage(
          state,
          SignUpDetailsScreen(args: state.extra! as SignUpDetailsArgs),
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
        path: AppRoutes.clientCatalogueCategory,
        pageBuilder: (context, state) => _fluidPage(
          state,
          CategoryProductsScreen(
            category: ProductCategory.values.byName(
              state.pathParameters['category']!,
            ),
          ),
        ),
      ),
      // "Commandes"/"Messages" used to be their own client-shell tabs;
      // they're reached from the Profil screen's menu now instead, so
      // they're plain pushed routes rather than `StatefulShellBranch`es.
      GoRoute(
        path: AppRoutes.clientOrders,
        pageBuilder: (context, state) =>
            _fluidPage(state, const OrderListScreen()),
      ),
      GoRoute(
        path: AppRoutes.clientChat,
        pageBuilder: (context, state) =>
            _fluidPage(state, const ConversationListScreen()),
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
        path: AppRoutes.clientNotifications,
        pageBuilder: (context, state) =>
            _fluidPage(state, const NotificationCenterScreen()),
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
            initialAttachment: state.extra as ChatProductAttachment?,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.supplierOnboarding,
        pageBuilder: (context, state) =>
            _fluidPage(state, const SupplierKycWizardScreen()),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalKycQueue,
        pageBuilder: (context, state) =>
            _fluidPage(state, const KycReviewQueueScreen()),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalCourierQueue,
        pageBuilder: (context, state) =>
            _fluidPage(state, const CourierReviewQueueScreen()),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalKycDetailPath,
        pageBuilder: (context, state) => _fluidPage(
          state,
          KycReviewDetailScreen(kyc: state.extra! as SupplierKyc),
        ),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalPayoutQueue,
        pageBuilder: (context, state) =>
            _fluidPage(state, const PayoutReviewQueueScreen()),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalCharacteristicTypeQueue,
        pageBuilder: (context, state) =>
            _fluidPage(state, const CharacteristicTypeReviewQueueScreen()),
      ),
      // Product create/edit — `extra` carries the `Product` being edited,
      // `null` for create mode. Pushed on top of whichever shell the
      // signed-in role is in, mirrored once per zone like the shells
      // themselves (see `supplierRoutePrefixProvider`).
      GoRoute(
        path: AppRoutes.supplierTiersProductForm,
        pageBuilder: (context, state) => _fluidPage(
          state,
          SupplierProductFormScreen(product: state.extra as Product?),
        ),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalProductForm,
        pageBuilder: (context, state) => _fluidPage(
          state,
          SupplierProductFormScreen(product: state.extra as Product?),
        ),
      ),
      // Cross-product comment inbox, reached from an AppBar action on the
      // "Produits" tab rather than its own branch — mirrored once per zone
      // like the product form.
      GoRoute(
        path: AppRoutes.supplierTiersCommentInbox,
        pageBuilder: (context, state) =>
            _fluidPage(state, const SupplierCommentInboxScreen()),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalCommentInbox,
        pageBuilder: (context, state) =>
            _fluidPage(state, const SupplierCommentInboxScreen()),
      ),
      // Review management, reached from an AppBar action on the "Profil"
      // tab — mirrored once per zone like the comment inbox.
      GoRoute(
        path: AppRoutes.supplierTiersReviewManagement,
        pageBuilder: (context, state) =>
            _fluidPage(state, const SupplierReviewManagementScreen()),
      ),
      GoRoute(
        path: AppRoutes.supplierTiersPromoCodes,
        pageBuilder: (context, state) =>
            _fluidPage(state, const SupplierPromoCodesScreen()),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalPromoCodes,
        pageBuilder: (context, state) =>
            _fluidPage(state, const SupplierPromoCodesScreen()),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalReviewManagement,
        pageBuilder: (context, state) =>
            _fluidPage(state, const SupplierReviewManagementScreen()),
      ),
      // Notification center, reached from a bell icon on the "Tableau de
      // bord" tab — mirrored once per zone like the review management above.
      GoRoute(
        path: AppRoutes.supplierTiersNotifications,
        pageBuilder: (context, state) =>
            _fluidPage(state, const NotificationCenterScreen()),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalNotifications,
        pageBuilder: (context, state) =>
            _fluidPage(state, const NotificationCenterScreen()),
      ),
      // Order detail, scoped to the operating supplier's own group — see
      // `SupplierOrderView`. Mirrored once per zone like the product form.
      GoRoute(
        path: AppRoutes.supplierTiersOrderDetailPath,
        pageBuilder: (context, state) => _fluidPage(
          state,
          SupplierOrderDetailScreen(
            orderId: state.pathParameters['orderId']!,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalOrderDetailPath,
        pageBuilder: (context, state) => _fluidPage(
          state,
          SupplierOrderDetailScreen(
            orderId: state.pathParameters['orderId']!,
          ),
        ),
      ),
      // Chat thread — reuses `ChatThreadScreen` as-is (already agnostic of
      // which side is viewing, see the messaging lot).
      GoRoute(
        path: AppRoutes.supplierTiersChatThreadPath,
        pageBuilder: (context, state) => _fluidPage(
          state,
          ChatThreadScreen(
            conversationId: state.pathParameters['conversationId']!,
            initialAttachment: state.extra as ChatProductAttachment?,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.supplierPrincipalChatThreadPath,
        pageBuilder: (context, state) => _fluidPage(
          state,
          ChatThreadScreen(
            conversationId: state.pathParameters['conversationId']!,
            initialAttachment: state.extra as ChatProductAttachment?,
          ),
        ),
      ),
      // Fournisseur tiers shell — 6 branches sharing `SupplierShell` and its
      // screens with the "principal" shell just below: what differs is only
      // the URL prefix and the account operating each screen (see
      // `operatingSupplierIdProvider`), not the widgets themselves.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            SupplierShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplierTiersDashboard,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const SupplierHomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplierTiersProducts,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const SupplierProductListScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplierTiersOrders,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const SupplierOrderListScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplierTiersMessages,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const SupplierConversationListScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplierTiersFinances,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const SupplierFinanceScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplierTiersAccount,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const SupplierAccountScreen()),
              ),
            ],
          ),
        ],
      ),
      // Fournisseur principal (MTC staff) shell — identical shape, separate
      // URL prefix (kept apart by `route_guards.dart`'s zone check).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            SupplierShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplierPrincipalDashboard,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const SupplierHomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplierPrincipalProducts,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const SupplierProductListScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplierPrincipalOrders,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const SupplierOrderListScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplierPrincipalMessages,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const SupplierConversationListScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplierPrincipalFinances,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const SupplierFinanceScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supplierPrincipalAccount,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const SupplierAccountScreen()),
              ),
            ],
          ),
        ],
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
                path: AppRoutes.clientCatalogue,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const CatalogueScreen()),
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
                path: AppRoutes.clientFavorites,
                pageBuilder: (context, state) =>
                    _fluidPage(state, const FavoritesScreen()),
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
