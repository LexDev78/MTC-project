@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';

import '../../support/supabase_test_harness.dart';

// L'audit d'avant lancement (25/10/2026), et ce qui ne doit pas revenir.
//
// Chaque attaque y a été menée avec la seule clé publique de l'app, comme
// le ferait n'importe qui l'ayant extraite d'un APK :
//
//   * `0128` — l'inscription publique faisait un administrateur MTC, ou un
//     collaborateur de la boutique de son choix ;
//   * `0129` — « un boubou + −3 sacs » faisait une commande à 0 FCFA et
//     remontait le stock ; un groupe d'une boutique portait les produits
//     d'une autre ;
//   * `0131` — une vente livrée et encaissée par la boutique elle-même
//     ouvrait un versement que MTC payait de sa caisse ; une demande de
//     retrait pouvait naître « payée ».
//
// Comme ailleurs, chaque cas vérifie aussi que le geste légitime passe.
Future<SupabaseClient> _connecte(
  String identifiant, {
  String? motDePasse,
}) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(identifiant),
    password: motDePasse ?? 'password123',
  );
  addTearDown(client.dispose);
  return client;
}

/// Une inscription par l'API publique, avec ce que l'on veut dans `data` —
/// exactement ce que fait l'attaquant.
Future<void> _inscrire(String identifiant, Map<String, dynamic> data) async {
  final client = createTestSupabaseClient();
  addTearDown(client.dispose);
  await client.auth.signUp(
    email: pseudoEmail(identifiant),
    password: 'password123',
    data: {
      'username_or_phone': identifiant,
      'display_name': 'Essai',
      'phone_number': '+22370009000',
      ...data,
    },
  );
}

/// Le compte n'existe pas : la connexion échoue.
Future<void> _nExistePas(String identifiant) async {
  await expectLater(
    _connecte(identifiant),
    throwsA(isA<AuthException>()),
    reason: '« $identifiant » ne doit pas avoir été créé',
  );
}

/// La variante unique d'un produit du décor. Les identifiants de variantes
/// sont tirés au semis : ils ne s'écrivent pas en dur.
Future<({String id, int stock})> _variante(String productId) async {
  final client = createTestSupabaseClient();
  addTearDown(client.dispose);
  final row = await client
      .from('product_variants')
      .select('id, stock_quantity')
      .eq('product_id', productId)
      .single();
  return (
    id: row['id'] as String,
    stock: (row['stock_quantity'] as num).toInt(),
  );
}

Future<String> _commander(
  SupabaseClient client, {
  required String boutique,
  required List<Map<String, dynamic>> lignes,
  String mode = 'self_delivery',
}) async {
  final id = await client.rpc(
    'place_order',
    params: {
      'p_client_display_name_snapshot': 'Moussa Diarra',
      'p_client_phone_snapshot': '+22370000002',
      'p_groups': [
        {
          'supplier_id': boutique,
          'supplier_name': 'Nom inventé',
          'delivery_mode': mode,
          'items': lignes,
        },
      ],
      'p_delivery_address_label': 'Domicile',
      'p_delivery_city': 'Bamako',
      'p_delivery_details': 'Badalabougou',
      'p_delivery_latitude': 12.63,
      'p_delivery_longitude': -8.0,
    },
  );
  return id as String;
}

Future<Map<String, dynamic>> _grandLivre(SupabaseClient patron) async =>
    Map<String, dynamic>.from(
      await patron.rpc('fetch_my_finance_summary') as Map,
    );

