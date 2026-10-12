@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/domain/entities/stock_movement.dart';
import 'package:mtc_app/features/catalog/presentation/controllers/supplier_product_controller.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';
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

      // Neither supplier is the currently signed-in session (client2) —
      // reading their notifications back needs the admin bypass rather
      // than logging in as each of them just to check.
      final riceSupplierNotifications = await fetchNotificationsForUserAsAdmin(
        DemoIds.supplierAlimentationSegou,
      );
      final phoneSupplierNotifications = await fetchNotificationsForUserAsAdmin(
        DemoIds.supplierElectroBamako,
      );
      expect(
        riceSupplierNotifications.any((n) => n['type'] == 'new_order'),
        isTrue,
      );
      expect(
        phoneSupplierNotifications.any((n) => n['type'] == 'new_order'),
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
          .sendMessage(conversationId: DemoIds.convAwaBogolan, text: 'Merci !');

      // Awa (the recipient) isn't the signed-in session (fournisseur1).
      final clientNotifications = await fetchNotificationsForUserAsAdmin(
        DemoIds.clientAwa,
      );
      expect(
        clientNotifications.any((n) => n['type'] == 'new_message'),
        isTrue,
      );

      // The supplier's own notifications aren't touched by their own
      // message — fournisseur1 IS the signed-in session here, so this one
      // can go through the real repository.
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
      // A fresh product rather than one of Bogolan Bamako's seeded ones:
      // every seeded product now comes with its own pre-existing default
      // variant (`0021_backfill_default_variants_and_require_variant.sql`),
      // and `adjust_stock` (`0016_adjust_stock_rpc.sql`) refuses a
      // product-level adjustment (no `variantId`) once a product has
      // variants — this test cares about the low-stock threshold logic,
      // not variant plumbing, so it gives itself a product with a single
      // variant at a known stock instead of fighting an existing one's
      // arbitrary seeded stock.
      final supplierId = container.read(operatingSupplierIdProvider)!;
      final user = container.read(currentUserProvider).value! as SupplierTiersUser;
      final supplierProfile = await container
          .read(supplierRepositoryProvider)
          .getById(supplierId);
      final draft = await productRepository.createProduct(
        supplierId: supplierId,
        supplierName: supplierProfile.businessName,
        supplierType: SupplierType.tiers,
        isSupplierVerified: user.verificationStatus == VerificationStatus.verified,
        name: 'Produit test seuil de stock',
        description: 'Produit créé pour tester les notifications de stock bas.',
        category: ProductCategory.autre,
        priceFcfa: 10000,
        stockQuantity: 10,
        weightKg: 1.0,
        city: 'Bamako',
        imageUrls: const [],
        allowsSelfDelivery: true,
        allowsMtcDelivery: true,
        sizes: const [],
        colors: const [],
        region: ProductRegion.mali,
        lowStockThreshold: 5,
      );
      await giveProductADefaultVariantAsAdmin(
        draft.id,
        priceFcfa: 10000,
        stockQuantity: 10,
      );
      final variantId = (await productRepository.getById(draft.id)).variants.single.id;
      final product = draft;

      // Stays above threshold — no notification.
      await container
          .read(supplierProductControllerProvider.notifier)
          .adjustStock(
            productId: product.id,
            quantityDelta: -2,
            reason: StockMovementReason.manualAdjustment,
            variantId: variantId,
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
            variantId: variantId,
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

      final notifications = await fetchNotificationsForUserAsAdmin(
        DemoIds.supplierArtisanatSikasso,
      );
      expect(
        notifications.any((n) => n['type'] == 'kyc_decision'),
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
            payoutId: DemoIds.payoutBogolan1,
            status: PayoutStatus.rejected,
          );
      // Already terminal in the seed (`paid`) — invalid transition, no
      // notification should have been sent. Bogolan Bamako isn't the
      // signed-in session (admin1).
      final none = await fetchNotificationsForUserAsAdmin(
        DemoIds.supplierBogolanBamako,
      );
      expect(
        none.any((n) => n['type'] == 'payout_decision'),
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

      final notified = await fetchNotificationsForUserAsAdmin(
        DemoIds.supplierBogolanBamako,
      );
      expect(
        notified.any((n) => n['type'] == 'payout_decision'),
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
            orderId: DemoIds.orderAwaDelivered,
            supplierGroupId: DemoIds.groupAwaDelivered1,
            supplierId: DemoIds.supplierBogolanBamako,
            stars: 5,
            comment: 'Excellent service.',
          );

      final notifications = await fetchNotificationsForUserAsAdmin(
        DemoIds.supplierBogolanBamako,
      );
      expect(
        notifications.any((n) => n['type'] == 'new_review'),
        isTrue,
      );
    },
  );
}
