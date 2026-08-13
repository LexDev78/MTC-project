import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/domain/order_status_transitions.dart';

void main() {
  test('a status never "transitions" to itself', () {
    for (final status in OrderStatus.values) {
      expect(isValidTransition(status, status), isFalse);
    }
  });

  test('the forward path allows both adjacent and skipped steps', () {
    expect(isValidTransition(OrderStatus.pending, OrderStatus.confirmed), isTrue);
    expect(isValidTransition(OrderStatus.pending, OrderStatus.preparing), isTrue);
    expect(isValidTransition(OrderStatus.pending, OrderStatus.inTransit), isTrue);
    expect(isValidTransition(OrderStatus.pending, OrderStatus.delivered), isTrue);
    expect(
      isValidTransition(OrderStatus.confirmed, OrderStatus.delivered),
      isTrue,
    );
  });

  test('the forward path never runs backward', () {
    expect(
      isValidTransition(OrderStatus.delivered, OrderStatus.pending),
      isFalse,
    );
    expect(
      isValidTransition(OrderStatus.inTransit, OrderStatus.confirmed),
      isFalse,
    );
    expect(
      isValidTransition(OrderStatus.preparing, OrderStatus.pending),
      isFalse,
    );
  });

  test('cancellation is allowed from any non-terminal status', () {
    expect(
      isValidTransition(OrderStatus.pending, OrderStatus.cancelled),
      isTrue,
    );
    expect(
      isValidTransition(OrderStatus.confirmed, OrderStatus.cancelled),
      isTrue,
    );
    expect(
      isValidTransition(OrderStatus.preparing, OrderStatus.cancelled),
      isTrue,
    );
    expect(
      isValidTransition(OrderStatus.inTransit, OrderStatus.cancelled),
      isTrue,
    );
  });

  test('delivered and cancelled are terminal — nothing moves out of them', () {
    for (final target in OrderStatus.values) {
      expect(isValidTransition(OrderStatus.delivered, target), isFalse);
      expect(isValidTransition(OrderStatus.cancelled, target), isFalse);
    }
  });
}
