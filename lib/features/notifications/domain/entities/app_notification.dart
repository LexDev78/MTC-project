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
  orderStatusUpdate;

  String get label => switch (this) {
    NotificationType.newOrder => 'Nouvelle commande',
    NotificationType.newMessage => 'Nouveau message',
    NotificationType.lowStock => 'Stock faible',
    NotificationType.kycDecision => 'Vérification',
    NotificationType.payoutDecision => 'Retrait',
    NotificationType.newReview => 'Nouvel avis',
    NotificationType.orderStatusUpdate => 'Commande',
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
