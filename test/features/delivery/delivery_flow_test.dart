@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/features/delivery/data/datasources/supabase_delivery_datasource.dart';
import 'package:mtc_app/features/delivery/data/repositories/supabase_delivery_repository.dart';
import 'package:mtc_app/features/delivery/domain/entities/courier_delivery.dart';
import 'package:mtc_app/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:mtc_app/features/orders/data/datasources/supabase_order_datasource.dart';
import 'package:mtc_app/features/orders/data/repositories/supabase_order_repository.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/domain/repositories/order_repository.dart';

import '../../support/supabase_test_harness.dart';

// Parcours d'attribution d'une course (étape 1 de l'interface livreur,
// `0046_couriers_and_deliveries.sql`) : un groupe fournisseur livré par MTC
// qui part en livraison crée une course, proposée à un livreur à la fois.
//
// Chaque rôle a sa propre session : les policies de `deliveries` ne montrent
// une course qu'à celui à qui elle est proposée, donc « livreur1 la voit » et
// « livreur2 ne la voit pas » ne veulent dire quelque chose qu'avec deux
// clients distincts.
Future<SupabaseClient> _signIn(String usernameOrPhone) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(usernameOrPhone),
    password: 'password123',
  );
  return client;
}

void main() {
  // Le groupe « Electro Bamako » du jeu de démo, livré par MTC.
  const groupId = 'ca322249-2d39-5557-b97e-2e67eaeb4131';
  const courier1Id = 'f1c4e8a2-0000-5000-9000-000000000001';
  const courier2Id = 'f1c4e8a2-0000-5000-9000-000000000002';

  late SupabaseClient courier1Client;
  late DeliveryRepository asCourier1;

  setUp(() async {
    await resetAndSeed();
    courier1Client = await _signIn('livreur1');
    asCourier1 = SupabaseDeliveryRepository(
      SupabaseDeliveryDatasource(courier1Client),
    );
  });

  /// Remet le groupe en préparation puis le repasse en livraison **en tant
  /// que fournisseur** : c'est cette transition-là qui déclenche la création
  /// de la course, et le jeu de démo livre ce groupe déjà `in_transit`.
  Future<String> handOverToDelivery() async {
    await adminSetGroupStatus(groupId: groupId, status: 'preparing');

    final supplierClient = await _signIn('fournisseur5');
    final OrderRepository asSupplier = SupabaseOrderRepository(
      SupabaseOrderDatasource(supplierClient),
    );
    // L'id de commande se lit avec la session du fournisseur : ses policies
    // lui donnent accès à ses propres groupes, pas besoin d'un helper admin.
    final groupRow = await supplierClient
        .from('order_supplier_groups')
        .select('order_id')
        .eq('id', groupId)
        .single();
    final orderId = groupRow['order_id'] as String;
    await asSupplier.updateGroupStatus(
      orderId: orderId,
      groupId: groupId,
      status: OrderStatus.inTransit,
    );
    await supplierClient.dispose();
    return orderId;
  }

  test(
    'a supplier handing an MTC group over to delivery creates a course and '
    'offers it to an approved, online courier — and only to them',
    () async {
      await asCourier1.setOnline(
        courierId: courier1Id,
        isOnline: true,
        latitude: 12.6392,
        longitude: -8.0029,
      );

      await handOverToDelivery();

      final mine = await asCourier1.watchForCourier(courier1Id).first;
      expect(mine, hasLength(1));
      expect(mine.single.status, DeliveryStatus.offered);
      // Dès la proposition, le livreur voit d'où et vers où : sans ça, il ne
      // peut pas décider s'il prend. Le numéro du client, lui, attend qu'il
      // ait accepté (`0120`).
      expect(mine.single.supplierName, isNotEmpty);
      expect(mine.single.deliveryLatitude, isNotNull);
      expect(mine.single.deliveryLatitude, isNot(0));
      expect(mine.single.clientPhone, isNull);

      // livreur2 est `pending` : il ne reçoit rien, et ne voit rien.
      final courier2Client = await _signIn('livreur2');
      final asCourier2 = SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(courier2Client),
      );
      final theirs = await asCourier2.watchForCourier(courier2Id).first;
      expect(theirs, isEmpty);
      await courier2Client.dispose();

      await courier1Client.dispose();
    },
  );

  test('accepting a course takes it off the market', () async {
    await asCourier1.setOnline(
      courierId: courier1Id,
      isOnline: true,
      latitude: 12.6392,
      longitude: -8.0029,
    );
    await handOverToDelivery();

    final offered = await asCourier1.watchForCourier(courier1Id).first;
    await asCourier1.accept(offered.single.id);

    final after = await asCourier1.watchForCourier(courier1Id).first;
    expect(after.single.status, DeliveryStatus.accepted);
    // Acceptée : le numéro du client arrive.
    expect(after.single.clientPhone, isNotEmpty);

    // Même livreur, deuxième acceptation : la course n'est plus proposée,
    // donc le serveur refuse. C'est la garde qui empêche aussi un livreur de
    // rafler une course déjà prise par un autre.
    await expectLater(
      asCourier1.accept(offered.single.id),
      throwsA(isA<PostgrestException>()),
    );

    await courier1Client.dispose();
  });

  test(
    'a supplier with no pickup point cannot hand an order over to MTC '
    'delivery — the refusal names what to fix',
    () async {
      // Le fournisseur efface son adresse de retrait, puis tente la remise.
      await adminClearSupplierPickupPoint(
        supplierId: 'dbff9b88-4829-5eed-b15a-78c33431553f', // Electro Bamako
      );

      await expectLater(handOverToDelivery(), throwsA(isA<Exception>()));

      // Et aucune course fantôme n'a été créée au passage.
      await asCourier1.setOnline(
        courierId: courier1Id,
        isOnline: true,
        latitude: 12.6392,
        longitude: -8.0029,
      );
      await asCourier1.reofferExpired();
      expect(await asCourier1.watchForCourier(courier1Id).first, isEmpty);

      await courier1Client.dispose();
    },
  );

  // Cet écran n'était couvert par aucun test, et il échouait en production :
  // `couriers` référence `profiles` deux fois (le livreur, et l'agent qui a
  // statué), donc la requête imbriquée était ambiguë et PostgREST la
  // refusait entièrement. Le staff ne pouvait valider personne.
  test(
    'the staff queue lists pending couriers with their identity',
    () async {
      final staffClient = await _signIn('agent1');
      final asStaff = SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(staffClient),
      );

      final queue = await asStaff.fetchPendingCouriers();

      // `livreur2` est seedé en attente, `livreur1` déjà validé.
      expect(queue.map((c) => c.id), contains(courier2Id));
      expect(queue.map((c) => c.id), isNot(contains(courier1Id)));

      // Le nom et le téléphone viennent de la table jointe : s'ils sont
      // vides, c'est que la jointure est repartie sur la mauvaise clé.
      final pending = queue.firstWhere((c) => c.id == courier2Id);
      expect(pending.displayName, 'Fanta Cissé');
      expect(pending.phoneNumber, '+22378000002');
      expect(pending.city, 'Bamako');

      await staffClient.dispose();
      await courier1Client.dispose();
    },
  );

  // Le fournisseur gardait un bouton « Livrée » sur les commandes confiées à
  // MTC. Il ne constate pourtant pas l'arrivée du colis — et le paiement du
  // groupe dépend de ce statut, donc il a intérêt à le déclarer tôt. La
  // garde est côté base : retirer le bouton ne protège que de l'écran.
  test(
    'a supplier cannot close an MTC delivery — only the client\'s scan does',
    () async {
      await asCourier1.setOnline(
        courierId: courier1Id,
        isOnline: true,
        latitude: 12.6392,
        longitude: -8.0029,
      );
      final orderId = await handOverToDelivery();

      final supplierClient = await _signIn('fournisseur5');
      final OrderRepository asSupplier = SupabaseOrderRepository(
        SupabaseOrderDatasource(supplierClient),
      );

      await expectLater(
        asSupplier.updateGroupStatus(
          orderId: orderId,
          groupId: groupId,
          status: OrderStatus.delivered,
        ),
        throwsA(isA<Exception>()),
      );
      // Et la commande est restée ouverte, pas close à moitié.
      expect(await adminFetchGroupStatus(groupId), 'in_transit');

      await supplierClient.dispose();
      await courier1Client.dispose();
    },
  );

  // Troisième écran signalé comme inutilisable. La liste était cassée ; la
  // décision elle-même n'avait jamais été exécutée par un test.
  test(
    'a staff member approves a pending courier, who can then take courses',
    () async {
      final staffClient = await _signIn('agent1');
      final asStaff = SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(staffClient),
      );

      await asStaff.reviewCourier(courierId: courier2Id, approve: true);

      // Plus dans la file, et effectivement validé : un livreur approuvé
      // doit pouvoir se mettre en service et recevoir des propositions.
      expect(
        (await asStaff.fetchPendingCouriers()).map((c) => c.id),
        isNot(contains(courier2Id)),
      );
      expect(await adminFetchCourierStatus(courier2Id), 'approved');

      // Et un refus non motivé reste refusé par le serveur, quel que soit
      // l'écran qui le demande.
      await expectLater(
        asStaff.reviewCourier(courierId: courier2Id, approve: false),
        throwsA(isA<PostgrestException>()),
      );

      await staffClient.dispose();
      await courier1Client.dispose();
    },
  );

  test('a course nobody is available for stays unassigned, then finds its '
      'courier once one comes online', () async {
    // Personne en ligne au moment de la remise.
    await handOverToDelivery();

    var mine = await asCourier1.watchForCourier(courier1Id).first;
    expect(mine, isEmpty);

    // Le livreur prend son service : la relance (jouée à l'ouverture de sa
    // liste) lui propose la course restée sans destinataire.
    await asCourier1.setOnline(
      courierId: courier1Id,
      isOnline: true,
      latitude: 12.6392,
      longitude: -8.0029,
    );
    await asCourier1.reofferExpired();

    mine = await asCourier1.watchForCourier(courier1Id).first;
    expect(mine, hasLength(1));
    expect(mine.single.status, DeliveryStatus.offered);

    await courier1Client.dispose();
  });
}
