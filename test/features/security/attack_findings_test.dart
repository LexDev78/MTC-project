@Tags(['integration'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/utils/id_generator.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/delivery/data/datasources/supabase_delivery_datasource.dart';
import 'package:mtc_app/features/delivery/data/repositories/supabase_delivery_repository.dart';
import 'package:mtc_app/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:mtc_app/features/orders/data/datasources/supabase_order_datasource.dart';
import 'package:mtc_app/features/orders/data/repositories/supabase_order_repository.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/domain/repositories/order_repository.dart';

import '../../support/supabase_test_harness.dart';

// Ce que l'attaque du système a trouvé, et qui ne doit pas revenir (`0106`).
//
// Cinq failles, mesurées en se présentant comme l'utilisateur concerné :
// l'acheteur déclarait lui-même son paiement ; un collaborateur sans aucune
// permission écrivait dans le stockage de la boutique ; on pouvait déposer au
// dossier la pièce d'identité d'un autre ; et un livreur suspendu acceptait
// la course qu'on lui avait proposée.
//
// Chaque cas vérifie les deux côtés : l'attaque est refusée, **et** le geste
// légitime passe toujours. Une garde qui ferme aussi la porte au
// propriétaire n'est pas une garde, c'est une panne.
Future<SupabaseClient> _connecte(String identifiant) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(identifiant),
    password: 'password123',
  );
  addTearDown(client.dispose);
  return client;
}

/// Une image minuscule mais réelle : l'API de stockage refuse un corps vide.
final _image = Uint8List.fromList(List<int>.filled(64, 0x42));

/// Un chemin neuf à chaque exécution.
///
/// `resetAndSeed` ne vide pas le stockage — Supabase interdit la suppression
/// directe dans `storage.objects` depuis SQL (`0088`), d'où la file de purge.
/// Un chemin fixe ferait donc échouer la deuxième exécution sur un 409
/// « Duplicate », qui ressemble à un refus de politique sans en être un.
String _chemin(String dossier, String nom) =>
    '$dossier/${IdGenerator.next()}-$nom';

