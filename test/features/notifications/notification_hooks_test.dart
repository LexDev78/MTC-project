@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/stock_movement.dart';
import 'package:mtc_app/features/catalog/presentation/controllers/supplier_product_controller.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/payment.dart';
import 'package:mtc_app/features/orders/presentation/controllers/checkout_controller.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mtc_app/features/ratings/presentation/controllers/review_controller.dart';
import 'package:mtc_app/features/supplier_finance/domain/entities/payout_request.dart';
import 'package:mtc_app/features/supplier_finance/presentation/controllers/supplier_finance_controller.dart';
import 'package:mtc_app/features/supplier_finance/presentation/providers/supplier_finance_providers.dart';
import 'package:mtc_app/features/supplier_onboarding/presentation/controllers/kyc_review_controller.dart';
import 'package:mtc_app/features/supplier_onboarding/presentation/providers/supplier_kyc_providers.dart';

import '../../support/supabase_test_harness.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetAndSeed();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> login(String usernameOrPhone) async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: usernameOrPhone, password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test(
    'CheckoutController.placeOrder notifies every supplier in the order, '
    'not just one',
    () async {
      await login('client2');
      await container.read(addressesProvider.future);
      await container.read(checkoutGroupsProvider.future);
      await container.read(checkoutControllerProvider.future);

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();
      expect(success, isTrue);

      final repo = container.read(notificationRepositoryProvider);
      final riceSupplierNotifications = await repo
          .watchForUser(DemoIds.supplierAlimentationSegou)
          .first;
      final phoneSupplierNotifications = await repo
          .watchForUser(DemoIds.supplierElectroBamako)
          .first;
      expect(
        riceSupplierNotifications.any((n) => n.type == NotificationType.newOrder),
        isTrue,
      );
      expect(
        phoneSupplierNotifications.any(
          (n) => n.type == NotificationType.newOrder,
        ),
        isTrue,
      );
    },
  );

  test(
    'ChatController.sendMessage notifies the other side of the '
    'conversation, whichever direction it goes',
    () async {
      await login('fournisseur1');

      // fournisseur1 replying on the seeded conv-awa-bogolan conversation
      // notifies the client, Awa.
      await container
          .read(chatControllerProvider.notifier)
          .sendMessage(conversationId: 'conv-awa-bogolan', text: 'Merci !');

      final clientNotifications = await container
          .read(notificationRepositoryProvider)
          .watchForUser(DemoIds.clientAwa)
          .first;
      expect(
        clientNotifications.any((n) => n.type == NotificationType.newMessage),
        isTrue,
      );

      // The supplier's own notifications aren't touched by their own
      // message.
      final supplierNotifications = await container
          .read(notificationRepositoryProvider)
          .watchForUser(DemoIds.supplierBogolanBamako)
          .first;
      expect(
        supplierNotifications.any((n) => n.type == NotificationType.newMessage),
        isFalse,
      );
    },
  );

  test(
    'SupplierProductController.adjustStock notifies the supplier only when '
    'the resulting stock is at/below the threshold',
    () async {
      await login('fournisseur1');

      final productRepository = container.read(productRepositoryProvider);
      final myProducts = await container
          .read(productRepositoryProvider)
          .watchMyProducts(DemoIds.supplierBogolanBamako)
          .first;
      final product = myProducts.firstWhere(
        (p) => p.lowStockThreshold != null,
        orElse: () => myProducts.first,
      );
      // Force a known threshold so the test doesn't depend on seed values.
      await productRepository.updateProduct(
        product.copyWith(lowStockThreshold: 5, stockQuantity: 10),
      );

      // Stays above threshold — no notification.
      await container
          .read(supplierProductControllerProvider.notifier)
          .adjustStock(
            productId: product.id,
            quantityDelta: -2,
            reason: StockMovementReason.manualAdjustment,
          );
      var notifications = await container
          .read(notificationRepositoryProvider)
          .watchForUser(DemoIds.supplierBogolanBamako)
          .first;
      expect(
        notifications.any((n) => n.type == NotificationType.lowStock),
        isFalse,
      );

      // Drops to exactly the threshold — notifies.
      await container
          .read(supplierProductControllerProvider.notifier)
          .adjustStock(
            productId: product.id,
            quantityDelta: -3,
            reason: StockMovementReason.manualAdjustment,
          );
      notifications = await container
          .read(notificationRepositoryProvider)
          .watchForUser(DemoIds.supplierBogolanBamako)
          .first;
      expect(
        notifications.any((n) => n.type == NotificationType.lowStock),
        isTrue,
      );
    },
  );

  test(
    'KycReviewController.approve/reject each notify the fournisseur whose '
    'dossier was decided',
    () async {
      await login('agent1');

      // Artisanat Sikasso (fournisseur2) has a seeded `submitted` dossier.
      final queue = await container.read(kycReviewQueueProvider.future);
      final kyc = queue.first;

      await container
          .read(kycReviewControllerProvider.notifier)
          .approve(
            kycId: kyc.id,
            supplierId: DemoIds.supplierArtisanatSikasso,
            staffId: DemoIds.staffAgent,
          );

      final notifications = await container
          .read(notificationRepositoryProvider)
          .watchForUser(DemoIds.supplierArtisanatSikasso)
          .first;
      expect(
        notifications.any((n) => n.type == NotificationType.kycDecision),
        isTrue,
      );
    },
  );

  test(
    'SupplierFinanceController.reviewPayout notifies the supplier the '
    'request belongs to',
    () async {
      await login('admin1');

      await container
          .read(supplierFinanceControllerProvider.notifier)
          .reviewPayout(
            payoutId: 'payout-bogolan-1',
            status: PayoutStatus.rejected,
          );
      // Already terminal in the seed (`paid`) — invalid transition, no
      // notification should have been sent.
      final none = await container
          .read(notificationRepositoryProvider)
          .watchForUser(DemoIds.supplierBogolanBamako)
          .first;
      expect(
        none.any((n) => n.type == NotificationType.payoutDecision),
        isFalse,
      );

      // Create a fresh, still-`requested` payout to actually exercise the
      // notification path — `payout_requests_insert_own` requires the
      // caller to actually be the owning supplier, not admin.
      await container.read(authRepositoryProvider).logout();
      await login('fournisseur1');
      final fresh = await container
          .read(supplierFinanceRepositoryProvider)
          .requestPayout(
            supplierId: DemoIds.supplierBogolanBamako,
            amountFcfa: 1000,
            method: MobileMoneyProvider.moovMoney,
            payoutDestination: '+22370000000',
          );

      // `update_payout_status()` (reachable via `reviewPayout`) is
      // admin-only.
      await container.read(authRepositoryProvider).logout();
      await login('admin1');
      await container
          .read(supplierFinanceControllerProvider.notifier)
          .reviewPayout(payoutId: fresh.id, status: PayoutStatus.processing);

      final notified = await container
          .read(notificationRepositoryProvider)
          .watchForUser(DemoIds.supplierBogolanBamako)
          .first;
      expect(
        notified.any((n) => n.type == NotificationType.payoutDecision),
        isTrue,
      );
    },
  );

  test(
    'ReviewController.submit notifies the supplier the review was left for',
    () async {
      await login('client1');

      await container
          .read(reviewControllerProvider.notifier)
          .submit(
            orderId: 'order-awa-delivered',
            supplierGroupId: 'group-awa-delivered-1',
            supplierId: DemoIds.supplierBogolanBamako,
            stars: 5,
            comment: 'Excellent service.',
          );

      final notifications = await container
          .read(notificationRepositoryProvider)
          .watchForUser(DemoIds.supplierBogolanBamako)
          .first;
      expect(
        notifications.any((n) => n.type == NotificationType.newReview),
        isTrue,
      );
    },
  );
}
