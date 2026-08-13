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

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
    'paying "now" after a Mobile Money provider is confirmed records the '
    'order as paid',
    () async {
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
      expect(order.paymentStatus, PaymentStatus.paid);
      expect(order.mobileMoneyProvider, MobileMoneyProvider.orangeMoney);
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
      container.read(supplierMessageTypeProvider.notifier).state =
          SupplierMessageType.voice;
      container.read(supplierMessageVoicePathProvider.notifier).state =
          '/tmp/voice.m4a';
      container.read(supplierMessageVoiceDurationProvider.notifier).state = 7;

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();

      expect(success, isTrue);
      final order = container.read(checkoutControllerProvider).valueOrNull;
      expect(order!.supplierMessageType, SupplierMessageType.voice);
      expect(order.supplierMessageVoicePath, '/tmp/voice.m4a');
      expect(order.supplierMessageVoiceDurationSeconds, 7);
      expect(order.supplierMessageText, isNull);
    },
  );
}
