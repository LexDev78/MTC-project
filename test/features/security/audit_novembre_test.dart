@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';

import '../../support/supabase_test_harness.dart';

// L'audit du 27/10/2026 et ce que sa correction a trouvé autour
// (`0136`–`0151`), mené comme l'audit : avec la seule clé publique de l'app,
// par l'API, ce que ferait n'importe qui l'ayant extraite d'un APK.
//
// Chaque cas essaie le chemin interdit, puis vérifie que le geste légitime
// passe toujours. Le détail de chaque règle, table par table, est dans les
// vérifications SQL (`supabase/snippets/verif_0136_0137.sql` et suivantes).
Future<SupabaseClient> _connecte(String identifiant) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(identifiant),
    password: 'password123',
  );
  addTearDown(client.dispose);
  return client;
}

/// Une inscription par l'API publique, avec ce que l'on veut — l'adresse
/// comprise, que l'app, elle, tire toujours de l'identifiant.
Future<void> _inscrire({
  required String email,
  required Map<String, dynamic> data,
}) async {
  final client = createTestSupabaseClient();
  addTearDown(client.dispose);
  await client.auth.signUp(
    email: email,
    password: 'password123',
    data: {'display_name': 'Essai', 'phone_number': '+22370009000', ...data},
  );
}

Future<String> _variante(String productId) async {
  final client = createTestSupabaseClient();
  addTearDown(client.dispose);
  final row = await client
      .from('product_variants')
      .select('id')
      .eq('product_id', productId)
      .order('id')
      .limit(1)
      .single();
  return row['id'] as String;
}

