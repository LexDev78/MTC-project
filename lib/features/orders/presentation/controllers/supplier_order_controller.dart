import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_variant.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../providers/order_providers.dart';

/// Drives every order-management action for the operating supplier (see
/// `operatingSupplierIdProvider` — the same controller serves both a
/// fournisseur tiers and MTC staff).
class SupplierOrderController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Advances one supplier group to [status] and notifies the client — the
  /// screen passes [clientId]/[supplierName] through from the already-loaded
  /// `SupplierOrderView` rather than this controller re-fetching the order
  /// just to learn who to notify.
  Future<bool> updateStatus({
    required String orderId,
    required String groupId,
    required OrderStatus status,
    required String clientId,
    required String supplierName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(orderRepositoryProvider)
          .updateGroupStatus(orderId: orderId, groupId: groupId, status: status);
      await ref
          .read(notificationRepositoryProvider)
          .add(
            userId: clientId,
            type: NotificationType.orderStatusUpdate,
            title: 'Commande $supplierName',
            body: 'Votre commande est maintenant : ${status.label.toLowerCase()}.',
            referenceId: orderId,
          );
    });
    return !state.hasError;
  }

  Future<bool> cancel({
    required String orderId,
    required String groupId,
    required String reason,
    required String clientId,
    required String supplierName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(orderRepositoryProvider)
          .updateGroupStatus(
            orderId: orderId,
            groupId: groupId,
            status: OrderStatus.cancelled,
            cancellationReason: reason,
            cancelledBy: CancelledBy.supplier,
          );
      await ref
          .read(notificationRepositoryProvider)
          .add(
            userId: clientId,
            type: NotificationType.orderStatusUpdate,
            title: 'Commande $supplierName',
            body: 'Votre commande a été refusée : $reason',
            referenceId: orderId,
          );
    });
    return !state.hasError;
  }

  /// Opens (or reuses) the conversation with the client who placed this
  /// order, reusing `ChatRepository.startOrGetConversation` exactly as the
  /// client side does — returns the conversation id to navigate to, `null`
  /// on failure.
  Future<String?> contactClient({
    required String clientId,
    required String clientDisplayNameSnapshot,
  }) async {
    final supplierId = ref.read(operatingSupplierIdProvider);
    if (supplierId == null) return null;

    state = const AsyncLoading();
    String? conversationId;
    state = await AsyncValue.guard(() async {
      final supplierProfile = await ref
          .read(supplierRepositoryProvider)
          .getById(supplierId);
      conversationId = await ref
          .read(chatRepositoryProvider)
          .startOrGetConversation(
            clientId: clientId,
            clientDisplayNameSnapshot: clientDisplayNameSnapshot,
            supplierId: supplierId,
            supplierName: supplierProfile.businessName,
          );
    });
    return state.hasError ? null : conversationId;
  }

  /// Same as [contactClient], but also resolves the live [Product] for
  /// [item] so the screen can attach it to the conversation's next message
  /// (see `ChatThreadScreen.initialProduct`) — the client sees exactly
  /// which article the supplier is reaching out about, instead of having to
  /// guess from a generic "Contacter le client".
  ///
  /// [OrderItem] only carries a name/price snapshot, not an image, so the
  /// product is re-fetched by id for its photo. That fetch is best-effort:
  /// if the listing was since deleted, the conversation still opens, just
  /// without a product card attached — the supplier isn't blocked from
  /// reaching the client over something the client's own order already
  /// shows regardless.
  Future<({String? conversationId, Product? product, ProductVariant? variant})>
  contactClientAboutItem({
    required String clientId,
    required String clientDisplayNameSnapshot,
    required OrderItem item,
  }) async {
    final supplierId = ref.read(operatingSupplierIdProvider);
    if (supplierId == null) {
      return (conversationId: null, product: null, variant: null);
    }

    state = const AsyncLoading();
    String? conversationId;
    state = await AsyncValue.guard(() async {
      final supplierProfile = await ref
          .read(supplierRepositoryProvider)
          .getById(supplierId);
      conversationId = await ref
          .read(chatRepositoryProvider)
          .startOrGetConversation(
            clientId: clientId,
            clientDisplayNameSnapshot: clientDisplayNameSnapshot,
            supplierId: supplierId,
            supplierName: supplierProfile.businessName,
          );
    });
    if (state.hasError) return (conversationId: null, product: null, variant: null);

    Product? product;
    try {
      // `getById`'s nested select already embeds `variants`, so resolving
      // which one this item ordered (if any) needs no second fetch.
      product = await ref.read(productRepositoryProvider).getById(item.productId);
    } catch (_) {
      // See doc comment above — a missing product just skips the attachment.
    }
    final variant = item.variantId == null
        ? null
        : product?.variants.firstWhereOrNull((v) => v.id == item.variantId);
    return (conversationId: conversationId, product: product, variant: variant);
  }
}

final supplierOrderControllerProvider =
    AsyncNotifierProvider<SupplierOrderController, void>(
      SupplierOrderController.new,
    );
