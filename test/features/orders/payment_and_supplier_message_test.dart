@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/fulfillment.dart';
import 'package:mtc_app/features/orders/domain/entities/payment.dart';
import 'package:mtc_app/features/orders/presentation/controllers/checkout_controller.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';

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

    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: 'client2', password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await container.read(addressesProvider.future);
    await container.read(checkoutGroupsProvider.future);
    await container.read(checkoutControllerProvider.future);
  });

  test(
    'paying "now" without confirming a Mobile Money provider fails with a '
    'validation error',
    () async {
      container.read(paymentMethodProvider.notifier).state =
          PaymentMethod.now;

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();

      expect(success, isFalse);
      expect(
        container.read(checkoutControllerProvider).error,
        isA<ValidationException>(),
      );
    },
  );

  test(
    'paying "now" records the chosen provider but never presumes the money '
    'arrived',
    () async {
      // Ce test exigeait auparavant `PaymentStatus.paid` — il encodait donc
      // la faille, et c'est à ce titre qu'il a échoué quand elle a été
      // refermée (`0106`). L'app posait ce statut elle-même dès que le
      // client cochait « payer maintenant », alors qu'aucune intégration
      // Orange Money ou Moov n'existe : le fournisseur lisait « Payé » et
      // expédiait sans qu'un franc ait bougé.
      //
      // Ce qui est juste, et ce que l'on vérifie : le choix du client est
      // conservé — méthode et opérateur —, mais l'encaissement n'est pas
      // présumé. Seul `mark_order_paid()`, réservé au staff MTC, peut dire
      // une commande payée. Si cette attente est un jour remise à `paid`,
      // c'est que la faille est revenue.
      container.read(paymentMethodProvider.notifier).state =
          PaymentMethod.now;
      container.read(mobileMoneyProviderChoiceProvider.notifier).state =
          MobileMoneyProvider.orangeMoney;

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();

      expect(success, isTrue);
      final order = container.read(checkoutControllerProvider).valueOrNull;
      expect(order, isNotNull);
      expect(order!.paymentMethod, PaymentMethod.now);
      expect(order.mobileMoneyProvider, MobileMoneyProvider.orangeMoney);
      expect(order.paymentStatus, PaymentStatus.pendingOnDelivery);
    },
  );

  test(
    'defaulting to "on delivery" payment (no interaction) still places the '
    'order, pending payment',
    () async {
      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();

      expect(success, isTrue);
      final order = container.read(checkoutControllerProvider).valueOrNull;
      expect(order!.paymentMethod, PaymentMethod.onDelivery);
      expect(order.paymentStatus, PaymentStatus.pendingOnDelivery);
      expect(order.mobileMoneyProvider, isNull);
    },
  );

  test('a home-delivery order carries the alternate phone, if set', () async {
    container.read(alternatePhoneProvider.notifier).state = '+22376543210';

    final success = await container
        .read(checkoutControllerProvider.notifier)
        .placeOrder();

    expect(success, isTrue);
    final order = container.read(checkoutControllerProvider).valueOrNull;
    expect(order!.alternatePhone, '+22376543210');
  });

  test(
    'a written message to the supplier is recorded as SupplierMessageType.text',
    () async {
      container.read(supplierMessageTypeProvider.notifier).state =
          SupplierMessageType.text;
      container.read(supplierMessageTextProvider.notifier).state =
          'Sonnez deux fois, merci.';

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();

      expect(success, isTrue);
      final order = container.read(checkoutControllerProvider).valueOrNull;
      expect(order!.supplierMessageType, SupplierMessageType.text);
      expect(order.supplierMessageText, 'Sonnez deux fois, merci.');
      expect(order.supplierMessageVoicePath, isNull);
    },
  );

  test(
    'a voice message to the supplier is recorded as SupplierMessageType.voice '
    'with its path and duration',
    () async {
      // `attachSupplierVoiceMessage` uploads the local recording for real
      // (Lot 9) — needs an actual file on disk, and the stored path ends
      // up as the uploaded `order-messages` object path, not the local
      // path passed in.
      final localFile = File(
        '${Directory.systemTemp.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await localFile.writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);

      container.read(supplierMessageTypeProvider.notifier).state =
          SupplierMessageType.voice;
      container.read(supplierMessageVoicePathProvider.notifier).state =
          localFile.path;
      container.read(supplierMessageVoiceDurationProvider.notifier).state = 7;

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();

      expect(success, isTrue);
      final order = container.read(checkoutControllerProvider).valueOrNull;
      expect(order!.supplierMessageType, SupplierMessageType.voice);
      expect(order.supplierMessageVoicePath, startsWith('${order.id}/'));
      expect(order.supplierMessageVoicePath, isNot(localFile.path));
      expect(order.supplierMessageVoiceDurationSeconds, 7);
      expect(order.supplierMessageText, isNull);
    },
  );
}
