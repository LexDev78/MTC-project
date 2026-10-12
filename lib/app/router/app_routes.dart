/// Route path constants + typed builders for parameterized routes.
abstract final class AppRoutes {
  // Auth
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String loading = '/loading';
  static const String signUp = '/sign-up';
  static const String signUpRole = '/sign-up/role';
  static const String signUpSupplierLegalType = '/sign-up/supplier-type';
  static const String signUpDetails = '/sign-up/details';

  // Client shell
  static const String clientHome = '/client/home';
  static const String clientCatalogue = '/client/catalogue';
  static const String clientCatalogueCategory = '/client/catalogue/:category';
  static const String clientProductDetail = '/client/product/:productId';
  static const String clientSearch = '/client/search';
  static const String clientFavorites = '/client/favorites';
  static const String clientCart = '/client/cart';
  static const String clientCheckout = '/client/checkout';
  static const String clientOrders = '/client/orders';
  static const String clientOrderDetail = '/client/orders/:orderId';
  static const String clientOrderTrack = '/client/orders/:orderId/track';
  static const String clientOrderReview = '/client/orders/:orderId/review';
  static const String clientChat = '/client/chat';
  static const String clientChatThread = '/client/chat/:conversationId';
  static const String clientSupplierProfile = '/client/supplier/:supplierId';
  static const String clientProfile = '/client/profile';
  static const String clientProfileEdit = '/client/profile/edit';
  static const String clientNotifications = '/client/notifications';
  static const String clientSettings = '/client/settings';

  // Supplier tiers shell — 6 branches, mirrored 1:1 by the "principal" group
  // below (same `SupplierShell`/screens, see `app_router.dart`).
  static const String supplierTiersDashboard = '/supplier-tiers/dashboard';
  static const String supplierTiersProducts = '/supplier-tiers/products';
  static const String supplierTiersOrders = '/supplier-tiers/orders';
  static const String supplierTiersMessages = '/supplier-tiers/messages';
  static const String supplierTiersFinances = '/supplier-tiers/finances';
  static const String supplierTiersAccount = '/supplier-tiers/account';
  static const String supplierOnboarding = '/supplier-tiers/onboarding';
  static const String supplierTiersProductForm = '/supplier-tiers/products/form';
  static const String supplierTiersCommentInbox =
      '/supplier-tiers/products/comments';
  static const String supplierTiersReviewManagement =
      '/supplier-tiers/account/reviews';
  static const String supplierTiersNotifications =
      '/supplier-tiers/notifications';
  static const String supplierTiersOrderDetailPath =
      '/supplier-tiers/orders/:orderId';
  static const String supplierTiersChatThreadPath =
      '/supplier-tiers/messages/:conversationId';

  // Supplier principal (MTC staff) shell — same 6 branches.
  // ---- livreur -------------------------------------------------------------
  static const String courierHome = '/livreur/courses';
  static const String courierDelivery = '/livreur/courses/:id';
  static const String courierProfile = '/livreur/profil';

  static String courierDeliveryPath(String id) => '/livreur/courses/$id';

  static const String supplierPrincipalDashboard =
      '/supplier-principal/dashboard';
  static const String supplierPrincipalProducts =
      '/supplier-principal/products';
  static const String supplierPrincipalOrders = '/supplier-principal/orders';
  static const String supplierPrincipalMessages =
      '/supplier-principal/messages';
  static const String supplierPrincipalFinances =
      '/supplier-principal/finances';
  static const String supplierPrincipalAccount =
      '/supplier-principal/account';
  static const String supplierPrincipalProductForm =
      '/supplier-principal/products/form';
  static const String supplierPrincipalCommentInbox =
      '/supplier-principal/products/comments';
  static const String supplierPrincipalReviewManagement =
      '/supplier-principal/account/reviews';
  static const String supplierPrincipalNotifications =
      '/supplier-principal/notifications';
  static const String supplierPrincipalOrderDetailPath =
      '/supplier-principal/orders/:orderId';
  static const String supplierPrincipalChatThreadPath =
      '/supplier-principal/messages/:conversationId';

  // Staff-only KYC review (fournisseur principal)
  static const String supplierPrincipalKycQueue = '/supplier-principal/kyc';
  static const String supplierPrincipalKycDetailPath =
      '/supplier-principal/kyc/:kycId';

  // Staff-only, admin-only payout review (fournisseur principal) — no
  // tiers equivalent, same shape as the KYC queue above.
  static const String supplierPrincipalPayoutQueue =
      '/supplier-principal/finances/payouts';

  // Staff-only review of supplier-proposed characteristic types (fournisseur
  // principal) — no tiers equivalent, same shape as the KYC queue above.
  static const String supplierPrincipalCharacteristicTypeQueue =
      '/supplier-principal/products/characteristic-types';

  /// File des inscriptions livreurs, même forme que la file KYC ci-dessus.
  static const String supplierPrincipalCourierQueue =
      '/supplier-principal/couriers';

  static String catalogueCategory(String categoryName) =>
      '/client/catalogue/$categoryName';
  static String productDetail(String productId) => '/client/product/$productId';
  static String orderDetail(String orderId) => '/client/orders/$orderId';
  static String orderTrack(String orderId) => '/client/orders/$orderId/track';
  static String orderReview(String orderId) => '/client/orders/$orderId/review';
  static String chatThread(String conversationId) =>
      '/client/chat/$conversationId';
  static String supplierProfile(String supplierId) =>
      '/client/supplier/$supplierId';
  static String supplierPrincipalKycDetail(String kycId) =>
      '/supplier-principal/kyc/$kycId';
  static String supplierTiersOrderDetail(String orderId) =>
      '/supplier-tiers/orders/$orderId';
  static String supplierPrincipalOrderDetail(String orderId) =>
      '/supplier-principal/orders/$orderId';
  static String supplierTiersChatThread(String conversationId) =>
      '/supplier-tiers/messages/$conversationId';
  static String supplierPrincipalChatThread(String conversationId) =>
      '/supplier-principal/messages/$conversationId';
}
