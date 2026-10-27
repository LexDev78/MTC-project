import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/domain/notification_route_resolver.dart';

void main() {
  const referenceId = 'ref-123';
  const supplierPrefix = '/supplier-tiers';

  test('a null referenceId never resolves to a route, for any type', () {
    for (final type in NotificationType.values) {
      for (final isClient in [true, false]) {
        expect(
          resolveNotificationRoute(
            type: type,
            referenceId: null,
            isClient: isClient,
            supplierRoutePrefix: supplierPrefix,
          ),
          isNull,
          reason: '$type / isClient=$isClient',
        );
      }
    }
  });

  test('newMessage routes to the chat thread, client vs. supplier', () {
    expect(
      resolveNotificationRoute(
        type: NotificationType.newMessage,
        referenceId: referenceId,
        isClient: true,
        supplierRoutePrefix: supplierPrefix,
      ),
      '/client/chat/$referenceId',
    );
    expect(
      resolveNotificationRoute(
        type: NotificationType.newMessage,
        referenceId: referenceId,
        isClient: false,
        supplierRoutePrefix: supplierPrefix,
      ),
      '$supplierPrefix/messages/$referenceId',
    );
  });

  test(
    'newOrder and orderStatusUpdate both route to the order, client vs. '
    'supplier',
    () {
      for (final type in [
        NotificationType.newOrder,
        NotificationType.orderStatusUpdate,
      ]) {
        expect(
          resolveNotificationRoute(
            type: type,
            referenceId: referenceId,
            isClient: true,
            supplierRoutePrefix: supplierPrefix,
          ),
          '/client/orders/$referenceId',
          reason: '$type client',
        );
        expect(
          resolveNotificationRoute(
            type: type,
            referenceId: referenceId,
            isClient: false,
            supplierRoutePrefix: supplierPrefix,
          ),
          '$supplierPrefix/orders/$referenceId',
          reason: '$type supplier',
        );
      }
    },
  );

  test(
    'newComment routes the client to the product, the supplier to their '
    'comment inbox',
    () {
      expect(
        resolveNotificationRoute(
          type: NotificationType.newComment,
          referenceId: referenceId,
          isClient: true,
          supplierRoutePrefix: supplierPrefix,
        ),
        '/client/product/$referenceId',
      );
      expect(
        resolveNotificationRoute(
          type: NotificationType.newComment,
          referenceId: referenceId,
          isClient: false,
          supplierRoutePrefix: supplierPrefix,
        ),
        '$supplierPrefix/products/comments',
      );
    },
  );

  test(
    'lowStock, kycDecision, payoutDecision, newReview and '
    'characteristicTypeDecision never resolve to a route yet, even with a '
    'referenceId',
    () {
      for (final type in [
        NotificationType.lowStock,
        NotificationType.kycDecision,
        NotificationType.payoutDecision,
        NotificationType.newReview,
        NotificationType.characteristicTypeDecision,
      ]) {
        for (final isClient in [true, false]) {
          expect(
            resolveNotificationRoute(
              type: type,
              referenceId: referenceId,
              isClient: isClient,
              supplierRoutePrefix: supplierPrefix,
            ),
            isNull,
            reason: '$type / isClient=$isClient',
          );
        }
      }
    },
  );
}
