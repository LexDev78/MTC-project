@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';

import '../../support/supabase_test_harness.dart';

// Audit de sécurité : argent, idempotence, sessions, charge.
//
// Rien ici n'est affirmé sans être mesuré. Chaque cas met le serveur dans
// la situation réelle — plusieurs sessions distinctes, lancées vraiment en
// parallèle — et vérifie l'**invariant**, pas le chemin heureux.
//
// `concurrency_test.dart` couvre déjà trois courses : deux notations d'une
// même course, deux commandes sur un code à usage unique, deux acheteurs sur
// la dernière unité. Ce fichier prend la suite, là où l'argent et les
// sessions entrent en jeu.

Future<SupabaseClient> _connecte(String identifiant) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(identifiant),
    password: 'password123',
  );
  addTearDown(client.dispose);
  return client;
}

/// Ce que MTC doit à la boutique avant tout retrait : ce qu'il a encaissé
/// pour elle, moins sa commission — y compris celle due sur ce que la
/// boutique a encaissé elle-même (`supplier_ledger`, `0131`). Lu par le
/// propriétaire, qui en a le droit.
///
/// C'est **le** plafond : aucune combinaison de retraits ne doit le
/// dépasser. Il se lit chez le serveur plutôt que de recopier la règle ici.
/// Recopiée, elle comptait toute vente « livrée », y compris celles payées
/// à la boutique en espèces : c'est la faille que `0131` ferme.
Future<int> _netDu(SupabaseClient patron) async {
  final grandLivre = await patron.rpc('fetch_my_finance_summary') as Map;
  return (grandLivre['net_fcfa'] as num).toInt();
}

/// Le total des retraits non refusés.
Future<int> _totalDemande(SupabaseClient patron) async {
  final rows = await patron
      .from('payout_requests')
      .select('amount_fcfa, status')
      .eq('supplier_id', DemoIds.supplierBogolanBamako);
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .where((row) => row['status'] != 'rejected')
      .fold<int>(0, (somme, row) => somme + (row['amount_fcfa'] as num).toInt());
}

/// Le solde réellement disponible : le net dû, moins ce qui a déjà été
/// demandé — ce que `guard_payout_amount` compte sous verrou.
Future<int> _soldeDisponible(SupabaseClient patron) async {
  return await _netDu(patron) - await _totalDemande(patron);
}

/// Lance l'appel et dit seulement s'il a abouti.
///
/// Sous contention, un refus est un résultat légitime — ce qui se vérifie
/// ensuite, c'est que l'état de la base corresponde exactement au nombre
/// d'appels acceptés.
Future<bool> _aAbouti(Future<Object?> Function() appel) async {
  try {
    await appel();
    return true;
  } catch (_) {
    return false;
  }
}

/// Les lignes de commande portant sur un produit, comptées avec les droits
/// du staff MTC — `order_items` n'est pas lisible hors des parties
/// concernées, et c'est précisément ce qu'on ne veut pas contourner ailleurs.
Future<int> _lignesDeCommande(String productId) async {
  final staff = await _connecte('admin1');
  final rows = await staff
      .from('order_items')
      .select('id')
      .eq('product_id', productId);
  return (rows as List).length;
}

/// Le stock d'un produit, lu hors session (le catalogue est public).
Future<int> _stockProduit(String productId) async {
  final client = createTestSupabaseClient();
  addTearDown(client.dispose);
  final row = await client
      .from('products')
      .select('stock_quantity')
      .eq('id', productId)
      .single();
  return (row['stock_quantity'] as num).toInt();
}