void main() {
  const bogolan = DemoIds.supplierBogolanBamako;
  const boubou = DemoIds.product002; // 45 000 FCFA
  const sac = DemoIds.product003; // 15 000 FCFA

  setUp(resetAndSeed);

  group('personne ne se fait staff ni vendeur en s\'inscrivant', () {
    test(
      "l'inscription publique en administrateur échoue, sans rien laisser",
      () async {
        await expectLater(
          _inscrire('pirate-admin', {
            'role': 'supplier_principal',
            'staff_role': 'admin',
          }),
          throwsA(isA<AuthException>()),
        );
        await _nExistePas('pirate-admin');

        // Même déguisé en client, `staff_role` ne passe pas.
        await expectLater(
          _inscrire('pirate-admin2', {'role': 'client', 'staff_role': 'admin'}),
          throwsA(isA<AuthException>()),
        );
        await _nExistePas('pirate-admin2');
      },
    );

    test("l'inscription publique dans la boutique d'un autre échoue", () async {
      await expectLater(
        _inscrire('pirate-vendeur', {
          'role': 'supplier_tiers',
          'collaborator_of': bogolan,
          'permissions': ['products', 'orders', 'storefront', 'messages'],
          'business_name': 'Boutique écran',
          'city': 'Bamako',
          'legal_type': 'company',
        }),
        throwsA(isA<AuthException>()),
      );
      await _nExistePas('pirate-vendeur');

      final patron = await _connecte('fournisseur1');
      final equipe = await patron.rpc('fetch_my_collaborators') as List;
      expect(
        equipe.map((c) => (c as Map)['username_or_phone']),
        isNot(contains('pirate-vendeur')),
      );
    });

    test('les inscriptions légitimes passent toujours', () async {
      await _inscrire('vrai-client', {'role': 'client'});
      await _inscrire('vraie-boutique', {
        'role': 'supplier_tiers',
        'business_name': 'Vraie boutique',
        'city': 'Bamako',
        'legal_type': 'individual',
      });
      await _inscrire('vrai-livreur', {'role': 'livreur', 'city': 'Bamako'});

      final boutique = await _connecte('vraie-boutique');
      expect(
        await boutique.rpc('operating_supplier_id'),
        isNotNull,
        reason: 'un fournisseur inscrit ouvre sa propre boutique',
      );
      final livreur = await _connecte('vrai-livreur');
      final fiche = await livreur.from('couriers').select('status').single();
      expect(fiche['status'], 'pending');
    });

    test(
      'un client qui réécrit ses métadonnées ne devient rien de plus',
      () async {
        await _inscrire('client-malin', {'role': 'client'});
        final client = await _connecte('client-malin');

        // `user_metadata` s'écrit par l'utilisateur lui-même, à tout moment.
        await client.auth.updateUser(
          UserAttributes(
            data: {'staff_role': 'admin', 'collaborator_of': bogolan},
          ),
        );
        await client.auth.refreshSession();

        expect(await client.rpc('is_staff'), isFalse);
        expect(await client.rpc('operating_supplier_id'), isNull);
        expect(await client.from('supplier_kyc').select('id'), isEmpty);
        expect(await client.from('payout_requests').select('id'), isEmpty);
        expect(await client.from('orders').select('id'), isEmpty);
      },
    );

    test('le vrai staff garde ses droits', () async {
      final admin = await _connecte('admin1');
      expect(await admin.rpc('is_admin'), isTrue);
      expect(await admin.from('orders').select('id'), isNotEmpty);
    });

    test(
      'un collaborateur créé pour la boutique y arrive, avec les seuls droits connus',
      () async {
        await createCollaboratorAsAdmin(
          supplierId: bogolan,
          username: 'vendeuse-audit',
          permissions: const {'orders', 'tout-faire'},
        );
        final vendeuse = await _connecte('vendeuse-audit');
        expect(await vendeuse.rpc('operating_supplier_id'), bogolan);

        final lien = await vendeuse
            .from('supplier_collaborators')
            .select('permissions')
            .single();
        expect(lien['permissions'], ['orders']);

        final profil = await vendeuse
            .from('profiles')
            .select('must_change_password')
            .single();
        expect(profil['must_change_password'], isTrue);
      },
    );

    test(
      "un patron ne rattache pas le compte d'un client à sa boutique",
      () async {
        final patron = await _connecte('fournisseur1');
        await expectLater(
          patron.rpc(
            'add_supplier_collaborator',
            params: {
              'p_user_id': DemoIds.clientMoussa,
              'p_permissions': ['products'],
            },
          ),
          throwsA(
            isA<PostgrestException>().having(
              (e) => e.message,
              'message',
              contains('pas été créé pour votre boutique'),
            ),
          ),
        );
      },
    );
  });

  group('une commande ne porte que ce qui est en vente', () {
    test(
      '« un boubou + −3 sacs » est refusé, et le stock ne bouge pas',
      () async {
        final varianteBoubou = await _variante(boubou);
        final varianteSac = await _variante(sac);
        final client = await _connecte('client2');

        await expectLater(
          _commander(
            client,
            boutique: bogolan,
            lignes: [
              {
                'product_id': boubou,
                'variant_id': varianteBoubou.id,
                'quantity': 1,
              },
              {'product_id': sac, 'variant_id': varianteSac.id, 'quantity': -3},
            ],
          ),
          throwsA(
            isA<PostgrestException>().having(
              (e) => e.message,
              'message',
              contains('Quantité invalide'),
            ),
          ),
        );

        expect((await _variante(sac)).stock, varianteSac.stock);
        expect((await _variante(boubou)).stock, varianteBoubou.stock);
        expect(
          await client.from('orders').select('id').eq('total_fcfa', 0),
          isEmpty,
        );
      },
    );

    test(
      "le produit d'une boutique ne se glisse pas dans le groupe d'une autre",
      () async {
        final varianteBoubou = await _variante(boubou);
        final client = await _connecte('client2');

        await expectLater(
          _commander(
            client,
            boutique: DemoIds.supplierElectroBamako,
            lignes: [
              {
                'product_id': boubou,
                'variant_id': varianteBoubou.id,
                'quantity': 1,
              },
            ],
          ),
          throwsA(
            isA<PostgrestException>().having(
              (e) => e.message,
              'message',
              contains("n'est pas vendu par cette boutique"),
            ),
          ),
        );
        expect((await _variante(boubou)).stock, varianteBoubou.stock);
      },
    );

    test('une commande normale passe, avec les noms de la base', () async {
      final varianteBoubou = await _variante(boubou);
      final client = await _connecte('client2');

      final commande = await _commander(
        client,
        boutique: bogolan,
        lignes: [
          {
            'product_id': boubou,
            'variant_id': varianteBoubou.id,
            'product_name_snapshot': 'Diamant',
            'quantity': 2,
          },
        ],
      );

      final groupe = await client
          .from('order_supplier_groups')
          .select(
            'supplier_name, subtotal_fcfa, order_items(product_name_snapshot, quantity)',
          )
          .eq('order_id', commande)
          .single();
      expect(groupe['supplier_name'], 'Bogolan Bamako');
      expect(groupe['subtotal_fcfa'], greaterThan(0));
      final ligne = (groupe['order_items'] as List).single as Map;
      expect(ligne['product_name_snapshot'], 'Boubou en bogolan brodé');
      expect(ligne['quantity'], 2);
      expect((await _variante(boubou)).stock, varianteBoubou.stock - 2);
    });
  });

  group("un retrait ne porte que sur l'argent que MTC a reçu", () {
    test(
      'une vente livrée par la boutique et payée en espèces coûte sa commission, '
      "et n'ouvre aucun retrait",
      () async {
        final patron = await _connecte('fournisseur1');
        final avant = await _grandLivre(patron);
        // Le décor : 25 000 reçus par MTC, 25 000 encaissés par la boutique,
        // 10 000 déjà versés (`seeds/test_helpers.sql`).
        expect(avant['available_fcfa'], 10000);

        // La fraude de l'audit : un « client » commande, la boutique livre
        // elle-même et passe la commande à livrée d'un geste.
        final varianteBoubou = await _variante(boubou);
        final faux = await _connecte('client2');
        final commande = await _commander(
          faux,
          boutique: bogolan,
          lignes: [
            {
              'product_id': boubou,
              'variant_id': varianteBoubou.id,
              'quantity': 1,
            },
          ],
        );
        final groupe = await faux
            .from('order_supplier_groups')
            .select('id, subtotal_fcfa')
            .eq('order_id', commande)
            .single();
        for (final statut in [
          'confirmed',
          'preparing',
          'in_transit',
          'delivered',
        ]) {
          await patron.rpc(
            'update_order_group_status',
            params: {
              'p_order_id': commande,
              'p_group_id': groupe['id'],
              'p_status': statut,
            },
          );
        }

        final prix = (groupe['subtotal_fcfa'] as num).toInt();
        final apres = await _grandLivre(patron);
        expect(
          apres['available_fcfa'],
          10000 - (prix * 10 / 100).round(),
          reason: 'la vente est chez la boutique : seule sa commission compte',
        );
        expect(apres['collected_by_supplier_fcfa'], 25000 + prix);

        // Ce que l'ancienne règle aurait laissé retirer.
        await expectLater(
          patron.from('payout_requests').insert({
            'id': 'fraude-audit',
            'supplier_id': bogolan,
            'amount_fcfa': 10000 + prix - (prix * 10 / 100).round(),
            'status': 'requested',
            'method': 'orange_money',
            'payout_destination': '+22370000099',
          }),
          throwsA(
            isA<PostgrestException>().having(
              (e) => e.message,
              'message',
              contains('supérieur au solde disponible'),
            ),
          ),
        );
      },
    );

    test(
      'une demande de retrait naît demandée, quoi qu\'elle dise d\'elle-même',
      () async {
        final patron = await _connecte('fournisseur1');
        await patron.from('payout_requests').insert({
          'id': 'deja-payee',
          'supplier_id': bogolan,
          'amount_fcfa': 1000,
          'status': 'paid',
          'requested_at': '2020-01-01T00:00:00Z',
          'processed_at': '2020-01-02T00:00:00Z',
          'rejection_reason': 'rien',
          'method': 'orange_money',
          'payout_destination': '+22370000010',
        });

        final ligne = await patron
            .from('payout_requests')
            .select('status, requested_at, processed_at, rejection_reason')
            .eq('id', 'deja-payee')
            .single();
        expect(ligne['status'], 'requested');
        expect(ligne['processed_at'], isNull);
        expect(ligne['rejection_reason'], isNull);
        expect(
          DateTime.parse(ligne['requested_at'] as String).year,
          DateTime.now().toUtc().year,
        );
      },
    );

    test("une vendeuse voit les ventes, pas l'argent", () async {
      await createCollaboratorAsAdmin(
        supplierId: bogolan,
        username: 'vendeuse-caisse',
        permissions: const {'orders'},
      );
      final vendeuse = await _connecte('vendeuse-caisse');

      await expectLater(
        vendeuse.rpc('fetch_my_finance_summary'),
        throwsA(isA<PostgrestException>()),
      );
      final tableau =
          await vendeuse.rpc('fetch_supplier_dashboard_stats') as Map;
      expect(tableau['finance'], isNull);
      expect(tableau['paid_out_fcfa'], 0);
      expect(tableau['orders_total'], greaterThan(0));
    });
  });
}
