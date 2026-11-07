import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/domain/order_status_transitions.dart';

void main() {
  test('a status never "transitions" to itself', () {
    for (final status in OrderStatus.values) {
      expect(isValidTransition(status, status), isFalse);
    }
  });

  test('the forward path only allows the immediately next step', () {
    expect(isValidTransition(OrderStatus.pending, OrderStatus.confirmed), isTrue);
    expect(isValidTransition(OrderStatus.confirmed, OrderStatus.preparing), isTrue);
    expect(isValidTransition(OrderStatus.preparing, OrderStatus.inTransit), isTrue);
    expect(isValidTransition(OrderStatus.inTransit, OrderStatus.delivered), isTrue);
  });

  test('the forward path rejects skipping intermediate steps', () {
    expect(isValidTransition(OrderStatus.pending, OrderStatus.preparing), isFalse);
    expect(isValidTransition(OrderStatus.pending, OrderStatus.inTransit), isFalse);
    expect(isValidTransition(OrderStatus.pending, OrderStatus.delivered), isFalse);
    expect(
      isValidTransition(OrderStatus.confirmed, OrderStatus.delivered),
      isFalse,
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

  test('the client may only cancel a still-pending group', () {
    expect(canClientCancel(OrderStatus.pending), isTrue);
    expect(canClientCancel(OrderStatus.confirmed), isFalse);
    expect(canClientCancel(OrderStatus.preparing), isFalse);
    expect(canClientCancel(OrderStatus.inTransit), isFalse);
    expect(canClientCancel(OrderStatus.delivered), isFalse);
    expect(canClientCancel(OrderStatus.cancelled), isFalse);
  });
}
