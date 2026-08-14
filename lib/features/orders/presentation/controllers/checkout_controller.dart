import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/storage/image_upload.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';

import '../../domain/entities/fulfillment.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/payment.dart';
import '../providers/checkout_providers.dart';
import '../providers/order_providers.dart';

class CheckoutController extends AsyncNotifier<Order?> {
  @override
  Future<Order?> build() async => null;

  Future<bool> placeOrder() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user is! ClientUser) return false;
    final userId = user.id;

    final fulfillmentMethod = ref.read(fulfillmentMethodProvider);
    final String deliveryAddressLabel;
    final String deliveryCity;
    final String deliveryDetails;
    final double deliveryLatitude;
    final double deliveryLongitude;

    if (fulfillmentMethod == FulfillmentMethod.pickupPoint) {
      final point = ref.read(selectedPickupPointProvider);
      if (point == null) {
        state = AsyncError(
          const ValidationException(
            'Choisissez un point de retrait avant de commander.',
          ),
          StackTrace.current,
        );
        return false;
      }
      deliveryAddressLabel = point.name;
      deliveryCity = point.city;
      deliveryDetails = point.address;
      deliveryLatitude = point.latitude;
      deliveryLongitude = point.longitude;
    } else {
      final address = ref.read(defaultAddressProvider);
      if (address == null) {
        state = AsyncError(
          const ValidationException(
            'Ajoutez une adresse de livraison avant de commander.',
          ),
          StackTrace.current,
        );
        return false;
      }
      deliveryAddressLabel = address.label;
      deliveryCity = address.city;
      deliveryDetails = address.details;
      deliveryLatitude = address.latitude;
      deliveryLongitude = address.longitude;
    }

    final paymentMethod = ref.read(paymentMethodProvider);
    final mobileMoneyProvider = ref.read(mobileMoneyProviderChoiceProvider);
    if (paymentMethod == PaymentMethod.now && mobileMoneyProvider == null) {
      state = AsyncError(
        const ValidationException('Effectuez le paiement avant de commander.'),
        StackTrace.current,
      );
      return false;
    }

    final groups = await ref.read(checkoutGroupsProvider.future);
    if (groups.isEmpty) return false;

    // Validate stock availability up front, before any write happens — a
    // single pass over every line, rather than decrementing as we go and
    // risking a partial order if a later line comes up short.
    final productRepository = ref.read(productRepositoryProvider);
    for (final group in groups) {
      for (final item in group.items) {
        final product = await productRepository.getById(item.productId);
        if (product.stockQuantity < item.quantity) {
          state = AsyncError(
            InsufficientStockException(
              'Stock insuffisant pour ${item.productNameSnapshot} : '
              '${product.stockQuantity} disponible(s), ${item.quantity} demandé(s).',
            ),
            StackTrace.current,
          );
          return false;
        }
      }
    }

    final inputs = groups.map((g) {
      // In pickup-point mode, there's no "supplier delivers it themselves"
      // option — MTC always fetches the parcel and brings it to the point.
      final mode = fulfillmentMethod == FulfillmentMethod.pickupPoint
          ? (g.allowsMtcDelivery
                ? DeliveryMode.mtcDelivery
                : DeliveryMode.selfDelivery)
          : ref.read(deliveryModeChoiceProvider(g.supplierId)) ??
                (g.allowsSelfDelivery
                    ? DeliveryMode.selfDelivery
                    : DeliveryMode.mtcDelivery);
      return CheckoutGroupInput(
        supplierId: g.supplierId,
        supplierName: g.supplierName,
        items: g.items
            .map(
              (i) => OrderItem(
                productId: i.productId,
                productNameSnapshot: i.productNameSnapshot,
                unitPriceFcfaSnapshot: i.unitPriceFcfaSnapshot,
                quantity: i.quantity,
              ),
            )
            .toList(),
        deliveryMode: mode,
        mtcDeliveryFeeFcfa: g.mtcDeliveryFeeFcfa,
      );
    }).toList();

    final isHomeDelivery = fulfillmentMethod == FulfillmentMethod.homeDelivery;
    final isPriority = isHomeDelivery && ref.read(isPriorityOrderProvider);
    final supplierMessageType = isHomeDelivery
        ? ref.read(supplierMessageTypeProvider)
        : SupplierMessageType.none;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      var order = await ref
          .read(orderRepositoryProvider)
          .placeOrder(
            clientId: userId,
            clientDisplayNameSnapshot: user.displayName,
            clientPhoneSnapshot: user.phoneNumber,
            groups: inputs,
            deliveryAddressLabel: deliveryAddressLabel,
            deliveryCity: deliveryCity,
            deliveryDetails: deliveryDetails,
            deliveryLatitude: deliveryLatitude,
            deliveryLongitude: deliveryLongitude,
            fulfillmentMethod: fulfillmentMethod,
            courierPhone: isHomeDelivery ? ref.read(courierPhoneProvider) : null,
            alternatePhone: isHomeDelivery
                ? ref.read(alternatePhoneProvider)
                : null,
            deliveryDate: isHomeDelivery
                ? ref.read(selectedDeliveryDateProvider)
                : null,
            deliveryTimeSlotLabel: isHomeDelivery
                ? ref.read(selectedDeliveryTimeSlotProvider)
                : null,
            isPriority: isPriority,
            priorityFeeFcfa: isPriority ? priorityOrderFeeFcfa : 0,
            supplierMessageType: supplierMessageType,
            supplierMessageText: supplierMessageType == SupplierMessageType.text
                ? ref.read(supplierMessageTextProvider)
                : null,
            // Never the local path here — `order-messages`'s Storage
            // policy is keyed by order id, which doesn't exist until this
            // very call returns one (see the upload step below).
            paymentMethod: paymentMethod,
            paymentStatus: paymentMethod == PaymentMethod.now
                ? PaymentStatus.paid
                : PaymentStatus.pendingOnDelivery,
            mobileMoneyProvider: mobileMoneyProvider,
          );
      // Stock is already decremented atomically inside `place_order()`
      // itself (see `supabase/migrations/0003_orders_rpc.sql`) — a client
      // session has no write access to `products`/`stock_movements`
      // (RLS requires the operating supplier), so this must not be
      // repeated here.
      await ref.read(cartRepositoryProvider).clear(userId);

      if (supplierMessageType == SupplierMessageType.voice) {
        final localPath = ref.read(supplierMessageVoicePathProvider);
        final duration = ref.read(supplierMessageVoiceDurationProvider);
        if (localPath != null && duration != null) {
          final voicePath = await uploadPickedImage(
            client: ref.read(supabaseClientProvider),
            bucket: 'order-messages',
            folder: order.id,
            file: XFile(localPath),
            contentType: 'audio/mp4',
          );
          await ref
              .read(orderRepositoryProvider)
              .attachSupplierVoiceMessage(
                orderId: order.id,
                voicePath: voicePath,
                durationSeconds: duration,
              );
          order = order.copyWith(
            supplierMessageVoicePath: voicePath,
            supplierMessageVoiceDurationSeconds: duration,
          );
        }
      }

      final notificationRepository = ref.read(notificationRepositoryProvider);
      for (final group in order.supplierGroups) {
        await notificationRepository.add(
          userId: group.supplierId,
          type: NotificationType.newOrder,
          title: 'Nouvelle commande',
          body: '${user.displayName} — ${group.items.length} article(s)',
        );
      }

      return order;
    });

    return !state.hasError;
  }
}

final checkoutControllerProvider =
    AsyncNotifierProvider<CheckoutController, Order?>(CheckoutController.new);
