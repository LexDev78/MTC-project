@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/features/delivery/data/datasources/supabase_delivery_datasource.dart';
import 'package:mtc_app/features/delivery/data/repositories/supabase_delivery_repository.dart';
import 'package:mtc_app/features/delivery/domain/entities/courier_delivery.dart';
import 'package:mtc_app/features/delivery/domain/repositories/delivery_repository.dart';

import '../../support/supabase_test_harness.dart';

// Les deux QR à usage unique (`0051_delivery_codes.sql`). Ce qu'ils prouvent,
// c'est que le livreur était sur place : chaque test ci-dessous vérifie une
// des conditions sans lesquelles cette preuve ne vaut plus rien.
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
  const courier1Id = 'f1c4e8a2-0000-5000-9000-000000000001';

  late SupabaseClient courierClient;
  late DeliveryRepository asCourier;
  late String deliveryId;

  /// Décor commun : une course acceptée par livreur1, prête à être retirée.
  setUp(() async {
    await resetAndSeed();

    courierClient = await _signIn('livreur1');
    asCourier = SupabaseDeliveryRepository(
      SupabaseDeliveryDatasource(courierClient),
    );
    await asCourier.setOnline(
      courierId: courier1Id,
      isOnline: true,
      latitude: 12.6392,
      longitude: -8.0029,
    );

    await adminSetGroupStatus(groupId: groupId, status: 'preparing');
    await adminSetGroupStatus(groupId: groupId, status: 'in_transit');

    final offered = await asCourier.watchForCourier(courier1Id).first;
    deliveryId = offered.single.id;
    await asCourier.accept(deliveryId);
  });

  tearDown(() async {
    await courierClient.dispose();
  });

  test('le livreur ne peut pas lire les codes qu\'il doit scanner', () async {
    // Le cœur du dispositif : s'il pouvait les lire, il lui suffirait de les
    // renvoyer sans se déplacer, et le scan ne prouverait plus rien.
    expect(
      await asCourier.fetchCode(
        deliveryId: deliveryId,
        kind: DeliveryCodeKind.pickup,
      ),
      isNull,
    );
    expect(
      await asCourier.fetchCode(
        deliveryId: deliveryId,
        kind: DeliveryCodeKind.delivery,
      ),
      isNull,
    );
  });

  test('le fournisseur voit le code de retrait, le client celui de remise — '
      'et aucun ne voit celui de l\'autre', () async {
    final supplierClient = await _signIn('fournisseur5');
    final asSupplier = SupabaseDeliveryRepository(
      SupabaseDeliveryDatasource(supplierClient),
    );
    expect(
      await asSupplier.fetchCode(
        deliveryId: deliveryId,
        kind: DeliveryCodeKind.pickup,
      ),
      isNotNull,
    );
    expect(
      await asSupplier.fetchCode(
        deliveryId: deliveryId,
        kind: DeliveryCodeKind.delivery,
      ),
      isNull,
    );
    await supplierClient.dispose();

    final clientClient = await _signIn('client1');
    final asClient = SupabaseDeliveryRepository(
      SupabaseDeliveryDatasource(clientClient),
    );
    expect(
      await asClient.fetchCode(
        deliveryId: deliveryId,
        kind: DeliveryCodeKind.delivery,
      ),
      isNotNull,
    );
    expect(
      await asClient.fetchCode(
        deliveryId: deliveryId,
        kind: DeliveryCodeKind.pickup,
      ),
      isNull,
    );
    await clientClient.dispose();
  });

  test('scanner le retrait puis la remise fait avancer la course, et clôt le '
      'groupe de commande', () async {
    final supplierClient = await _signIn('fournisseur5');
    final pickupCode = await SupabaseDeliveryRepository(
      SupabaseDeliveryDatasource(supplierClient),
    ).fetchCode(deliveryId: deliveryId, kind: DeliveryCodeKind.pickup);
    await supplierClient.dispose();

    expect(
      await asCourier.scan(deliveryId: deliveryId, code: pickupCode!),
      DeliveryStatus.pickedUp,
    );

    final clientClient = await _signIn('client1');
    final deliveryCode = await SupabaseDeliveryRepository(
      SupabaseDeliveryDatasource(clientClient),
    ).fetchCode(deliveryId: deliveryId, kind: DeliveryCodeKind.delivery);
    await clientClient.dispose();

    expect(
      await asCourier.scan(deliveryId: deliveryId, code: deliveryCode!),
      DeliveryStatus.delivered,
    );

    // La remise accusée clôt la commande : personne n'a à le redire ailleurs.
    expect(await adminFetchGroupStatus(groupId), 'delivered');
  });

  test('un code ne sert qu\'une fois', () async {
    final supplierClient = await _signIn('fournisseur5');
    final pickupCode = await SupabaseDeliveryRepository(
      SupabaseDeliveryDatasource(supplierClient),
    ).fetchCode(deliveryId: deliveryId, kind: DeliveryCodeKind.pickup);
    await supplierClient.dispose();

    await asCourier.scan(deliveryId: deliveryId, code: pickupCode!);
    await expectLater(
      asCourier.scan(deliveryId: deliveryId, code: pickupCode),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('on ne peut pas accuser la remise avant le retrait', () async {
    final clientClient = await _signIn('client1');
    final deliveryCode = await SupabaseDeliveryRepository(
      SupabaseDeliveryDatasource(clientClient),
    ).fetchCode(deliveryId: deliveryId, kind: DeliveryCodeKind.delivery);
    await clientClient.dispose();

    // La course est `accepted` : le serveur n'attend que le code de retrait,
    // et celui de la remise — pourtant valide — est refusé.
    await expectLater(
      asCourier.scan(deliveryId: deliveryId, code: deliveryCode!),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'la position du livreur est visible du client pendant la course, et '
    'effacée dès la remise accusée',
    () async {
      await asCourier.pushPosition(latitude: 12.6500, longitude: -8.0100);

      // Le client la voit : c'est sa commande, et la course est en cours.
      final clientClient = await _signIn('client1');
      Future<Map<String, dynamic>?> readDelivery() => clientClient
          .from('deliveries')
          .select('courier_latitude, courier_longitude, status')
          .eq('id', deliveryId)
          .maybeSingle();

      final during = await readDelivery();
      expect(during!['courier_latitude'], closeTo(12.65, 0.0001));

      // Un client qui n'a rien à voir avec cette commande n'y a pas accès.
      final otherClient = await _signIn('client2');
      expect(
        await otherClient
            .from('deliveries')
            .select('id')
            .eq('id', deliveryId)
            .maybeSingle(),
        isNull,
      );
      await otherClient.dispose();

      // Les deux scans, puis vérification de l'oubli.
      final supplierClient = await _signIn('fournisseur5');
      final pickupCode = await SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(supplierClient),
      ).fetchCode(deliveryId: deliveryId, kind: DeliveryCodeKind.pickup);
      await supplierClient.dispose();
      await asCourier.scan(deliveryId: deliveryId, code: pickupCode!);

      final deliveryCode = await SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(clientClient),
      ).fetchCode(deliveryId: deliveryId, kind: DeliveryCodeKind.delivery);
      await asCourier.scan(deliveryId: deliveryId, code: deliveryCode!);

      // Sans cet oubli, la dernière position connue — le domicile du client —
      // resterait lisible sur une course terminée.
      final after = await readDelivery();
      expect(after!['courier_latitude'], isNull);
      expect(after['courier_longitude'], isNull);

      await clientClient.dispose();
    },
  );

  test('un code inventé est refusé', () async {
    await expectLater(
      asCourier.scan(deliveryId: deliveryId, code: 'a' * 64),
      throwsA(isA<PostgrestException>()),
    );
  });
}