void main() {
  const bogolan = DemoIds.supplierBogolanBamako;
  const riz = 'd9d25e13-71ac-51c4-93f7-ed042a996500'; // Riz local 25kg
  const alimentationSegou = '2c66294c-e1d7-59f1-925c-5ab6703827f3';
  const livreur1 = 'f1c4e8a2-0000-5000-9000-000000000001';
  const livreur2 = 'f1c4e8a2-0000-5000-9000-000000000002';
  const groupeMtc = 'ca322249-2d39-5557-b97e-2e67eaeb4131'; // Electro Bamako

  setUp(resetAndSeed);

  group("l'acheteur ne décide pas de son propre paiement", () {
    /// Commande par le chemin de l'app, en tentant de se déclarer payé.
    Future<String> commande(SupabaseClient client) async {
      final id = await client.rpc(
        'place_order',
        params: {
          'p_client_display_name_snapshot': 'Awa Traoré',
          'p_client_phone_snapshot': '+22370000001',
          'p_groups': [
            {
              'supplier_id': alimentationSegou,
              'supplier_name': 'Alimentation Ségou',
              'delivery_mode': 'self_delivery',
              'items': [
                {
                  'product_id': riz,
                  'variant_id': null,
                  'product_name_snapshot': 'Riz local 25kg',
                  'variant_name_snapshot': null,
                  'quantity': 1,
                },
              ],
            },
          ],
          'p_delivery_address_label': 'Domicile',
          'p_delivery_city': 'Bamako',
          'p_delivery_details': 'Badalabougou',
          'p_delivery_latitude': 12.63,
          'p_delivery_longitude': -8.0,
          'p_payment_method': 'now',
          // L'attaque tient dans ces deux mots.
          'p_payment_status': 'paid',
          'p_mobile_money_provider': 'orange_money',
        },
      );
      return id as String;
    }

    test('se déclarer payé ne paie rien', () async {
      // Avant `0106`, cet appel créait une commande marquée `paid` sans
      // qu'un franc ne bouge, et le fournisseur lisait « Payé via Orange
      // Money » avant d'expédier.
      final client = await _connecte('client1');
      final orderId = await commande(client);

      final order = await client
          .from('orders')
          .select('payment_status, payment_method, total_fcfa')
          .eq('id', orderId)
          .single();
      expect(order['payment_status'], 'pending_on_delivery');
      // La méthode demandée est conservée — c'est l'intention du client, et
      // elle ne coûte rien. Seul l'encaissement n'est pas présumé.
      expect(order['payment_method'], 'now');
      expect((order['total_fcfa'] as num).toInt(), greaterThan(0));
    });

    test('et il ne peut pas davantage le déclarer après coup', () async {
      final client = await _connecte('client1');
      final orderId = await commande(client);

      await expectLater(
        client.rpc('mark_order_paid', params: {'p_order_id': orderId}),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('staff'),
          ),
        ),
      );
      // Ni par une écriture directe sur la colonne.
      try {
        await client
            .from('orders')
            .update({'payment_status': 'paid'})
            .eq('id', orderId);
      } on PostgrestException {
        // Refusé d'emblée : très bien.
      }
      final apres = await client
          .from('orders')
          .select('payment_status')
          .eq('id', orderId)
          .single();
      expect(apres['payment_status'], 'pending_on_delivery');
    });

    test('le staff, lui, constate un paiement reçu', () async {
      // Le chemin légitime doit exister : sans lui, aucun paiement mobile
      // ne pourrait jamais être enregistré.
      final client = await _connecte('client1');
      final orderId = await commande(client);

      final agent = await _connecte('agent1');
      await agent.rpc('mark_order_paid', params: {'p_order_id': orderId});

      final apres = await client
          .from('orders')
          .select('payment_status')
          .eq('id', orderId)
          .single();
      expect(apres['payment_status'], 'paid');

      // Et le client en est prévenu.
      final notifications = await fetchNotificationsForUserAsAdmin(
        '04060d99-e34d-520e-8b75-631ff4d3c10c',
      );
      expect(
        notifications.map((n) => n['title']),
        contains('Paiement confirmé'),
      );
    });

  });

  group('le stockage de la boutique suit les permissions', () {
    test('sans permission, un collaborateur n\'y dépose rien', () async {
      // Les tables étaient gardées depuis `0094`/`0097`, le stockage ne
      // l'était pas — or une photo de catalogue est du contenu de boutique
      // autant qu'une ligne de table.
      await createCollaboratorAsAdmin(
        supplierId: bogolan,
        username: 'sans_droit',
        permissions: const {},
      );
      final collaborateur = await _connecte('sans_droit');

      await expectLater(
        collaborateur.storage
            .from('product-images')
            .uploadBinary(_chemin(bogolan, 'intrus.jpg'), _image),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        collaborateur.storage
            .from('product-videos')
            .uploadBinary(_chemin(bogolan, 'intrus.mp4'), _image),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        collaborateur.storage
            .from('supplier-branding')
            .uploadBinary(_chemin(bogolan, 'banniere.jpg'), _image),
        throwsA(isA<StorageException>()),
      );
    });

    test('avec la permission produits, il dépose une photo', () async {
      await createCollaboratorAsAdmin(
        supplierId: bogolan,
        username: 'vendeur_photo',
        permissions: const {'products'},
      );
      final collaborateur = await _connecte('vendeur_photo');

      await collaborateur.storage
          .from('product-images')
          .uploadBinary(_chemin(bogolan, 'legitime.jpg'), _image);

      // Mais la bannière relève de la vitrine, pas des produits.
      await expectLater(
        collaborateur.storage
            .from('supplier-branding')
            .uploadBinary(_chemin(bogolan, 'banniere.jpg'), _image),
        throwsA(isA<StorageException>()),
      );
    });

    test('et le patron fait les deux', () async {
      final patron = await _connecte('fournisseur1');
      await patron.storage
          .from('product-images')
          .uploadBinary(_chemin(bogolan, 'patron.jpg'), _image);
      await patron.storage
          .from('supplier-branding')
          .uploadBinary(_chemin(bogolan, 'banniere.jpg'), _image);
    });
  });

  group('une pièce ne se dépose que dans son propre dossier', () {
    test('un livreur ne peut pas présenter la pièce d\'un autre', () async {
      // Sans cette garde, un dossier refusé pour pièce illisible pouvait
      // être redéposé avec les papiers valides d'un collègue : l'agent lit
      // le bucket avec ses droits de staff, il voyait donc la pièce de
      // l'autre présentée comme celle du demandeur.
      await adminResetCourierDossier(courierId: livreur2);
      final livreuse = await _connecte('livreur2');

      await expectLater(
        livreuse.from('courier_documents').insert({
          'id': 'usurpation',
          'courier_id': livreur2,
          'type': 'national_id_front',
          'file_path': '$livreur1/nina-de-oumar.jpg',
        }),
        throwsA(isA<PostgrestException>()),
      );

      // La sienne, rangée chez elle, passe.
      await livreuse.from('courier_documents').insert({
        'id': 'la-mienne',
        'courier_id': livreur2,
        'type': 'national_id_front',
        'file_path': '$livreur2/ma-nina.jpg',
      });
    });

    test('un fournisseur non plus', () async {
      final voisin = await _connecte('fournisseur4');
      final dossier = await voisin
          .from('supplier_kyc')
          .select('id, supplier_id')
          .maybeSingle();
      if (dossier == null) {
        markTestSkipped('fournisseur4 n\'a pas de dossier dans le jeu de données');
        return;
      }

      await expectLater(
        voisin.from('supplier_documents').insert({
          'id': 'usurpation-fournisseur',
          'kyc_id': dossier['id'],
          'type': 'national_id_front',
          'file_path': '$bogolan/piece-de-bogolan.jpg',
        }),
        throwsA(isA<PostgrestException>()),
      );

      await voisin.from('supplier_documents').insert({
        'id': 'la-mienne-fournisseur',
        'kyc_id': dossier['id'],
        'type': 'national_id_front',
        'file_path': '${dossier['supplier_id']}/ma-piece.jpg',
      });
    });
  });

  group('un livreur hors d\'état n\'emporte pas de colis', () {
    /// Confie le groupe « Electro Bamako » à la livraison MTC, ce qui crée la
    /// course et la propose au livreur en ligne le plus proche.
    Future<void> confierALaLivraison() async {
      await adminSetGroupStatus(groupId: groupeMtc, status: 'preparing');
      final fournisseur = await _connecte('fournisseur5');
      final OrderRepository asSupplier = SupabaseOrderRepository(
        SupabaseOrderDatasource(fournisseur),
      );
      final groupe = await fournisseur
          .from('order_supplier_groups')
          .select('order_id')
          .eq('id', groupeMtc)
          .single();
      await asSupplier.updateGroupStatus(
        orderId: groupe['order_id'] as String,
        groupId: groupeMtc,
        status: OrderStatus.inTransit,
      );
    }

    test('refusé entre la proposition et l\'acceptation, il n\'accepte plus',
        () async {
      final client = await _connecte('livreur1');
      final DeliveryRepository asCourier = SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(client),
      );
      await asCourier.setOnline(
        courierId: livreur1,
        isOnline: true,
        latitude: 12.6392,
        longitude: -8.0029,
      );
      await confierALaLivraison();

      final proposees = await asCourier.watchForCourier(livreur1).first;
      expect(proposees, hasLength(1), reason: 'la course doit lui être proposée');
      final courseId = proposees.single.id;

      // MTC le écarte — c'est précisément à ce moment qu'une suspension
      // tombe : à cause de ce qu'il vient de faire.
      final agent = await _connecte('agent1');
      final DeliveryRepository asStaff = SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(agent),
      );
      await asStaff.reviewCourier(
        courierId: livreur1,
        approve: false,
        reason: 'Colis manquant signalé',
      );

      await expectLater(
        asCourier.accept(courseId),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('n\'est pas en règle'),
          ),
        ),
      );
      expect(await adminFetchCourierStatus(livreur1), 'rejected');
    });

    test('en règle, il accepte normalement', () async {
      final client = await _connecte('livreur1');
      final DeliveryRepository asCourier = SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(client),
      );
      await asCourier.setOnline(
        courierId: livreur1,
        isOnline: true,
        latitude: 12.6392,
        longitude: -8.0029,
      );
      await confierALaLivraison();

      final proposees = await asCourier.watchForCourier(livreur1).first;
      await asCourier.accept(proposees.single.id);

      final apres = await asCourier.watchForCourier(livreur1).first;
      expect(apres.single.status.name, 'accepted');
    });
  });

  group("les points que l'audit avait laissés ouverts", () {
    test('le compteur de vues ne compte qu\'une fois par personne et par jour',
        () async {
      // Mesuré avant `0107` : vingt-cinq appels, vingt-cinq vues, sur
      // n'importe quel produit. Le tableau de bord affiche « visionnage des
      // produits » : la statistique était déclarative, et un concurrent
      // pouvait gonfler le chiffre d'un voisin aussi bien que le sien.
      final client = await _connecte('client1');
      final anon = createTestSupabaseClient();
      addTearDown(anon.dispose);

      Future<int> vues() async {
        final row = await anon
            .from('products')
            .select('view_count')
            .eq('id', riz)
            .single();
        return (row['view_count'] as num).toInt();
      }

      final avant = await vues();
      for (var i = 0; i < 25; i++) {
        await client.rpc('increment_product_view', params: {'p_product_id': riz});
      }
      expect(
        await vues() - avant,
        1,
        reason: 'vingt-cinq ouvertures d\'une même fiche par la même personne '
            'ne font pas vingt-cinq visiteurs',
      );

      // Mais deux personnes comptent bien pour deux : la garde ne doit pas
      // transformer le compteur en plafond.
      final autre = await _connecte('client2');
      await autre.rpc('increment_product_view', params: {'p_product_id': riz});
      expect(await vues() - avant, 2);
    });

    test('l\'identifiant d\'un client ne se lit plus depuis un numéro de '
        'commande', () async {
      final client = await _connecte('client1');
      final mienne = await client
          .from('orders')
          .select('id')
          .limit(1)
          .maybeSingle();
      if (mienne == null) {
        markTestSkipped('aucune commande dans le jeu de données');
        return;
      }
      final orderId = mienne['id'] as String;

      // La fonction qui rendait l'uuid du client est fermée…
      await expectLater(
        client.rpc('order_client_id', params: {'p_order_id': orderId}),
        throwsA(isA<PostgrestException>()),
      );
      // …et celle qui l'a remplacée ne dit que oui ou non, sur soi.
      expect(
        await client.rpc('order_belongs_to_me', params: {'p_order_id': orderId}),
        isTrue,
      );
      final fournisseur = await _connecte('fournisseur5');
      expect(
        await fournisseur.rpc(
          'order_belongs_to_me',
          params: {'p_order_id': orderId},
        ),
        isFalse,
      );

      // Et les écrans voient toujours ce qu'ils doivent : c'est la même
      // fonction qui porte les politiques des commandes.
      final lignes = await client.from('order_items').select('id');
      expect(lignes, isNotEmpty);
      final groupes = await fournisseur
          .from('order_supplier_groups')
          .select('id');
      expect(groupes, isNotEmpty);
    });

    test('le concierge des courses n\'est plus à la portée de tout le monde',
        () async {
      final client = await _connecte('client1');
      await expectLater(
        client.rpc('reoffer_expired_deliveries'),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('livreurs'),
          ),
        ),
      );

      // Le livreur, lui, en a besoin : c'est son écran qui le déclenche.
      final livreur = await _connecte('livreur1');
      expect(await livreur.rpc('reoffer_expired_deliveries'), isA<int>());
    });

    test('le modèle d\'empreintes en service n\'est pas public', () async {
      // Ses deux appelantes sont `security definer` : elles continuent de le
      // lire, et la recherche par photo passe par le rôle de service.
      final client = await _connecte('client1');
      await expectLater(
        client.rpc('serving_embedding_model'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
