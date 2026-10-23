import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/order.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/providers/supplier_order_providers.dart';
import 'package:mtc_app/features/orders/presentation/screens/supplier_order_detail_screen.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

/// Ce qu'une boutique voit du client sur sa commande, selon qui livre et où
/// en est sa part. Le serveur décide (`client_contact`, `0120`) ; l'écran
/// montre ce qu'il reçoit, et dit pourquoi le reste manque.

const _boutique = 'boutique-1';

SupplierOrderView _vue({
  required DeliveryMode livraison,
  required OrderStatus statut,
  OrderContact? contact,
}) => (
  orderId: 'cmd-1',
  placedAt: DateTime(2026, 10, 21, 9, 30),
  clientDisplayNameSnapshot: 'Awa Traoré',
  clientId: 'client-awa',
  deliveryCity: 'Bamako',
  contact: contact,
  myGroup: OrderSupplierGroup(
    id: 'groupe-1',
    supplierId: _boutique,
    supplierName: 'Bogolan Bamako',
    items: const [
      OrderItem(
        productId: 'p1',
        productNameSnapshot: 'Tissu bogolan',
        unitPriceFcfaSnapshot: 15000,
        quantity: 1,
      ),
    ],
    deliveryMode: livraison,
    deliveryFeeFcfa: 0,
    subtotalFcfa: 15000,
    status: statut,
  ),
);

const _adresse = OrderContact(
  addressLabel: 'Maison',
  addressDetails: 'Rue 12, porte 34',
  latitude: 12.6,
  longitude: -8.0,
);

Future<void> _ouvrir(WidgetTester tester, SupplierOrderView vue) async {
  tester.view.physicalSize = const Size(375, 1200) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        operatingSupplierIdProvider.overrideWithValue(_boutique),
        supplierOrderDetailProvider.overrideWith(
          (ref, args) => Stream.value(vue),
        ),
        deliveryForGroupProvider.overrideWith((ref, id) => Stream.value(null)),
        // La photo de l'article n'est pas le sujet : elle reste en chemin.
        productDetailProvider.overrideWith(
          (ref, id) => Completer<Product>().future,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const SupplierOrderDetailScreen(orderId: 'cmd-1'),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('la boutique qui livre elle-même voit numéro et adresse', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      _vue(
        livraison: DeliveryMode.selfDelivery,
        statut: OrderStatus.confirmed,
        contact: _adresse.copyWith(
          phone: '+22371111111',
          alternatePhone: '+22372222222',
        ),
      ),
    );

    expect(find.text('Awa Traoré'), findsOneWidget);
    expect(
      find.text('+22371111111 · autre numéro : +22372222222'),
      findsOneWidget,
    );
    expect(find.text('Maison'), findsOneWidget);
    expect(find.text('Rue 12, porte 34, Bamako'), findsOneWidget);
  });

  testWidgets('livrée par MTC : l\'adresse, pas le numéro, et pourquoi', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      _vue(
        livraison: DeliveryMode.mtcDelivery,
        statut: OrderStatus.preparing,
        contact: _adresse,
      ),
    );

    expect(
      find.text(
        'Son numéro n\'est visible que du livreur MTC. Vous pouvez lui '
        'écrire ici.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('+223'), findsNothing);
    expect(find.text('Maison'), findsOneWidget);
  });

  testWidgets('commande terminée : ni numéro ni adresse, mais la discussion', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      _vue(livraison: DeliveryMode.selfDelivery, statut: OrderStatus.delivered),
    );

    expect(find.text('Awa Traoré'), findsOneWidget);
    expect(
      find.text(
        'Commande terminée : son numéro et son adresse ne sont plus '
        'affichés. Vous pouvez lui écrire ici.',
      ),
      findsOneWidget,
    );
    expect(find.text('Maison'), findsNothing);
    expect(find.textContaining('Rue 12'), findsNothing);
    expect(find.byTooltip('Écrire au client'), findsOneWidget);
  });
}
