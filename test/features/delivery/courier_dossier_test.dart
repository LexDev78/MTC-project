@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/features/delivery/data/datasources/supabase_delivery_datasource.dart';
import 'package:mtc_app/features/delivery/data/repositories/supabase_delivery_repository.dart';
import 'package:mtc_app/features/delivery/domain/entities/courier_dossier.dart';
import 'package:mtc_app/features/delivery/domain/repositories/delivery_repository.dart';

import '../../support/supabase_test_harness.dart';

// Le dossier du livreur (`0105`).
//
// Un livreur n'était validé que sur son nom, son téléphone et sa ville. Il
// transporte pourtant la marchandise d'un fournisseur et, en paiement à la
// livraison, son argent. Son dossier prend donc la même forme que celui d'un
// fournisseur : des pièces dans un bucket privé, un dépôt qui gèle le
// dossier, une décision qui le tranche.
//
// Ce qui se vérifie ici : les pièces exigées dépendent du moyen de
// transport ; un dossier déposé ne se modifie plus ; personne d'autre que le
// livreur et le staff ne voit ses pièces ; et l'agent ne peut pas valider
// quelqu'un dont il n'a rien vu.
Future<SupabaseClient> _connecte(String identifiant) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(identifiant),
    password: 'password123',
  );
  addTearDown(client.dispose);
  return client;
}

DeliveryRepository _depot(SupabaseClient client) =>
    SupabaseDeliveryRepository(SupabaseDeliveryDatasource(client));