/// Une commande d'un boubou chez Bogolan, livrée par la boutique.
Future<({String commande, String groupe})> _commander(
  SupabaseClient client,
) async {
  final variante = await _variante(DemoIds.product002);
  final commande = await client.rpc(
    'place_order',
    params: {
      'p_client_display_name_snapshot': 'Service client MTC',
      'p_client_phone_snapshot': '+22370000002',
      'p_groups': [
        {
          'supplier_id': DemoIds.supplierBogolanBamako,
          'supplier_name': 'Nom inventé',
          'delivery_mode': 'self_delivery',
          'items': [
            {
              'product_id': DemoIds.product002,
              'variant_id': variante,
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
    },
  ) as String;
  final groupe = await client
      .from('order_supplier_groups')
      .select('id')
      .eq('order_id', commande)
      .single();
  return (commande: commande, groupe: groupe['id'] as String);
}

Future<void> _avancer(
  SupabaseClient boutique,
  ({String commande, String groupe}) cmd,
  List<String> statuts,
) async {
  for (final statut in statuts) {
    await boutique.rpc(
      'update_order_group_status',
      params: {
        'p_order_id': cmd.commande,
        'p_group_id': cmd.groupe,
        'p_status': statut,
      },
    );
  }
}

Map<String, dynamic> _produit(String id, String boutique, {String? nom}) => {
  'id': id,
  'supplier_id': boutique,
  'supplier_name': nom ?? 'MTC Officiel',
  'supplier_type': 'principal',
  'name': 'Panier tressé',
  'description': 'Un panier.',
  'category': 'artisanat',
  'price_fcfa': 1000,
  'stock_quantity': 5,
  'city': 'Sikasso',
  'weight_kg': 1,
  'status': 'draft',
  'is_supplier_verified': true,
  'rating_average': 5,
  'rating_count': 999,
  'view_count': 99999,
};

void main() {
  setUp(resetAndSeed);

  group('faille 1 — avis forgés', () {
    test('un client n\'écrit plus d\'avis sur la boutique de son choix', () async {
      final awa = await _connecte('client1');
      await expectLater(
        awa.from('reviews').insert({
          'id': 'forge-1',
          'order_id': DemoIds.orderAwaIntransit,
          'supplier_group_id': 'nimporte-quoi',
          'client_id': DemoIds.clientAwa,
          'supplier_id': DemoIds.supplierTissusMopti,
          'stars': 1,
          'comment': 'arnaque',
          'client_display_name_snapshot': 'Awa',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('faille 2 — un produit dit ce que la base sait', () {
    test('une boutique en attente ne se déclare ni vérifiée, ni MTC, ni notée', () async {
      final sikasso = await _connecte('fournisseur2');
      final cree = await sikasso
          .from('products')
          .insert(_produit('audit-produit-1', DemoIds.supplierArtisanatSikasso))
          .select()
          .single();
      expect(cree['is_supplier_verified'], isFalse);
      expect(cree['supplier_name'], 'Artisanat Sikasso');
      expect(cree['supplier_type'], 'tiers');
      expect(cree['rating_count'], 0);
      expect(cree['view_count'], 0);

      // Et le public ne le voit pas.
      final visiteur = createTestSupabaseClient();
      addTearDown(visiteur.dispose);
      expect(
        await visiteur.from('products').select('id').eq('id', 'audit-produit-1'),
        isEmpty,
      );
    });

    test('une boutique vérifiée crée un produit vérifié, noté comme elle', () async {
      final bogolan = await _connecte('fournisseur1');
      final cree = await bogolan
          .from('products')
          .insert(
            _produit('audit-produit-2', DemoIds.supplierBogolanBamako)
              ..['is_supplier_verified'] = false,
          )
          .select()
          .single();
      final boutique = await bogolan
          .from('supplier_storefronts')
          .select('rating_average, rating_count')
          .eq('id', DemoIds.supplierBogolanBamako)
          .single();
      expect(cree['is_supplier_verified'], isTrue);
      expect(cree['supplier_name'], 'Bogolan Bamako');
      expect(cree['rating_count'], boutique['rating_count']);
    });

    test('une photo de produit n\'est jamais une adresse (faille 8)', () async {
      final bogolan = await _connecte('fournisseur1');
      await expectLater(
        bogolan
            .from('products')
            .update({
              'image_urls': ['http://169.254.169.254/latest/meta-data/'],
            })
            .eq('id', DemoIds.product002),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('faille 3 — la remise d\'une commande livrée par la boutique se prouve', () {
    test('la boutique ne se déclare plus livrée seule ; le code du client clôt', () async {
      final moussa = await _connecte('client2');
      final bogolan = await _connecte('fournisseur1');
      final cmd = await _commander(moussa);
      await _avancer(bogolan, cmd, ['confirmed', 'preparing', 'in_transit']);

      await expectLater(
        _avancer(bogolan, cmd, ['delivered']),
        throwsA(isA<PostgrestException>()),
      );
      expect(await adminFetchGroupStatus(cmd.groupe), 'in_transit');

      // La boutique ne lit pas le code ; le client, si.
      await expectLater(
        bogolan.rpc('fetch_self_delivery_code', params: {'p_group_id': cmd.groupe}),
        throwsA(isA<PostgrestException>()),
      );
      final code = await moussa.rpc(
        'fetch_self_delivery_code',
        params: {'p_group_id': cmd.groupe},
      ) as String;

      await expectLater(
        bogolan.rpc(
          'confirm_self_delivery_by_code',
          params: {'p_group_id': cmd.groupe, 'p_code': '0' * 64},
        ),
        throwsA(isA<PostgrestException>()),
      );
      await bogolan.rpc(
        'confirm_self_delivery_by_code',
        params: {'p_group_id': cmd.groupe, 'p_code': code},
      );
      expect(await adminFetchGroupStatus(cmd.groupe), 'delivered');
    });

    test('le client confirme lui-même ; un autre client ne le peut pas', () async {
      final moussa = await _connecte('client2');
      final awa = await _connecte('client1');
      final bogolan = await _connecte('fournisseur1');
      final cmd = await _commander(moussa);
      await _avancer(bogolan, cmd, ['confirmed']);
      // Seulement acceptée, elle ne se confirme pas reçue : elle n'est pas
      // partie.
      await expectLater(
        moussa.rpc('confirm_self_delivery_received', params: {'p_group_id': cmd.groupe}),
        throwsA(isA<PostgrestException>()),
      );
      await _avancer(bogolan, cmd, ['preparing', 'in_transit']);

      await expectLater(
        awa.rpc('confirm_self_delivery_received', params: {'p_group_id': cmd.groupe}),
        throwsA(isA<PostgrestException>()),
      );
      await moussa.rpc(
        'confirm_self_delivery_received',
        params: {'p_group_id': cmd.groupe},
      );
      expect(await adminFetchGroupStatus(cmd.groupe), 'delivered');
    });

    test('un avis par boutique et par période, quel que soit le nombre de commandes', () async {
      // Awa : le jeu de démonstration ne lui donne aucun avis chez Bogolan
      // (Moussa, lui, y en a un d'il y a dix jours — et la règle le refuserait
      // dès le premier).
      final awa = await _connecte('client1');
      final bogolan = await _connecte('fournisseur1');
      final premiere = await _commander(awa);
      final seconde = await _commander(awa);
      for (final cmd in [premiere, seconde]) {
        await _avancer(bogolan, cmd, ['confirmed', 'preparing', 'in_transit']);
        await awa.rpc(
          'confirm_self_delivery_received',
          params: {'p_group_id': cmd.groupe},
        );
      }

      await awa.rpc(
        'submit_review',
        params: {
          'p_order_id': premiere.commande,
          'p_supplier_group_id': premiere.groupe,
          'p_stars': 5,
          'p_comment': 'Parfait.',
        },
      );
      await expectLater(
        awa.rpc(
          'submit_review',
          params: {
            'p_order_id': seconde.commande,
            'p_supplier_group_id': seconde.groupe,
            'p_stars': 5,
            'p_comment': 'Encore parfait.',
          },
        ),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            contains('déjà noté cette boutique'),
          ),
        ),
      );
    });
  });

  group('faille 4 — un commentaire dit qui l\'a écrit', () {
    test('« Service client MTC » sous un produit de Bogolan, adressé à Tissus Mopti', () async {
      final avant = await fetchNotificationsForUserAsAdmin(DemoIds.supplierTissusMopti);
      final awa = await _connecte('client1');
      await awa.from('product_comments').insert({
        'id': 'audit-comm-1',
        'product_id': DemoIds.product002,
        'supplier_id': DemoIds.supplierTissusMopti,
        'author_id': DemoIds.clientAwa,
        'author_name': 'Service client MTC',
        'is_supplier': true,
        'text': 'Votre boutique sera fermée : envoyez 5000 FCFA.',
      });

      final lu = await awa
          .from('product_comments_with_likes')
          .select()
          .eq('id', 'audit-comm-1')
          .single();
      expect(lu['author_name'], 'Awa Traoré');
      expect(lu['is_supplier'], isFalse);
      expect(lu['supplier_id'], DemoIds.supplierBogolanBamako);
      expect(lu['is_mine'], isTrue);
      // Plus d'identifiants dans la vue publique.
      expect(lu.containsKey('author_id'), isFalse);
      expect(lu.containsKey('liked_by_user_ids'), isFalse);

      final apres = await fetchNotificationsForUserAsAdmin(DemoIds.supplierTissusMopti);
      expect(apres.length, avant.length, reason: 'Tissus Mopti n\'a rien à recevoir');
    });
  });

  group('faille 5 — un dossier KYC soumis ne bouge plus', () {
    test('un dossier naît brouillon ; un dossier approuvé ne se modifie pas', () async {
      final kayes = await _connecte('fournisseur3');
      await kayes.from('supplier_kyc').insert({
        'id': 'audit-kyc-1',
        'supplier_id': DemoIds.supplierCoutureKayes,
        'legal_type': 'company',
        'status': 'approved',
      });
      final dossier = await kayes
          .from('supplier_kyc')
          .select('status')
          .eq('id', 'audit-kyc-1')
          .single();
      expect(dossier['status'], 'draft');

      final bogolan = await _connecte('fournisseur1');
      await expectLater(
        bogolan
            .from('supplier_kyc')
            .update({'rccm_number': 'FAUX'})
            .eq('supplier_id', DemoIds.supplierBogolanBamako),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('faille 6 — un collaborateur n\'a que ses cases', () {
    test('« messages » seul : ni commandes, ni options, ni versements', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'audit-messages',
        permissions: const {'messages'},
      );
      await insertNotificationAsAdmin(
        userId: DemoIds.supplierBogolanBamako,
        type: 'payout_decision',
        title: 'Retrait',
        body: '250 000 FCFA',
      );
      final vendeur = await _connecte('audit-messages');

      expect(await vendeur.from('orders').select('id'), isEmpty);
      expect(await vendeur.from('order_items').select('id'), isEmpty);
      final versements = await vendeur
          .from('notifications')
          .select('id')
          .eq('type', 'payout_decision');
      expect(versements, isEmpty);

      final touchees = await vendeur
          .from('product_characteristic_options')
          .update({'price_delta_fcfa': -40000})
          .neq('id', '')
          .select('id');
      expect(touchees, isEmpty);
    });
  });

  group('faille 7 — personne ne s\'inscrit sous l\'identité d\'un autre', () {
    test('« Client1 » à côté de « client1 », « MTC Officiel », « Service client MTC »', () async {
      await expectLater(
        _inscrire(email: 'client1x@mtc.local', data: {'username_or_phone': 'Client1'}),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        _inscrire(
          email: pseudoEmail('audit-boutique'),
          data: {
            'username_or_phone': 'audit-boutique',
            'role': 'supplier_tiers',
            'business_name': 'M.T.C Officiel',
            'city': 'Bamako',
            'legal_type': 'individual',
          },
        ),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        _inscrire(
          email: pseudoEmail('audit-pirate'),
          data: {'username_or_phone': 'audit-pirate', 'display_name': 'Service client MTC'},
        ),
        throwsA(isA<AuthException>()),
      );
      // L'inscription de l'app, elle, passe.
      await _inscrire(
        email: pseudoEmail('audit-normale'),
        data: {'username_or_phone': 'audit-normale', 'display_name': 'Mariam Diallo'},
      );
      expect(await _connecte('audit-normale'), isA<SupabaseClient>());
    });

    test('une boutique ne se renomme pas « MTC Officiel »', () async {
      final bogolan = await _connecte('fournisseur1');
      await expectLater(
        bogolan
            .from('suppliers')
            .update({'business_name': 'MTC Officiel'})
            .eq('id', DemoIds.supplierBogolanBamako),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('trouvé en corrigeant — chacun dans son rôle', () {
    test('un livreur ne commande pas', () async {
      final livreur = await _connecte('livreur1');
      await expectLater(_commander(livreur), throwsA(isA<PostgrestException>()));
    });

    test('un téléphone passe au compte qui s\'y connecte', () async {
      final awa = await _connecte('client1');
      await awa.rpc('register_device_token', params: {'p_token': 'audit-telephone'});
      final moussa = await _connecte('client2');
      await moussa.rpc('register_device_token', params: {'p_token': 'audit-telephone'});

      expect(await tokensForNotificationUserAsAdmin(DemoIds.clientAwa),
          isNot(contains('audit-telephone')));
      expect(await tokensForNotificationUserAsAdmin(DemoIds.clientMoussa),
          contains('audit-telephone'));
    });
  });
}
