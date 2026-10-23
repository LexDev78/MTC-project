/// Route path constants + typed builders for parameterized routes.
abstract final class AppRoutes {
  // Auth
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String login = '/login';

  /// Mot de passe oublié (`0127`) : l'identifiant, puis le code reçu par
  /// e-mail et le nouveau mot de passe. Ouvert sans être connecté.
  static const String forgotPassword = '/mot-de-passe-oublie';
  static const String forgotPasswordCode = '/mot-de-passe-oublie/code';
  static const String loading = '/loading';
  static const String signUp = '/sign-up';
  static const String signUpRole = '/sign-up/role';
  static const String signUpSupplierLegalType = '/sign-up/supplier-type';
  static const String signUpDetails = '/sign-up/details';

  /// Imposé à un collaborateur tant qu'il n'a pas remplacé le code à usage
  /// unique que son patron lui a dicté (`0098`).
  static const String changePassword = '/change-password';

  /// Le compte lui-même — mot de passe, adresse e-mail —, hors des aires de
  /// rôle : client, fournisseur, collaborateur et livreur y ont tous accès,
  /// chacun pour le sien. Le garde de routes ne redirige pas ces chemins,
  /// puisqu'ils n'appartiennent à aucun rôle en particulier.
  static const String accountPassword = '/compte/mot-de-passe';
  static const String accountEmail = '/compte/e-mail';

  /// Le code qui valide une nouvelle adresse e-mail (`0124`) ; `extra` porte
  /// la demande partie (`ContactEmailCodeRequest`).
  static const String accountEmailCode = '/compte/e-mail/code';

  // Client shell
  static const String clientHome = '/client/home';
  static const String clientCatalogue = '/client/catalogue';
  static const String clientCatalogueCategory = '/client/catalogue/:category';
  static const String clientProductDetail = '/client/product/:productId';
  static const String clientProductReviews =
      '/client/product/:productId/reviews';
  static const String clientSearch = '/client/search';

  /// Recherche par photo. Une route à part et non un mode de l'écran de
  /// recherche : elle a son propre quota, ses propres refus à expliquer, et
  /// un état qui ne se mélange pas à une recherche texte.
  static const String clientVisualSearch = '/client/search/photo';
  static const String clientSearchHistory = '/client/search/history';
  static const String clientFavorites = '/client/favorites';

  /// Les produits en promotion (« On sale » du kit FlutterShop).
  static const String clientOnSale = '/client/promotions';
  static const String clientCart = '/client/cart';
  static const String clientCheckout = '/client/checkout';
  static const String clientCheckoutPayment = '/client/checkout/payment';
  static const String clientOrders = '/client/orders';
  static const String clientOrderDetail = '/client/orders/:orderId';
  static const String clientOrderSuccess = '/client/orders/:orderId/merci';
  static const String clientOrderTrack = '/client/orders/:orderId/track';
  static const String clientOrderReview = '/client/orders/:orderId/review';

  /// Une rubrique de l'historique (« En attente », « Livrées »…), par le nom
  /// de son `OrderHistoryCategory`.
  static const String clientOrdersByCategory =
      '/client/orders/status/:category';
  static const String clientOrderCancel =
      '/client/orders/:orderId/cancel/:groupId';
  static const String clientChat = '/client/chat';
  static const String clientChatThread = '/client/chat/:conversationId';
  static const String clientSupplierProfile = '/client/supplier/:supplierId';

  /// « Boutiques du Mali » : les boutiques que le client peut visiter.
  static const String clientShops = '/client/shops';
  static const String clientProfile = '/client/profile';
  static const String clientProfileEdit = '/client/profile/edit';

  /// Les informations du compte (maquette « Profile » du kit).
  static const String clientProfileInfo = '/client/profile/info';

  /// Modifier le nom et l'e-mail (maquette « Edit profile » du kit).
  static const String clientProfileInfoEdit = '/client/profile/info/edit';
  static const String clientNotifications = '/client/notifications';

  /// Les réglages de notification (maquette « Notifications » du kit).
  static const String clientNotificationSettings =
      '/client/notifications/settings';
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
  static const String supplierTiersProductForm =
      '/supplier-tiers/products/form';
  static const String supplierTiersCommentInbox =
      '/supplier-tiers/products/comments';
  static const String supplierTiersReviewManagement =
      '/supplier-tiers/account/reviews';
  static const String supplierTiersPromoCodes =
      '/supplier-tiers/account/promo-codes';
  static const String supplierTiersLocation =
      '/supplier-tiers/account/location';
  static const String supplierTiersPromotions =
      '/supplier-tiers/account/promotions';
  static const String supplierTiersCollaborators =
      '/supplier-tiers/account/collaborators';
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

  /// Ses courses terminées et ses notes. Hors de `courierHome` et de ses
  /// sous-routes : `/livreur/courses/:id` capturerait `historique` comme un
  /// identifiant de course.
  static const String courierHistory = '/livreur/historique';

  /// Ses pièces d'identité et le dépôt de son dossier (`0105`). Hors de
  /// `courierHome` pour la même raison que l'historique.
  static const String courierDossier = '/livreur/dossier';

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
  static const String supplierPrincipalAccount = '/supplier-principal/account';
  static const String supplierPrincipalProductForm =
      '/supplier-principal/products/form';
  static const String supplierPrincipalCommentInbox =
      '/supplier-principal/products/comments';
  static const String supplierPrincipalReviewManagement =
      '/supplier-principal/account/reviews';
  static const String supplierPrincipalPromoCodes =
      '/supplier-principal/account/promo-codes';
  static const String supplierPrincipalLocation =
      '/supplier-principal/account/location';
  static const String supplierPrincipalPromotions =
      '/supplier-principal/account/promotions';
  static const String supplierPrincipalCollaborators =
      '/supplier-principal/account/collaborators';
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
  static String productReviews(String productId) =>
      '/client/product/$productId/reviews';
  static String orderDetail(String orderId) => '/client/orders/$orderId';
  static String orderSuccess(String orderId) => '/client/orders/$orderId/merci';
  static String orderTrack(String orderId) => '/client/orders/$orderId/track';

  /// [groupId] : la part de la commande à noter — une commande livrée par
  /// deux boutiques reçoit un avis par boutique.
  static String orderReview(String orderId, {String? groupId}) =>
      '/client/orders/$orderId/review'
      '${groupId == null ? '' : '?group=${Uri.encodeQueryComponent(groupId)}'}';
  static String ordersByCategory(String category) =>
      '/client/orders/status/$category';
  static String orderCancel(String orderId, String groupId) =>
      '/client/orders/$orderId/cancel/$groupId';
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
