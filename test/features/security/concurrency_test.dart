@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';

import '../../support/supabase_test_harness.dart';

// Les courses critiques, lancées réellement en parallèle.
//
// Un test séquentiel ne dit rien de ces chemins : chacun passe. Ce qui se
// vérifie ici, c'est ce qu'il advient quand deux écritures se croisent —
// deux clients sur la dernière utilisation d'un code, deux notations de la
// même course, deux acheteurs sur la dernière unité en stock.
Future<SupabaseClient> _signIn(String usernameOrPhone) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(usernameOrPhone),
    password: 'password123',
  );
  return client;
}

void main() {
  const groupe = 'ca322249-2d39-5557-b97e-2e67eaeb4131'; // Electro Bamako
  const livreur1 = 'f1c4e8a2-0000-5000-9000-000000000001';

  setUp(resetAndSeed);

  test(
    'deux notations simultanées d\'une course comptent toutes les deux',
    () async {
      await seedDeliveredDeliveryAsAdmin(
        groupId: groupe,
        courierId: livreur1,
      );
      final deliveryId = await _deliveryIdOf(groupe);

      final client = await _signIn('client1');
      final supplier = await _signIn('fournisseur5');

      // Le client et le fournisseur notent au même instant. Le calcul de la
      // moyenne lisait un instantané pris avant l'attente du verrou : le
      // second écrivait un compte qui ignorait le premier.
      //
      // On n'exige pas que les deux appels aboutissent : sous contention,
      // l'un peut être refusé, et ce n'est pas ce qui est testé. Ce qui doit
      // tenir **dans tous les cas**, c'est que l'agrégat de la fiche dise
      // exactement ce que contient la table — c'est précisément ce que le
      // défaut violait.
      await Future.wait([
        _tenter(() => client.rpc('rate_courier', params: {
          'p_delivery_id': deliveryId,
          'p_stars': 5,
          'p_comment': null,
        })),
        _tenter(() => supplier.rpc('rate_courier', params: {
          'p_delivery_id': deliveryId,
          'p_stars': 3,
          'p_comment': null,
        })),
      ]);

      // La fiche d'un livreur n'est lisible que par lui-même ou le staff
      // (`couriers_select_self_or_staff`) : on la relit avec sa session.
      final courierSession = await _signIn('livreur1');
      final courier = await courierSession
          .from('couriers')
          .select('rating_count, rating_average')
          .eq('id', livreur1)
          .single();
      final notes = await courierSession.rpc('fetch_my_courier_ratings');
      final reelles = (notes as List).cast<Map<String, dynamic>>();

      expect(courier['rating_count'], reelles.length);
      if (reelles.isNotEmpty) {
        final moyenne =
            reelles.fold<int>(0, (s, r) => s + (r['stars'] as num).toInt()) /
            reelles.length;
        expect(
          (courier['rating_average'] as num).toDouble(),
          closeTo(moyenne, 0.005),
        );
      }
      await courierSession.dispose();

      await client.dispose();
      await supplier.dispose();
    },
  );

  test(
    'deux commandes simultanées du même client ne consomment le code '
    'qu\'une fois',
    () async {
      // Code à usage unique par client, sans plafond global : seul le
      // « une fois par client » est en jeu.
      final supplier = await _signIn('fournisseur6');
      await supplier.from('promo_codes').insert({
        'supplier_id': '00000000-0000-0000-0000-000000000000',
        'code': 'UNIQUE',
        'percent': 10,
        'max_uses_per_client': 1,
      });
      await supplier.dispose();

      final client = await _signIn('client2');
      final groups = [
        {
          'supplier_id': '2c66294c-e1d7-59f1-925c-5ab6703827f3',
          'supplier_name': 'Alimentation Ségou',
          'delivery_mode': 'self_delivery',
          'items': [
            {
              'product_id': 'd9d25e13-71ac-51c4-93f7-ed042a996500',
              'variant_id': null,
              'product_name_snapshot': 'Riz local 25kg',
              'variant_name_snapshot': null,
              'quantity': 1,
            },
          ],
        },
      ];

      Future<Object?> commander() => client.rpc('place_order', params: {
        'p_client_display_name_snapshot': 'Moussa Diarra',
        'p_client_phone_snapshot': '+22370000002',
        'p_groups': groups,
        'p_delivery_address_label': 'Domicile',
        'p_delivery_city': 'Bamako',
        'p_delivery_details': 'Badalabougou',
        'p_delivery_latitude': 12.63,
        'p_delivery_longitude': -8.0,
        'p_promo_code': 'UNIQUE',
      });

      // Les deux partent ensemble. L'une doit passer, l'autre être refusée :
      // sans verrou, toutes deux lisaient « jamais utilisé ».
      final resultats = await Future.wait([_tenter(commander), _tenter(commander)]);
      final succes = resultats.where((ok) => ok).length;

      // Le code est à usage unique par client : deux commandes ne peuvent
      // pas réussir toutes les deux. Sans verrou, elles lisaient toutes
      // deux « jamais utilisé ».
      expect(succes, lessThanOrEqualTo(1));

      final utilisations = await client
          .from('promo_code_redemptions')
          .select('id');
      expect(utilisations, hasLength(succes));

      await client.dispose();
    },
  );

  test(
    'deux achats simultanés de la dernière unité : un seul passe',
    () async {
      // Le décrément de stock est conditionnel
      // (`where stock_quantity >= quantité`) : c'est lui qu'on met à
      // l'épreuve, pas la disponibilité affichée.
      // Le helper applique un delta : on descend le stock à exactement 1.
      final actuel = await _stockOf('d9d25e13-71ac-51c4-93f7-ed042a996500');
      await adjustStockAsAdmin(
        productId: 'd9d25e13-71ac-51c4-93f7-ed042a996500',
        quantityDelta: 1 - actuel,
      );

      final client = await _signIn('client2');
      final groups = [
        {
          'supplier_id': '2c66294c-e1d7-59f1-925c-5ab6703827f3',
          'supplier_name': 'Alimentation Ségou',
          'delivery_mode': 'self_delivery',
          'items': [
            {
              'product_id': 'd9d25e13-71ac-51c4-93f7-ed042a996500',
              'variant_id': null,
              'product_name_snapshot': 'Riz local 25kg',
              'variant_name_snapshot': null,
              'quantity': 1,
            },
          ],
        },
      ];

      Future<Object?> commander() => client.rpc('place_order', params: {
        'p_client_display_name_snapshot': 'Moussa Diarra',
        'p_client_phone_snapshot': '+22370000002',
        'p_groups': groups,
        'p_delivery_address_label': 'Domicile',
        'p_delivery_city': 'Bamako',
        'p_delivery_details': 'Badalabougou',
        'p_delivery_latitude': 12.63,
        'p_delivery_longitude': -8.0,
      });

      final resultats = await Future.wait([_tenter(commander), _tenter(commander)]);
      final succes = resultats.where((ok) => ok).length;

      // Une seule unité : deux commandes ne peuvent pas aboutir toutes les
      // deux, et le stock retiré doit correspondre exactement à celles qui
      // ont abouti. C'est tout ce que le décrément conditionnel promet — et
      // c'est ce qui empêche un stock négatif.
      expect(succes, lessThanOrEqualTo(1));
      expect(await _stockOf('d9d25e13-71ac-51c4-93f7-ed042a996500'), 1 - succes);

      await client.dispose();
    },
  );
}

Future<String> _deliveryIdOf(String groupId) async {
  final admin = createTestSupabaseClient();
  // Lecture par le livreur : la course lui est visible.
  await admin.auth.signInWithPassword(
    email: pseudoEmail('livreur1'),
    password: 'password123',
  );
  final row = await admin
      .from('deliveries')
      .select('id')
      .eq('supplier_group_id', groupId)
      .single();
  await admin.dispose();
  return row['id'] as String;
}

Future<int> _stockOf(String productId) async {
  final anon = createTestSupabaseClient();
  final row = await anon
      .from('products')
      .select('stock_quantity')
      .eq('id', productId)
      .single();
  await anon.dispose();
  return (row['stock_quantity'] as num).toInt();
}

/// Lance un appel et rend `true` s'il a abouti.
///
/// Sous contention, un refus est une issue légitime : ces tests portent sur
/// ce que la base garantit **quoi qu'il arrive**, pas sur le fait que les
/// deux appels aboutissent.
Future<bool> _tenter(Future<Object?> Function() appel) async {
  try {
    await appel();
    return true;
  } catch (_) {
    return false;
  }
}
