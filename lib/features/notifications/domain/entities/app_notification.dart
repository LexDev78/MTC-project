import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_notification.freezed.dart';
part 'app_notification.g.dart';

/// What triggered the notification — drives the icon shown in
/// `NotificationCenterScreen` and, for some types, which route tapping it
/// opens.
enum NotificationType {
  @JsonValue('new_order')
  newOrder,
  @JsonValue('new_message')
  newMessage,
  @JsonValue('low_stock')
  lowStock,
  @JsonValue('kyc_decision')
  kycDecision,
  @JsonValue('payout_decision')
  payoutDecision,
  @JsonValue('new_review')
  newReview,
  // Sent to the CLIENT when a supplier moves their order forward (accepted/
  // preparing/shipped/delivered) or cancels it — the reverse direction of
  // [newOrder], which goes to the supplier when the client places one.
  @JsonValue('order_status_update')
  orderStatusUpdate,
  // Sent both ways on `product_comments` — to the supplier when a client
  // posts a top-level comment, and back to the client when the supplier (or
  // another client) replies to their comment. Same shared-type shape as
  // [newMessage].
  @JsonValue('new_comment')
  newComment,
  // Sent to a supplier when staff approves or rejects a characteristic
  // type they proposed (`CharacteristicTypeReviewController`) — same
  // shared-type shape as [kycDecision].
  @JsonValue('characteristic_type_decision')
  characteristicTypeDecision;

  String get label => switch (this) {
    NotificationType.newOrder => 'Nouvelle commande',
    NotificationType.newMessage => 'Nouveau message',
    NotificationType.lowStock => 'Stock faible',
    NotificationType.kycDecision => 'Vérification',
    NotificationType.payoutDecision => 'Retrait',
    NotificationType.newReview => 'Nouvel avis',
    NotificationType.orderStatusUpdate => 'Commande',
    NotificationType.newComment => 'Nouveau commentaire',
    NotificationType.characteristicTypeDecision => 'Caractéristique produit',
  };
}

/// Scope reduced to an in-app list — no real push (see
/// SUPPLIER_INTERFACE_PROGRESS.md). [userId] is whichever account should
/// see it: a plain `AppUser.id` for a client (or a fournisseur tiers, whose
/// id and `supplierId` coincide — see `operatingSupplierIdProvider`), or
/// the shared MTC `supplierId` for staff, so every agent/admin sees the
/// same feed for the storefront they jointly operate.
@freezed
class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    required DateTime createdAt,
    required bool isRead,
    // What the notification is about — a conversationId for `newMessage`,
    // an orderId for `newOrder`, null for every other type (see
    // `NotificationCenterScreen`'s tap handler, the only reader of this).
    String? referenceId,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}

/// The reverse of `AppNotification.fromJson`'s `type` decoding, exposed on
/// its own: a push's FCM `data` payload only carries the db string form
/// (`type: 'new_message'`, ...), not a full notification row, so the tap
/// handler (`notification_tap_router.dart`) needs to turn that string back
/// into a [NotificationType] without constructing a whole [AppNotification]
/// just to borrow its JSON decoding. `null` for an unrecognized or missing
/// value rather than throwing — a stale client shouldn't crash on a payload
/// sent by a newer server.
NotificationType? notificationTypeFromDbValue(String? value) => switch (value) {
  'new_order' => NotificationType.newOrder,
  'new_message' => NotificationType.newMessage,
  'low_stock' => NotificationType.lowStock,
  'kyc_decision' => NotificationType.kycDecision,
  'payout_decision' => NotificationType.payoutDecision,
  'new_review' => NotificationType.newReview,
  'order_status_update' => NotificationType.orderStatusUpdate,
  'new_comment' => NotificationType.newComment,
  'characteristic_type_decision' => NotificationType.characteristicTypeDecision,
  _ => null,
};