void main() {
  setUp(resetAndSeed);

  group("l'argent sous concurrence", () {
    test(
      'deux retraits simultanés du solde entier : un seul doit passer',
      () async {
        final lecteur = await _connecte('fournisseur1');
        final solde = await _soldeDisponible(lecteur);
        expect(
          solde,
          greaterThan(0),
          reason: 'sans solde, la course ne prouverait rien',
        );

        // Deux sessions distinctes du **même** propriétaire : c'est ainsi
        // qu'un double clic, ou deux téléphones, se présentent au serveur.
        final a = await _connecte('fournisseur1');
        final b = await _connecte('fournisseur1');

        Future<Object?> demander(SupabaseClient c, String id) async {
          try {
            await c.from('payout_requests').insert({
              'id': id,
              'supplier_id': DemoIds.supplierBogolanBamako,
              'amount_fcfa': solde,
              'status': 'requested',
              'method': 'orange_money',
              'payout_destination': '+22370000000',
            });
            return null;
          } catch (e) {
            return e;
          }
        }

        final resultats = await Future.wait([
          demander(a, 'course-retrait-1'),
          demander(b, 'course-retrait-2'),
        ]);

        final acceptes = resultats.where((e) => e == null).length;
        expect(
          acceptes,
          1,
          reason:
              'deux demandes du solde entier doivent se solder par une seule '
              'acceptation — sinon la boutique est payée deux fois',
        );

        // Et l'invariant, vérifié sur la base plutôt que sur les retours :
        // le total demandé ne dépasse jamais ce qui était disponible.
        final demande = await _totalDemande(lecteur);
        expect(
          demande,
          lessThanOrEqualTo(await _netDu(lecteur)),
          reason: 'le total demandé ne peut pas dépasser le net gagné',
        );
      },
    );
  });

  group("l'idempotence : rejouer ne doit rien doubler", () {
    test('soumettre deux fois le même dossier est refusé la seconde', () async {
      // Resoumettre remettrait le compteur à zéro dans la file du staff :
      // un dossier pourrait passer devant les autres indéfiniment.
      //
      // Le dossier choisi est celui de `fournisseur4`, **refusé** : c'est le
      // seul état depuis lequel une soumission est légitime. Avec un
      // fournisseur sans dossier, les deux appels échoueraient pour la même
      // raison et le test passerait sans rien démontrer.
      final patron = await _connecte('fournisseur4');

      await patron.rpc('submit_supplier_kyc');
      final apresPremier = await patron
          .from('supplier_kyc')
          .select('status, submitted_at')
          .single();
      expect(apresPremier['status'], 'submitted');

      await expectLater(
        patron.rpc('submit_supplier_kyc'),
        throwsA(isA<PostgrestException>()),
        reason: 'une seconde soumission ne doit jamais aboutir',
      );

      // Et surtout : l'horodatage n'a pas bougé. C'est lui qui fixe le rang
      // dans la file, donc c'est lui qu'un renvoi répété viserait.
      final apresSecond = await patron
          .from('supplier_kyc')
          .select('status, submitted_at')
          .single();
      expect(apresSecond['submitted_at'], apresPremier['submitted_at']);
      expect(apresSecond['status'], 'submitted');
    });

    test('rattacher deux fois le même collaborateur ne le double pas', () async {
      final userId = await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'rejoue1',
        permissions: const {'products'},
      );
      final patron = await _connecte('fournisseur1');

      // `on conflict do update` : l'appel se rejoue sans créer de doublon,
      // et met à jour les droits. C'est ce qu'on attend d'un bouton qu'on
      // peut toucher deux fois sur une connexion lente.
      await patron.rpc(
        'add_supplier_collaborator',
        params: {
          'p_user_id': userId,
          'p_permissions': ['products', 'orders'],
        },
      );
      await patron.rpc(
        'add_supplier_collaborator',
        params: {
          'p_user_id': userId,
          'p_permissions': ['products', 'orders'],
        },
      );

      final equipe = await patron.rpc('fetch_my_collaborators') as List;
      expect(equipe, hasLength(1));
      expect((equipe.single as Map)['permissions'], ['products', 'orders']);
    });

    test('lever deux fois le drapeau de mot de passe est sans effet', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'rejoue2',
        permissions: const {'products'},
      );
      final collaborateur = await _connecte('rejoue2');

      await collaborateur.rpc('mark_password_changed');
      await collaborateur.rpc('mark_password_changed');

      final profil = await collaborateur
          .from('profiles')
          .select('must_change_password')
          .eq('username_or_phone', 'rejoue2')
          .single();
      expect(profil['must_change_password'], isFalse);
    });

    test('retirer deux fois un collaborateur échoue la seconde', () async {
      final userId = await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'rejoue3',
        permissions: const {'products'},
      );
      final patron = await _connecte('fournisseur1');

      await patron.rpc(
        'remove_supplier_collaborator',
        params: {'p_user_id': userId},
      );
      // Un refus franc plutôt qu'un succès silencieux : l'écran doit
      // pouvoir dire « ce collaborateur n'est plus là » au lieu de laisser
      // croire qu'il vient de le retirer.
      await expectLater(
        patron.rpc(
          'remove_supplier_collaborator',
          params: {'p_user_id': userId},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('le contrôle de session', () {
    test('un jeton forgé n\'ouvre rien', () async {
      final faux = SupabaseClient(
        testSupabaseUrl,
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwi'
            'cm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43k'
            'dQwgnWNReilDMblYTn_I0',
        headers: const {
          // Une signature inventée : le serveur doit la rejeter, pas la
          // croire sur parole.
          'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ2b2xldXIifQ.x',
        },
      );
      addTearDown(faux.dispose);

      try {
        final lignes = await faux.from('payout_requests').select();
        expect(lignes, isEmpty);
      } on PostgrestException {
        // Rejeté d'emblée : mieux encore.
      }
    });

    test('un collaborateur retiré perd l\'accès à la suite', () async {
      final userId = await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'ephemere',
        permissions: const {'products'},
      );
      final collaborateur = await _connecte('ephemere');
      expect(
        await collaborateur.rpc('operating_supplier_id'),
        DemoIds.supplierBogolanBamako,
      );

      final patron = await _connecte('fournisseur1');
      await patron.rpc(
        'remove_supplier_collaborator',
        params: {'p_user_id': userId},
      );

      // La session reste techniquement valide — le jeton n'est pas révoqué —
      // mais elle n'opère plus aucune boutique. C'est ce qui compte : les
      // droits se lisent à chaque requête, pas une fois à la connexion.
      expect(await collaborateur.rpc('operating_supplier_id'), isNull);
      final produits = await collaborateur
          .from('products')
          .select('id')
          .eq('supplier_id', DemoIds.supplierBogolanBamako)
          .neq('status', 'active');
      expect(produits, isEmpty);
    });

    test('une permission retirée prend effet sans reconnexion', () async {
      final userId = await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'volatil',
        permissions: const {'promotions'},
      );
      final collaborateur = await _connecte('volatil');
      expect(
        await collaborateur.rpc('fetch_my_promo_codes'),
        isA<List<dynamic>>(),
      );

      final patron = await _connecte('fournisseur1');
      await patron.rpc(
        'set_collaborator_permissions',
        params: {'p_user_id': userId, 'p_permissions': <String>[]},
      );

      expect(await collaborateur.rpc('fetch_my_promo_codes'), isEmpty);
    });
  });

  group('sous charge, les invariants tiennent', () {
    test('douze retraits simultanés ne dépassent jamais le solde', () async {
      final lecteur = await _connecte('fournisseur1');
      final solde = await _soldeDisponible(lecteur);
      expect(solde, greaterThan(0));

      // Chacun demande un tiers du solde : trois peuvent passer, pas douze.
      // Douze sessions distinctes, lancées ensemble — c'est la forme que
      // prend un script, ou un bouton touché en rafale sur un réseau lent.
      final part = solde ~/ 3;
      final sessions = await Future.wait([
        for (var i = 0; i < 12; i++) _connecte('fournisseur1'),
      ]);

      await Future.wait([
        for (var i = 0; i < sessions.length; i++)
          sessions[i]
              .from('payout_requests')
              .insert({
                'id': 'charge-retrait-$i',
                'supplier_id': DemoIds.supplierBogolanBamako,
                'amount_fcfa': part,
                'status': 'requested',
                'method': 'orange_money',
                'payout_destination': '+22370000000',
              })
              .catchError((_) => null),
      ]);

      final net = await _netDu(lecteur);
      expect(
        await _totalDemande(lecteur),
        lessThanOrEqualTo(net),
        reason: 'aucune combinaison de demandes ne doit dépasser le net gagné',
      );
    });

    test('vingt décréments simultanés ne perdent aucune écriture', () async {
      // Les quatre produits de cette boutique ont tous des variantes :
      // `adjust_stock` exige alors qu'on précise laquelle. On prend celle
      // qui existe après le réamorçage — les identifiants de variantes sont
      // tirés au semis, donc ils ne peuvent pas être écrits en dur.
      final patron = await _connecte('fournisseur1');
      final variantes = await patron
          .from('product_variants')
          .select('id, product_id, stock_quantity, products!inner(supplier_id)')
          .eq('products.supplier_id', DemoIds.supplierBogolanBamako)
          .gt('stock_quantity', 0)
          .order('stock_quantity', ascending: true)
          .limit(1);
      final variante = ((variantes as List).first as Map<String, dynamic>);
      final stockInitial = (variante['stock_quantity'] as num).toInt();

      // Vingt retraits d'un dixième du stock, plus une unité : la somme
      // demandée dépasse volontairement ce qui existe, donc une partie doit
      // être refusée.
      final part = (stockInitial ~/ 10) + 1;
      final sessions = await Future.wait([
        for (var i = 0; i < 20; i++) _connecte('fournisseur1'),
      ]);

      final issues = await Future.wait([
        for (final session in sessions)
          _aAbouti(
            () => session.rpc(
              'adjust_stock',
              params: {
                'p_product_id': variante['product_id'],
                'p_variant_id': variante['id'],
                'p_quantity_delta': -part,
                'p_reason': 'manual_adjustment',
              },
            ),
          ),
      ]);
      final reussis = issues.where((ok) => ok).length;

      expect(
        reussis,
        greaterThan(0),
        reason: 'si aucun retrait ne passe, le test ne prouve rien',
      );

      final apres = await patron
          .from('product_variants')
          .select('stock_quantity')
          .eq('id', variante['id'])
          .single();
      final stockFinal = (apres['stock_quantity'] as num).toInt();

      expect(
        stockFinal,
        greaterThanOrEqualTo(0),
        reason: 'le stock ne doit jamais passer sous zéro',
      );
      // L'égalité est le vrai contrôle : elle échoue dès qu'un décrément
      // écrase celui d'à côté — une écriture perdue laisserait un stock
      // plus haut que le nombre de retraits acceptés.
      expect(
        stockFinal,
        stockInitial - reussis * part,
        reason: 'chaque retrait accepté doit se lire une fois, et une seule',
      );
      // Et le journal doit raconter exactement la même histoire.
      final mouvements = await patron
          .from('stock_movements')
          .select('quantity_delta')
          .eq('variant_id', variante['id'])
          .eq('reason', 'manual_adjustment');
      expect((mouvements as List), hasLength(reussis));
    });

    test('douze acheteurs sur la dernière unité : un seul repart avec',
        () async {
      // Le produit du jeu de démonstration qui n'a pas de variante, descendu
      // à exactement une unité.
      const produit = 'd9d25e13-71ac-51c4-93f7-ed042a996500'; // Riz local 25kg
      final stockActuel = await _stockProduit(produit);
      final lignesAvant = await _lignesDeCommande(produit);
      await adjustStockAsAdmin(
        productId: produit,
        quantityDelta: 1 - stockActuel,
      );

      // Douze sessions distinctes du même client : la forme que prend un
      // bouton touché en rafale, ou douze onglets ouverts.
      final sessions = await Future.wait([
        for (var i = 0; i < 12; i++) _connecte('client2'),
      ]);
      final groupes = [
        {
          'supplier_id': '2c66294c-e1d7-59f1-925c-5ab6703827f3',
          'supplier_name': 'Alimentation Ségou',
          'delivery_mode': 'self_delivery',
          'items': [
            {
              'product_id': produit,
              'variant_id': null,
              'product_name_snapshot': 'Riz local 25kg',
              'variant_name_snapshot': null,
              'quantity': 1,
            },
          ],
        },
      ];

      final issues = await Future.wait([
        for (final session in sessions)
          _aAbouti(
            () => session.rpc(
              'place_order',
              params: {
                'p_client_display_name_snapshot': 'Moussa Diarra',
                'p_client_phone_snapshot': '+22370000002',
                'p_groups': groupes,
                'p_delivery_address_label': 'Domicile',
                'p_delivery_city': 'Bamako',
                'p_delivery_details': 'Badalabougou',
                'p_delivery_latitude': 12.63,
                'p_delivery_longitude': -8.0,
              },
            ),
          ),
      ]);
      final reussis = issues.where((ok) => ok).length;

      expect(
        reussis,
        lessThanOrEqualTo(1),
        reason: 'une seule unité ne peut pas être vendue douze fois',
      );
      expect(await _stockProduit(produit), 1 - reussis);
      // Le stock décrémenté ne suffit pas : il faut aussi qu'il n'existe pas
      // de ligne de commande sans stock derrière elle. On compte l'écart —
      // le jeu de démonstration porte déjà une commande sur ce produit.
      expect(await _lignesDeCommande(produit) - lignesAvant, reussis);
    });

    test('vingt lectures simultanées du tableau de bord aboutissent toutes',
        () async {
      final sessions = await Future.wait([
        for (var i = 0; i < 20; i++) _connecte('fournisseur1'),
      ]);

      final resultats = await Future.wait([
        for (final session in sessions)
          session.rpc('fetch_supplier_dashboard_stats'),
      ]);

      expect(resultats, hasLength(20));
      for (final r in resultats) {
        expect(r, isA<Map<String, dynamic>>());
        expect((r as Map)['orders_delivered'], isNotNull);
      }
      // Et tous rendent la même chose : une lecture concurrente ne doit pas
      // voir un état à moitié écrit.
      final references = resultats
          .map((r) => (r as Map)['gross_fcfa'])
          .toSet();
      expect(references, hasLength(1));
    });
  });
}
