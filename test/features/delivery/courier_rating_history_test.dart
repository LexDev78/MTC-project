@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/features/delivery/data/datasources/supabase_delivery_datasource.dart';
import 'package:mtc_app/features/delivery/data/repositories/supabase_delivery_repository.dart';
import 'package:mtc_app/features/delivery/domain/entities/courier_delivery.dart';
import 'package:mtc_app/features/delivery/domain/entities/courier_history.dart';
import 'package:mtc_app/features/delivery/domain/repositories/delivery_repository.dart';

import '../../support/supabase_test_harness.dart';

// Notation des livreurs (`0059`) et historique de leurs courses (`0060`).
//
// Deux promesses à tenir, et c'est ce que vérifie ce fichier :
//
//  * une note par côté, déposée seulement par le client ou le fournisseur de
//    la course, et seulement après la livraison ;
//  * un historique qui ne garde **aucune** identité — ce qui ne se vérifie
//    pas en regardant l'écran, mais en regardant ce que la lecture renvoie.
Future<SupabaseClient> _signIn(String usernameOrPhone) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(usernameOrPhone),
    password: 'password123',
  );
  return client;
}

void main() {
  const groupId = 'ca322249-2d39-5557-b97e-2e67eaeb4131'; // Electro Bamako
  const courierId = 'f1c4e8a2-0000-5000-9000-000000000001';

  late SupabaseClient courierClient;
  late DeliveryRepository asCourier;
  late String deliveryId;

  /// Décor commun : une course **livrée**, les deux scans faits. Tout ce qui
  /// suit se note ou s'historise, donc rien ne se teste avant cet état.
  setUp(() async {
    await resetAndSeed();

    courierClient = await _signIn('livreur1');
    asCourier = SupabaseDeliveryRepository(
      SupabaseDeliveryDatasource(courierClient),
    );
    await asCourier.setOnline(
      courierId: courierId,
      isOnline: true,
      latitude: 12.6392,
      longitude: -8.0029,
    );

    await adminSetGroupStatus(groupId: groupId, status: 'preparing');
    await adminSetGroupStatus(groupId: groupId, status: 'in_transit');

    final offered = await asCourier.watchForCourier(courierId).first;
    deliveryId = offered.single.id;
    await asCourier.accept(deliveryId);
  });

  tearDown(() async {
    await courierClient.dispose();
  });

  /// Mène la course à `delivered` par les deux scans, comme en vrai.
  Future<void> completeDelivery() async {
    final supplierClient = await _signIn('fournisseur5');
    final pickupCode = await SupabaseDeliveryRepository(
      SupabaseDeliveryDatasource(supplierClient),
    ).fetchCode(deliveryId: deliveryId, kind: DeliveryCodeKind.pickup);
    await supplierClient.dispose();
    await asCourier.scan(deliveryId: deliveryId, code: pickupCode!);

    final clientClient = await _signIn('client1');
    final deliveryCode = await SupabaseDeliveryRepository(
      SupabaseDeliveryDatasource(clientClient),
    ).fetchCode(deliveryId: deliveryId, kind: DeliveryCodeKind.delivery);
    await clientClient.dispose();
    await asCourier.scan(deliveryId: deliveryId, code: deliveryCode!);
  }

  test(
    'le client et le fournisseur notent chacun de leur côté, et la moyenne '
    'du livreur tient compte des deux',
    () async {
      await completeDelivery();

      final clientClient = await _signIn('client1');
      final asClient = SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(clientClient),
      );
      await asClient.rateCourier(
        deliveryId: deliveryId,
        stars: 5,
        comment: 'Rapide et poli.',
      );

      final supplierClient = await _signIn('fournisseur5');
      final asSupplier = SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(supplierClient),
      );
      await asSupplier.rateCourier(deliveryId: deliveryId, stars: 3);

      // 5 et 3 : la moyenne est bien calculée sur les deux côtés, pas
      // écrasée par le dernier qui note.
      final stats = await asCourier.fetchStats();
      expect(stats.ratingCount, 2);
      expect(stats.ratingAverage, 4.0);
      expect(stats.deliveredCount, 1);
      expect(stats.monthDeliveredCount, 1);
      expect(stats.deliveredFeesFcfa, greaterThan(0));

      // Le livreur lit ses notes avec leur origine — jamais leur auteur.
      final ratings = await asCourier.fetchMyRatings();
      expect(ratings, hasLength(2));
      expect(
        ratings.map((r) => r.raterRole),
        containsAll(<CourierRaterRole>[
          CourierRaterRole.client,
          CourierRaterRole.supplier,
        ]),
      );
      expect(
        ratings.firstWhere((r) => r.raterRole == CourierRaterRole.client).stars,
        5,
      );

      // Et il ne peut pas remonter à l'auteur par la table : aucune policy
      // ne la lui ouvre. Si celle-ci se mettait à répondre, `rater_id`
      // arriverait sur son téléphone.
      final direct = await courierClient.from('courier_ratings').select();
      expect(direct, isEmpty);

      await clientClient.dispose();
      await supplierClient.dispose();
    },
  );

  test('noter une course non encore livrée est refusé', () async {
    final clientClient = await _signIn('client1');
    final asClient = SupabaseDeliveryRepository(
      SupabaseDeliveryDatasource(clientClient),
    );

    // La course est acceptée, pas livrée : il n'y a encore rien à juger.
    await expectLater(
      asClient.rateCourier(deliveryId: deliveryId, stars: 5),
      throwsA(isA<PostgrestException>()),
    );

    await clientClient.dispose();
  });

  test(
    'un tiers ne peut pas noter une course, même livrée',
    () async {
      await completeDelivery();

      // `client2` n'est ni le client de cette commande ni son fournisseur.
      // Sans cette garde, n'importe quel compte pourrait couler la note d'un
      // livreur, ou la gonfler.
      final otherClient = await _signIn('client2');
      final asOther = SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(otherClient),
      );

      await expectLater(
        asOther.rateCourier(deliveryId: deliveryId, stars: 1),
        throwsA(isA<PostgrestException>()),
      );
      expect((await asCourier.fetchStats()).ratingCount, 0);

      await otherClient.dispose();
    },
  );

  test(
    'renoter corrige sa note au lieu d\'en ajouter une seconde',
    () async {
      await completeDelivery();

      final clientClient = await _signIn('client1');
      final asClient = SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(clientClient),
      );
      await asClient.rateCourier(deliveryId: deliveryId, stars: 2);
      await asClient.rateCourier(
        deliveryId: deliveryId,
        stars: 4,
        comment: 'Finalement très correct.',
      );

      final stats = await asCourier.fetchStats();
      expect(stats.ratingCount, 1, reason: 'une note par côté, pas deux');
      expect(stats.ratingAverage, 4.0);

      // Et l'écran retrouve la note donnée, pour ne pas reproposer un
      // formulaire vierge qui laisserait croire que rien n'est parti.
      final mine = await asClient.fetchMyRatingForDelivery(deliveryId);
      expect(mine?.stars, 4);
      expect(mine?.comment, 'Finalement très correct.');

      await clientClient.dispose();
    },
  );

  test(
    'l\'historique du livreur ne contient aucune identité : ni client, ni '
    'fournisseur',
    () async {
      await completeDelivery();

      final history = await asCourier.fetchHistory();
      expect(history, hasLength(1));
      final entry = history.single;
      expect(entry.status, DeliveryStatus.delivered);
      expect(entry.itemCount, greaterThan(0));
      expect(entry.deliveryFeeFcfa, greaterThan(0));
      expect(entry.deliveredAt, isNotNull);
      expect(entry.reference, hasLength(6));
      // Les villes restent : sans elles, un livreur ne reconnaît pas un
      // trajet dans une liste de vingt lignes.
      expect(entry.pickupCity, isNotEmpty);
      expect(entry.dropoffCity, isNotEmpty);

      // Le cœur de la promesse. On interroge la RPC directement, et non
      // l'entité, parce que c'est la **lecture** qui doit être aveugle : une
      // entité pauvre au-dessus d'une requête bavarde laisserait les
      // coordonnées arriver sur l'appareil.
      final raw = await courierClient.rpc(
        'fetch_courier_delivery_history',
        params: {'p_limit': 30, 'p_offset': 0},
      );
      final columns = (raw as List).cast<Map<String, dynamic>>().single.keys;
      expect(
        columns,
        unorderedEquals(<String>[
          'delivery_id',
          'reference',
          'status',
          'pickup_city',
          'dropoff_city',
          'item_count',
          'delivery_fee_fcfa',
          'accepted_at',
          'picked_up_at',
          'delivered_at',
          'client_stars',
          'supplier_stars',
        ]),
        reason:
            'toute colonne ajoutée ici doit être relue à l\'aune de ce que le '
            'livreur conserve après la course',
      );

      // Et la note reçue s'y rattache, côté par côté.
      final clientClient = await _signIn('client1');
      await SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(clientClient),
      ).rateCourier(deliveryId: deliveryId, stars: 5);
      await clientClient.dispose();

      final rated = (await asCourier.fetchHistory()).single;
      expect(rated.clientStars, 5);
      expect(rated.supplierStars, isNull);
      expect(rated.hasRating, isTrue);
    },
  );

  test(
    'une course en cours n\'est pas dans l\'historique',
    () async {
      // Acceptée, pas livrée : elle s'affiche sur l'accueil, avec les
      // coordonnées dont le livreur a besoin à ce moment-là. L'historique,
      // lui, ne parle que de courses finies.
      expect(await asCourier.fetchHistory(), isEmpty);
      expect((await asCourier.fetchStats()).deliveredCount, 0);
    },
  );
}
