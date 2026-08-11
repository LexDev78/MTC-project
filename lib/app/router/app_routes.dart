/// Route path constants + typed builders for parameterized routes.
abstract final class AppRoutes {
  // Auth
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String loading = '/loading';
  static const String signUp = '/sign-up';
  static const String signUpRole = '/sign-up/role';
  static const String signUpDetails = '/sign-up/details';

  // Client shell
  static const String clientHome = '/client/home';
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
  static const String clientSettings = '/client/settings';

  // Supplier placeholders (full dashboards land in a later iteration)
  static const String supplierTiersDashboard = '/supplier-tiers/dashboard';
  static const String supplierPrincipalDashboard =
      '/supplier-principal/dashboard';

  static String productDetail(String productId) => '/client/product/$productId';
  static String orderDetail(String orderId) => '/client/orders/$orderId';
  static String orderTrack(String orderId) => '/client/orders/$orderId/track';
  static String orderReview(String orderId) => '/client/orders/$orderId/review';
  static String chatThread(String conversationId) =>
      '/client/chat/$conversationId';
  static String supplierProfile(String supplierId) =>
      '/client/supplier/$supplierId';
}
