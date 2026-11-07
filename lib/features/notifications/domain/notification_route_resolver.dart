import 'package:mtc_app/app/router/app_routes.dart';

import 'entities/app_notification.dart';

/// Where opening [type]/[referenceId] should land — the conversation for a
/// `newMessage`, the order for a `newOrder`/`orderStatusUpdate`, `null` for
/// every other type or when [referenceId] is missing (notifications created
/// before that field existed). Branches on client vs. supplier exactly like
/// `ConversationTile`. Pulled out of `_NotificationTile._routeFor` as a pure
/// function (no `Ref`/`BuildContext`) so the push tap handler — which runs
/// outside the widget tree, at cold start or from a background tap — can
/// reuse the exact same routing as the in-app notification list.
String? resolveNotificationRoute({
  required NotificationType type,
  required String? referenceId,
  required bool isClient,
  required String supplierRoutePrefix,
}) {
  if (referenceId == null) return null;
  return switch (type) {
    NotificationType.newMessage => isClient
        ? AppRoutes.chatThread(referenceId)
        : '$supplierRoutePrefix/messages/$referenceId',
    NotificationType.newOrder ||
    NotificationType.orderStatusUpdate => isClient
        ? AppRoutes.orderDetail(referenceId)
        : '$supplierRoutePrefix/orders/$referenceId',
    // [referenceId] is the product id either way; the client goes straight
    // to its (product-scoped) comment thread, the supplier to their inbox
    // of every product's comments — there's no per-product deep link into
    // that screen yet, so they land on the list and pick the thread that
    // was just replied to.
    NotificationType.newComment => isClient
        ? AppRoutes.productDetail(referenceId)
        : '$supplierRoutePrefix/products/comments',
    NotificationType.lowStock ||
    NotificationType.kycDecision ||
    NotificationType.payoutDecision ||
    NotificationType.newReview ||
    NotificationType.characteristicTypeDecision => null,
  };
}