void main() {
  // Oumar Sidibé, validé. Fanta Cissé, en attente avec ses quatre pièces.
  const livreur1 = 'f1c4e8a2-0000-5000-9000-000000000001';
  const livreur2 = 'f1c4e8a2-0000-5000-9000-000000000002';

  setUp(resetAndSeed);

  group('les pièces exigées suivent le moyen de transport', () {
    test('la règle de l\'app dit exactement celle du serveur', () async {
      // `CourierVehicleType.requiredDocuments` double
      // `courier_required_documents()` : l'écran doit afficher les cases que
      // le serveur contrôlera. Deux copies d'une règle finissent toujours par
      // diverger — sauf si un test les compare. C'est celui-ci.
      final client = await _connecte('livreur2');

      for (final vehicule in CourierVehicleType.values) {
        final serveur = await client.rpc(
          'courier_required_documents',
          params: {'p_vehicle_type': vehicule.wireValue},
        );
        expect(
          (serveur as List).cast<String>(),
          vehicule.requiredDocuments.map((t) => t.wireValue).toList(),
          reason: 'désaccord app/serveur pour ${vehicule.label}',
        );
      }
    });

    test('hors voiture, l\'identité suffit', () {
      // Moto et tricycle (katakata) comprises : c'est l'essentiel de la
      // livraison à Bamako, et leur réclamer permis et carte grise leur
      // fermerait l'inscription (`0108`).
      for (final vehicule in [
        CourierVehicleType.onFoot,
        CourierVehicleType.bicycle,
        CourierVehicleType.motorcycle,
        CourierVehicleType.tricycle,
      ]) {
        expect(vehicule.requiredDocuments, [
          CourierDocumentType.nationalIdFront,
          CourierDocumentType.nationalIdBack,
        ]);
      }
    });

    test('en voiture, le permis et la carte grise s\'ajoutent', () {
      expect(
        CourierVehicleType.car.requiredDocuments,
        containsAll([
          CourierDocumentType.drivingLicence,
          CourierDocumentType.vehicleRegistration,
        ]),
      );
    });
  });

  group('déposer son dossier', () {
    /// Un livreur sans aucune pièce : on efface celles du semis pour partir
    /// d'un dossier vide, ce que fait un nouvel inscrit.
    Future<DeliveryRepository> livreurSansPieces() async {
      final client = await _connecte('livreur2');
      final depot = _depot(client);
      await adminResetCourierDossier(courierId: livreur2);
      return depot;
    }

    test('sans pièce, le dépôt est refusé et dit lesquelles manquent',
        () async {
      final depot = await livreurSansPieces();

      await expectLater(
        depot.submitDossier(vehicleType: CourierVehicleType.bicycle),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('national_id_front'),
          ),
        ),
      );
    });

    test('à vélo, les deux pièces d\'identité suffisent', () async {
      final depot = await livreurSansPieces();
      await depot.saveDocument(
        courierId: livreur2,
        type: CourierDocumentType.nationalIdFront,
        filePath: '$livreur2/recto.jpg',
      );
      await depot.saveDocument(
        courierId: livreur2,
        type: CourierDocumentType.nationalIdBack,
        filePath: '$livreur2/verso.jpg',
      );

      await depot.submitDossier(
        vehicleType: CourierVehicleType.bicycle,
        vehicleLabel: 'Vélo bleu',
      );

      final dossier = await depot.fetchMyDossier(livreur2);
      expect(dossier.isSubmitted, isTrue);
      expect(dossier.vehicleType, CourierVehicleType.bicycle);
      expect(dossier.vehicleLabel, 'Vélo bleu');
    });

    test('en voiture, les mêmes deux pièces ne suffisent plus', () async {
      final depot = await livreurSansPieces();
      await depot.saveDocument(
        courierId: livreur2,
        type: CourierDocumentType.nationalIdFront,
        filePath: '$livreur2/recto.jpg',
      );
      await depot.saveDocument(
        courierId: livreur2,
        type: CourierDocumentType.nationalIdBack,
        filePath: '$livreur2/verso.jpg',
      );

      await expectLater(
        depot.submitDossier(vehicleType: CourierVehicleType.car),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('driving_licence'),
              contains('vehicle_registration'),
            ),
          ),
        ),
      );
      // Et rien n'a été déposé à moitié : le dossier reste modifiable.
      expect((await depot.fetchMyDossier(livreur2)).isSubmitted, isFalse);
    });

    test('remplacer une pièce n\'en empile pas deux', () async {
      final depot = await livreurSansPieces();
      await depot.saveDocument(
        courierId: livreur2,
        type: CourierDocumentType.nationalIdFront,
        filePath: '$livreur2/premier.jpg',
      );
      await depot.saveDocument(
        courierId: livreur2,
        type: CourierDocumentType.nationalIdFront,
        filePath: '$livreur2/corrige.jpg',
      );

      final dossier = await depot.fetchMyDossier(livreur2);
      expect(dossier.documents, hasLength(1));
      expect(
        dossier.documentOf(CourierDocumentType.nationalIdFront)?.filePath,
        '$livreur2/corrige.jpg',
      );
    });

    test('un dossier déposé ne se modifie plus', () async {
      // Sinon l'agent validerait des pièces qui ont changé depuis qu'il les
      // a ouvertes.
      final depot = _depot(await _connecte('livreur2'));
      final avant = await depot.fetchMyDossier(livreur2);
      expect(avant.isSubmitted, isTrue, reason: 'le semis le dépose');

      await depot.saveDocument(
        courierId: livreur2,
        type: CourierDocumentType.insurance,
        filePath: '$livreur2/assurance.jpg',
      ).then((_) => null, onError: (_) => null);

      final apres = await depot.fetchMyDossier(livreur2);
      expect(
        apres.documentOf(CourierDocumentType.insurance),
        isNull,
        reason: 'aucune pièce ne s\'ajoute pendant l\'examen',
      );
      expect(apres.documents, hasLength(avant.documents.length));
    });

    test('un livreur déjà validé ne redépose pas', () async {
      final depot = _depot(await _connecte('livreur1'));
      await expectLater(
        depot.submitDossier(vehicleType: CourierVehicleType.motorcycle),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('la décision de l\'agent', () {
    test('la file ne liste que les dossiers déposés, avec leurs pièces',
        () async {
      final staff = _depot(await _connecte('agent1'));

      final file = await staff.fetchPendingCouriers();
      final fanta = file.firstWhere((c) => c.id == livreur2);
      expect(fanta.displayName, 'Fanta Cissé');
      expect(fanta.vehicleType, CourierVehicleType.tricycle);
      // Quatre pièces : le semis les dépose toutes, même si un
      // tricycle n'exige plus que l'identité.
      expect(fanta.documents, hasLength(4));
      expect(
        fanta.documents.map((d) => d.type),
        containsAll([
          CourierDocumentType.nationalIdFront,
          CourierDocumentType.nationalIdBack,
          CourierDocumentType.drivingLicence,
          CourierDocumentType.vehicleRegistration,
        ]),
      );

      // Un livreur qui n'a rien déposé n'y figure pas : il n'y a rien à
      // examiner, et l'agent ne pourrait pas le valider.
      await adminResetCourierDossier(courierId: livreur2);
      expect(
        (await staff.fetchPendingCouriers()).map((c) => c.id),
        isNot(contains(livreur2)),
      );
    });

    test('on ne valide pas un livreur dont on n\'a rien vu', () async {
      await adminResetCourierDossier(courierId: livreur2);
      final staff = _depot(await _connecte('agent1'));

      await expectLater(
        staff.reviewCourier(courierId: livreur2, approve: true),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('pas encore déposé'),
          ),
        ),
      );
      expect(await adminFetchCourierStatus(livreur2), 'pending');
    });

    test('un refus rend la main au livreur, qui peut redéposer', () async {
      final staff = _depot(await _connecte('agent1'));
      await staff.reviewCourier(
        courierId: livreur2,
        approve: false,
        reason: 'Carte grise illisible',
      );

      final depot = _depot(await _connecte('livreur2'));
      final refuse = await depot.fetchMyDossier(livreur2);
      expect(refuse.isSubmitted, isFalse, reason: 'le dépôt est rendu');
      expect(refuse.rejectionReason, 'Carte grise illisible');

      // Il corrige la pièce en cause et redépose.
      await depot.saveDocument(
        courierId: livreur2,
        type: CourierDocumentType.vehicleRegistration,
        filePath: '$livreur2/carte-grise-nette.jpg',
      );
      await depot.submitDossier(vehicleType: CourierVehicleType.tricycle);

      final redepose = await depot.fetchMyDossier(livreur2);
      expect(redepose.isSubmitted, isTrue);
      // Et le motif du refus précédent ne s'affiche plus comme s'il était
      // toujours d'actualité.
      expect(redepose.rejectionReason, isNull);
      expect(await adminFetchCourierStatus(livreur2), 'pending');
    });

    test('une validation ouvre les courses', () async {
      final staff = _depot(await _connecte('agent1'));
      await staff.reviewCourier(courierId: livreur2, approve: true);
      expect(await adminFetchCourierStatus(livreur2), 'approved');
    });
  });

  group('les pièces ne regardent que le livreur et MTC', () {
    test('un autre livreur n\'en voit aucune', () async {
      final autre = _depot(await _connecte('livreur1'));
      final dossier = await autre.fetchMyDossier(livreur1);
      expect(dossier.documents, isEmpty);

      // Et la lecture directe de la table ne lui en montre pas davantage.
      final client = await _connecte('livreur1');
      final lignes = await client.from('courier_documents').select('id');
      expect(lignes, isEmpty);
    });

    test('ni un client, ni un fournisseur', () async {
      for (final identifiant in ['client1', 'fournisseur1']) {
        final client = await _connecte(identifiant);
        final lignes = await client.from('courier_documents').select('id');
        expect(
          lignes,
          isEmpty,
          reason: '$identifiant ne doit voir aucune pièce de livreur',
        );
      }
    });

    test('l\'agent MTC les voit, c\'est son métier', () async {
      final client = await _connecte('agent1');
      final lignes = await client.from('courier_documents').select('id');
      expect((lignes as List), hasLength(4));
    });

    test('le livreur ne décide pas de son propre statut', () async {
      final client = await _connecte('livreur2');
      try {
        await client
            .from('couriers')
            .update({'status': 'approved'})
            .eq('id', livreur2);
      } on PostgrestException {
        // Refusé d'emblée : le droit de colonne ne lui est pas accordé.
      }
      expect(await adminFetchCourierStatus(livreur2), 'pending');
    });
  });
}
