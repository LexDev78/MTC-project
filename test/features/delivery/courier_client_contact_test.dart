import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/features/delivery/data/datasources/supabase_delivery_datasource.dart';
import 'package:mtc_app/features/delivery/data/repositories/supabase_delivery_repository.dart';
import 'package:mtc_app/features/delivery/domain/entities/courier_delivery.dart';
import 'package:mtc_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:mtc_app/features/delivery/presentation/screens/courier_delivery_screen.dart';

/// Ce que le livreur voit du client : l'adresse dès la proposition, le
/// numéro une fois la course acceptée, plus rien une fois livrée. Le serveur
/// décide (`client_contact`, `0120`) ; l'app lit ce qu'il rend, et le dit
/// quand quelque chose manque.

/// Une ligne de `deliveries` telle que la requête imbriquée la rend.
Map<String, dynamic> _ligne({
  required String statut,
  Map<String, dynamic>? contact,
}) => {
  'id': 'course-1',
  'order_id': 'cmd-1',
  'supplier_group_id': 'groupe-1',
  'status': statut,
  'offer_expires_at': null,
  // L'adresse de retrait, rendue à part (`pickup_point`, `0133`).
  'pickup_point': {'full_address': 'Marché Rose'},
  'order_data': {
    'id': 'cmd-1',
    'client_display_name_snapshot': 'Awa Traoré',
    'delivery_city': 'Bamako',
    'payment_method': 'on_delivery',
    'client_contact': contact,
  },
  'group_data': {
    'id': 'groupe-1',
    'supplier_name': 'Electro Bamako',
    'delivery_fee_fcfa': 1000,
    'subtotal_fcfa': 85000,
    'supplier': {'city': 'Bamako', 'public_phone_numbers': <String>[]},
    'items': [
      {
        'product_name_snapshot': 'Smartphone',
        'quantity': 1,
        'variant_name_snapshot': null,
      },
    ],
  },
};

const _adresse = {
  'address_label': 'Maison',
  'address_details': 'Rue 12, porte 34',
  'latitude': 12.6,
  'longitude': -8,
};

class _Source implements SupabaseDeliveryDatasource {
  _Source(this.lignes);

  final List<Map<String, dynamic>> lignes;

  @override
  Stream<List<Map<String, dynamic>>> watchForCourier(String courierId) =>
      Stream.value(lignes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<CourierDelivery> _lire(Map<String, dynamic> ligne) async =>
    (await SupabaseDeliveryRepository(
      _Source([ligne]),
    ).watchForCourier('livreur-1').first).single;

Future<void> _ouvrir(WidgetTester tester, CourierDelivery course) async {
  tester.view.physicalSize = const Size(375, 1400) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        courierDeliveriesProvider.overrideWith((ref) => Stream.value([course])),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const CourierDeliveryScreen(deliveryId: 'course-1'),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('lecture de la course', () {
    test('acceptée : numéros et adresse', () async {
      final course = await _lire(
        _ligne(
          statut: 'accepted',
          contact: {
            ..._adresse,
            'phone': '+22371111111',
            'alternate_phone': '+22372222222',
          },
        ),
      );
      expect(course.clientPhone, '+22371111111');
      expect(course.clientAlternatePhone, '+22372222222');
      expect(course.deliveryAddressLabel, 'Maison');
      expect(course.deliveryDetails, 'Rue 12, porte 34');
      expect(course.deliveryLatitude, 12.6);
      expect(course.deliveryLongitude, -8.0);
    });

    test('proposée : l\'adresse sans le numéro', () async {
      final course = await _lire(_ligne(statut: 'offered', contact: _adresse));
      expect(course.clientPhone, isNull);
      expect(course.deliveryAddressLabel, 'Maison');
    });

    test('livrée : plus rien, sauf le nom et la ville', () async {
      final course = await _lire(_ligne(statut: 'delivered'));
      expect(course.clientName, 'Awa Traoré');
      expect(course.deliveryCity, 'Bamako');
      expect(course.clientPhone, isNull);
      expect(course.deliveryAddressLabel, isNull);
      expect(course.deliveryLatitude, isNull);
    });

    test('en route sans adresse : pas d\'itinéraire inventé', () async {
      final course = await _lire(_ligne(statut: 'picked_up'));
      expect(course.currentLeg, isNull);
    });
  });

  group('la feuille de route', () {
    testWidgets('proposée : l\'adresse, et le numéro annoncé pour plus tard', (
      tester,
    ) async {
      await _ouvrir(
        tester,
        await _lire(_ligne(statut: 'offered', contact: _adresse)),
      );

      expect(find.text('Maison'), findsOneWidget);
      expect(find.text('Rue 12, porte 34'), findsOneWidget);
      expect(
        find.text(
          'Le numéro du client s\'affichera quand vous aurez accepté la '
          'course.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('+223'), findsNothing);
    });

    testWidgets('acceptée : le numéro est là', (tester) async {
      await _ouvrir(
        tester,
        await _lire(
          _ligne(
            statut: 'accepted',
            contact: {..._adresse, 'phone': '+22371111111'},
          ),
        ),
      );

      expect(find.text('+22371111111'), findsOneWidget);
      expect(find.text('Maison'), findsOneWidget);
      expect(find.textContaining('s\'affichera'), findsNothing);
    });

    testWidgets('livrée : ni numéro ni adresse, et pourquoi', (tester) async {
      await _ouvrir(tester, await _lire(_ligne(statut: 'delivered')));

      expect(find.text('Awa Traoré'), findsOneWidget);
      expect(find.text('Maison'), findsNothing);
      expect(find.textContaining('+223'), findsNothing);
      expect(
        find.text(
          'Course terminée : le numéro et l\'adresse du client ne sont plus '
          'affichés.',
        ),
        findsOneWidget,
      );
    });
  });
}
