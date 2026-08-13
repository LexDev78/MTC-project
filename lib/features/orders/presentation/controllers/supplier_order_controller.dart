import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

import '../../domain/entities/order_status.dart';
import '../providers/order_providers.dart';

/// Drives every order-management action for the operating supplier (see
/// `operatingSupplierIdProvider` — the same controller serves both a
/// fournisseur tiers and MTC staff).
class SupplierOrderController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> updateStatus({
    required String orderId,
    required String groupId,
    required OrderStatus status,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(orderRepositoryProvider)
          .updateGroupStatus(orderId: orderId, groupId: groupId, status: status),
    );
    return !state.hasError;
  }

  Future<bool> cancel({
    required String orderId,
    required String groupId,
    required String reason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(orderRepositoryProvider)
          .updateGroupStatus(
            orderId: orderId,
            groupId: groupId,
            status: OrderStatus.cancelled,
            cancellationReason: reason,
            cancelledBy: CancelledBy.supplier,
          ),
    );
    return !state.hasError;
  }

  /// Opens (or reuses) the conversation with the client who placed this
  /// order, reusing `ChatRepository.startOrGetConversation` exactly as the
  /// client side does — returns the conversation id to navigate to, `null`
  /// on failure.
  Future<String?> contactClient({required String clientId}) async {
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
            supplierId: supplierId,
            supplierName: supplierProfile.businessName,
          );
    });
    return state.hasError ? null : conversationId;
  }
}

final supplierOrderControllerProvider =
    AsyncNotifierProvider<SupplierOrderController, void>(
      SupplierOrderController.new,
    );
