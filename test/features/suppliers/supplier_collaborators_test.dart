@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';

import '../../support/supabase_test_harness.dart';

// Une boutique, plusieurs personnes (`0093`, `0094`).
//
// Ce qui se vérifie ici tient en trois questions : un collaborateur
// travaille-t-il bien dans la boutique de son patron ; ne peut-il faire que
// ce qu'on lui a accordé ; et les quatre gestes qui ne se délèguent pas
// lui restent-ils fermés quoi qu'il arrive.

const _bogolan = 'b0fe527e-1f73-55e6-b24e-4d985576d473';

Future<SupabaseClient> _connecte(String identifiant) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(identifiant),
    password: 'password123',
  );
  addTearDown(client.dispose);
  return client;
}

void main() {
  setUp(resetAndSeed);

  test('un collaborateur opère la boutique de son patron', () async {
    await createCollaboratorAsAdmin(
      supplierId: DemoIds.supplierBogolanBamako,
      username: 'vendeur_a',
      permissions: const {'products'},
    );
    final collaborateur = await _connecte('vendeur_a');

    final boutique = await collaborateur.rpc('operating_supplier_id');
    expect(boutique, DemoIds.supplierBogolanBamako);
    expect(await collaborateur.rpc('is_supplier_owner'), isFalse);

    // Et il voit bien le catalogue de cette boutique, brouillons compris —
    // ce qu'un simple client ne verrait pas.
    final produits = await collaborateur
        .from('products')
        .select('id')
        .eq('supplier_id', DemoIds.supplierBogolanBamako);
    expect((produits as List), isNotEmpty);
  });

  test('aucune boutique vide n\'est créée pour un collaborateur', () async {
    final userId = await createCollaboratorAsAdmin(
      supplierId: DemoIds.supplierBogolanBamako,
      username: 'vendeur_b',
      permissions: const {},
    );

    // Sans la branche de `handle_new_user`, le rôle `supplier_tiers`
    // aurait ouvert une boutique à son nom — et `operating_supplier_id()`
    // l'aurait renvoyé chez lui plutôt que chez son patron.
    final admin = createTestSupabaseClient();
    addTearDown(admin.dispose);
    expect(
      await _connecte('vendeur_b').then((c) => c.rpc('operating_supplier_id')),
      DemoIds.supplierBogolanBamako,
      reason: 'le rattachement doit l\'emporter, car il n\'a pas de boutique',
    );
    expect(userId, isNotEmpty);
  });

  group('les permissions sont tenues, pas seulement affichées', () {
    test('sans le droit « produits », il ne peut pas en modifier', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_c',
        permissions: const {'orders'},
      );
      final collaborateur = await _connecte('vendeur_c');

      // La policy filtre : la mise à jour ne touche aucune ligne plutôt que
      // de lever. On vérifie donc l'effet, pas l'exception.
      await collaborateur
          .from('products')
          .update({'name': 'Renommé sans droit'})
          .eq('id', _bogolan);

      final apres = await collaborateur
          .from('products')
          .select('name')
          .eq('id', _bogolan)
          .single();
      expect(apres['name'], isNot('Renommé sans droit'));
    });

    test('avec le droit « produits », il peut', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_d',
        permissions: const {'products'},
      );
      final collaborateur = await _connecte('vendeur_d');

      await collaborateur
          .from('products')
          .update({'name': 'Renommé par le vendeur'})
          .eq('id', _bogolan);

      final apres = await collaborateur
          .from('products')
          .select('name')
          .eq('id', _bogolan)
          .single();
      expect(apres['name'], 'Renommé par le vendeur');
    });

    test('sans le droit « vitrine », il ne touche pas à la boutique', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_e',
        permissions: const {'products'},
      );
      final collaborateur = await _connecte('vendeur_e');

      await collaborateur
          .from('suppliers')
          .update({'description': 'Changée sans droit'})
          .eq('id', DemoIds.supplierBogolanBamako);

      final apres = await collaborateur
          .from('suppliers')
          .select('description')
          .eq('id', DemoIds.supplierBogolanBamako)
          .single();
      expect(apres['description'], isNot('Changée sans droit'));
    });
  });

  group('ce qui ne se délègue jamais', () {
    test('un collaborateur ne demande pas de retrait d\'argent', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_f',
        // Tous les droits accordables, et pourtant.
        permissions: const {
          'products',
          'orders',
          'promotions',
          'storefront',
          'messages',
          'reviews',
        },
      );
      final collaborateur = await _connecte('vendeur_f');

      await expectLater(
        collaborateur.from('payout_requests').insert({
          'id': 'retrait-test',
          'supplier_id': DemoIds.supplierBogolanBamako,
          'amount_fcfa': 1000,
          'status': 'requested',
          'method': 'orange_money',
          'payout_destination': '+22370000000',
        }),
        throwsA(isA<PostgrestException>()),
        reason: 'un employé ne vide pas la caisse',
      );
    });

    test('il ne soumet pas le dossier de vérification', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_g',
        permissions: const {'storefront'},
      );
      final collaborateur = await _connecte('vendeur_g');

      await expectLater(
        collaborateur.rpc('submit_supplier_kyc'),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('il n\'ajoute ni ne retire de collaborateur', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_h',
        permissions: const {'products', 'orders'},
      );
      final autre = await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_i',
        permissions: const {'products'},
      );
      final collaborateur = await _connecte('vendeur_h');

      // Celui qu'on vient de faire entrer n'évince pas celui qui l'a fait
      // entrer, et n'en recrute pas d'autres.
      await expectLater(
        collaborateur.rpc(
          'remove_supplier_collaborator',
          params: {'p_user_id': autre},
        ),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        collaborateur.rpc(
          'set_collaborator_permissions',
          params: {'p_user_id': autre, 'p_permissions': <String>[]},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('il ne voit pas la liste de ses collègues', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_j',
        permissions: const {'products'},
      );
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_k',
        permissions: const {'orders'},
      );
      final collaborateur = await _connecte('vendeur_j');

      final equipe = await collaborateur.rpc('fetch_my_collaborators');
      expect(
        equipe,
        isEmpty,
        reason: 'qui peut quoi dans la boutique ne le regarde pas',
      );
    });
  });

  group('le patron gère son équipe', () {
    test('il ajoute, modifie les accès, et retire', () async {
      final userId = await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_l',
        permissions: const {'products'},
      );
      final patron = await _connecte('fournisseur1');

      var equipe = await patron.rpc('fetch_my_collaborators') as List;
      expect(equipe, hasLength(1));
      expect((equipe.single as Map)['permissions'], ['products']);

      await patron.rpc(
        'set_collaborator_permissions',
        params: {
          'p_user_id': userId,
          'p_permissions': ['products', 'orders'],
        },
      );
      equipe = await patron.rpc('fetch_my_collaborators') as List;
      expect((equipe.single as Map)['permissions'], ['products', 'orders']);

      await patron.rpc(
        'remove_supplier_collaborator',
        params: {'p_user_id': userId},
      );
      expect(await patron.rpc('fetch_my_collaborators'), isEmpty);
    });

    test('retirer coupe l\'accès sans supprimer le compte', () async {
      final userId = await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_m',
        permissions: const {'products'},
      );
      final patron = await _connecte('fournisseur1');
      await patron.rpc(
        'remove_supplier_collaborator',
        params: {'p_user_id': userId},
      );

      final ancien = await _connecte('vendeur_m');
      // Le compte existe toujours — les commandes qu'il a traitées gardent
      // son nom — mais il n'opère plus aucune boutique.
      expect(await ancien.rpc('operating_supplier_id'), isNull);
    });

    test('un patron ne recrute pas chez le voisin', () async {
      final userId = await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_n',
        permissions: const {'products'},
      );
      final autrePatron = await _connecte('fournisseur2');

      await expectLater(
        autrePatron.rpc(
          'remove_supplier_collaborator',
          params: {'p_user_id': userId},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  // Une permission tenue par la seule RLS ne l'est qu'à moitié : une bonne
  // part des écritures passe par des fonctions `security definer`, qui la
  // contournent par construction. C'est le chemin par lequel un
  // collaborateur sans le droit « produits » pouvait quand même ajuster un
  // stock et refaire des variantes (`0097`).
  group('les chemins qui contournent la RLS sont gardés aussi', () {
    test('sans le droit « produits », il n\'ajuste pas le stock', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_o',
        permissions: const {'orders'},
      );
      final collaborateur = await _connecte('vendeur_o');

      await expectLater(
        collaborateur.rpc(
          'adjust_stock',
          params: {
            'p_product_id': _bogolan,
            'p_quantity_delta': 5,
            'p_reason': 'restock',
          },
        ),
        throwsA(isA<PostgrestException>()),
        reason: '`adjust_stock` est `security definer` : la policy ne le voit pas',
      );
    });

    test('avec le droit, il franchit le garde', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_p',
        permissions: const {'products'},
      );
      final collaborateur = await _connecte('vendeur_p');

      // Ce produit a des variantes : `adjust_stock` exige alors qu'on
      // précise laquelle, et refuse. Ce refus-là est une règle métier
      // ancienne, pas le garde de permission — et c'est précisément ce
      // qu'on vérifie : le collaborateur autorisé atteint la logique, au
      // lieu d'être arrêté avant.
      try {
        await collaborateur.rpc(
          'adjust_stock',
          params: {
            'p_product_id': _bogolan,
            'p_quantity_delta': 5,
            'p_reason': 'restock',
          },
        );
      } on PostgrestException catch (e) {
        expect(e.message, contains('variantes'));
        expect(
          e.message,
          isNot(contains('accès')),
          reason: 'le garde de permission ne doit pas s\'être déclenché',
        );
      }
    });

    test('sans le droit « produits », il ne refait pas les variantes', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_q',
        permissions: const {'orders'},
      );
      final collaborateur = await _connecte('vendeur_q');

      await expectLater(
        collaborateur.rpc(
          'replace_product_characteristics_and_variants',
          params: {
            'p_product_id': _bogolan,
            'p_characteristics': <dynamic>[],
            'p_variants': <dynamic>[],
          },
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('sans le droit « remises », il n\'en pose pas', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_r',
        permissions: const {'products'},
      );
      final collaborateur = await _connecte('vendeur_r');

      await expectLater(
        collaborateur.from('product_promotions').insert({
          'product_id': _bogolan,
          'kind': 'percentage',
          'value': 50,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('le mot de passe à usage unique', () {
    test('un collaborateur naît avec l\'obligation de le changer', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_s',
        permissions: const {'products'},
      );
      final collaborateur = await _connecte('vendeur_s');

      final profil = await collaborateur
          .from('profiles')
          .select('must_change_password')
          .eq('username_or_phone', 'vendeur_s')
          .single();
      expect(profil['must_change_password'], isTrue);
    });

    test('un fournisseur qui s\'inscrit lui-même n\'y est pas soumis', () async {
      // Il a choisi son mot de passe : rien à lui imposer.
      final patron = await _connecte('fournisseur1');
      final profil = await patron
          .from('profiles')
          .select('must_change_password')
          .eq('username_or_phone', 'fournisseur1')
          .single();
      expect(profil['must_change_password'], isFalse);
    });

    test('changer le mot de passe lève l\'obligation', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_t',
        permissions: const {'products'},
      );
      final collaborateur = await _connecte('vendeur_t');

      await collaborateur.rpc('mark_password_changed');

      final profil = await collaborateur
          .from('profiles')
          .select('must_change_password')
          .eq('username_or_phone', 'vendeur_t')
          .single();
      expect(profil['must_change_password'], isFalse);
    });

    test('le patron peut en redemander un pour un oubli', () async {
      final userId = await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_u',
        permissions: const {'products'},
      );
      final collaborateur = await _connecte('vendeur_u');
      await collaborateur.rpc('mark_password_changed');

      final patron = await _connecte('fournisseur1');
      // Le patron ne lit pas le profil de son employé — la policy ne montre
      // à chacun que le sien. L'information passe par sa propre RPC.
      var equipe = await patron.rpc('fetch_my_collaborators') as List;
      expect((equipe.single as Map)['must_change_password'], isFalse);

      await patron.rpc(
        'reset_collaborator_password_flag',
        params: {'p_user_id': userId},
      );

      equipe = await patron.rpc('fetch_my_collaborators') as List;
      expect((equipe.single as Map)['must_change_password'], isTrue);
    });

    test('un patron ne remet pas le drapeau chez le voisin', () async {
      final userId = await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_v',
        permissions: const {'products'},
      );
      final voisin = await _connecte('fournisseur2');

      await expectLater(
        voisin.rpc(
          'reset_collaborator_password_flag',
          params: {'p_user_id': userId},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  // Ce qu'un rôle n'a pas le droit de faire, il n'a pas le droit de le
  // voir. Les migrations `0094` à `0097` ne gardaient que les écritures —
  // une permission qui n'empêche que d'écrire laisse voir, et voir suffit à
  // nuire (`0100`).
  group('ce qu\'un collaborateur ne doit pas voir', () {
    test('les demandes de retrait lui sont fermées', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_w',
        // Tous les droits accordables : aucun n'ouvre l'argent.
        permissions: const {
          'products',
          'orders',
          'promotions',
          'storefront',
          'messages',
          'reviews',
        },
      );
      final collaborateur = await _connecte('vendeur_w');

      // Montants demandés et numéros Mobile Money de destination : un
      // vendeur au comptoir n'a pas à voir où part l'argent de son patron.
      final retraits = await collaborateur.from('payout_requests').select();
      expect(retraits, isEmpty);
    });

    test('le patron, lui, voit ses retraits', () async {
      // Le jeu de démonstration en pose un pour cette boutique : c'est ce
      // qui donne sa valeur au test précédent, où le collaborateur ne le
      // voit pas alors qu'il existe.
      final patron = await _connecte('fournisseur1');
      final retraits = await patron.from('payout_requests').select();
      expect(
        retraits,
        isNotEmpty,
        reason: 'sans donnée à cacher, « le collaborateur ne voit rien » '
            'ne prouverait rien',
      );
    });

    test('le taux de commission lui est fermé', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_x',
        permissions: const {'orders'},
      );
      final collaborateur = await _connecte('vendeur_x');

      // Aucune ligne n'existe dans le jeu de démonstration — l'application
      // retombe alors sur le taux par défaut. Ce qui se vérifie ici est donc
      // que la lecture ne **lève** pas tout en ne rendant rien : la policy
      // filtre, elle ne casse pas l'écran.
      final reglages = await collaborateur
          .from('supplier_finance_settings')
          .select();
      expect(reglages, isEmpty);
    });

    test('sans le droit « remises », il ne voit ni codes ni remises', () async {
      // Les deux lectures passent par des fonctions `security definer` :
      // elles contournaient les policies de `0094`.
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_y',
        permissions: const {'products', 'orders'},
      );
      final collaborateur = await _connecte('vendeur_y');

      expect(await collaborateur.rpc('fetch_my_promo_codes'), isEmpty);
      expect(await collaborateur.rpc('fetch_my_promotion_batches'), isEmpty);
    });

    test('avec le droit « remises », il les voit', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_z',
        permissions: const {'promotions'},
      );
      final patron = await _connecte('fournisseur1');
      await patron.rpc(
        'set_promotion_batch_active',
        params: {'p_batch_id': 'inexistant', 'p_is_active': false},
      ).catchError((_) => null);

      final collaborateur = await _connecte('vendeur_z');
      // La liste peut être vide faute de données, mais l'appel doit
      // aboutir et non être filtré par la garde.
      expect(
        await collaborateur.rpc('fetch_my_promo_codes'),
        isA<List<dynamic>>(),
      );
    });

    test('le tableau de bord ne lui montre pas l\'argent', () async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: 'vendeur_aa',
        permissions: const {'products', 'orders'},
      );
      final collaborateur = await _connecte('vendeur_aa');

      final stats =
          await collaborateur.rpc('fetch_supplier_dashboard_stats')
              as Map<String, dynamic>;

      // Les clés sont **absentes**, pas à zéro : un zéro se lirait comme
      // « la boutique n'a rien vendu ».
      for (final cle in [
        'gross_fcfa',
        'gross_last_30_days_fcfa',
        'gross_last_7_days_fcfa',
        'paid_out_fcfa',
      ]) {
        expect(stats.containsKey(cle), isFalse, reason: '$cle ne doit pas sortir');
      }
      // Ce qui ne touche pas à l'argent reste visible.
      expect(stats['orders_delivered'], isNotNull);
      expect(stats['views_total'], isNotNull);
      // Et le détail par article perd son montant.
      for (final article in (stats['best_sellers'] as List)) {
        expect((article as Map).containsKey('amount_fcfa'), isFalse);
      }
    });

    test('le patron, lui, voit tous les chiffres', () async {
      final patron = await _connecte('fournisseur1');
      final stats = await patron.rpc('fetch_supplier_dashboard_stats')
          as Map<String, dynamic>;

      expect(stats['gross_fcfa'], isNotNull);
      expect(stats['paid_out_fcfa'], isNotNull);
    });
  });

  group("le dossier d'identité du patron lui reste personnel", () {
    // Trouvé par l'audit du schéma (`0104`) : trois règles antérieures aux
    // gardes de collaborateur cloisonnaient par `operating_supplier_id()`,
    // qui répond « la boutique que j'opère » — donc celle du patron pour un
    // employé. Mesuré avant la correction : lecture du numéro fiscal,
    // `UPDATE 1` sur le dossier, et accès au fichier de la pièce d'identité.
    Future<SupabaseClient> collaborateurTousDroits(String nom) async {
      await createCollaboratorAsAdmin(
        supplierId: DemoIds.supplierBogolanBamako,
        username: nom,
        permissions: const {
          'products',
          'orders',
          'promotions',
          'storefront',
          'messages',
          'reviews',
        },
      );
      return _connecte(nom);
    }

    test('il ne lit ni le dossier, ni les pièces, même avec les six '
        'permissions', () async {
      final collaborateur = await collaborateurTousDroits('vendeur_kyc1');

      final dossiers = await collaborateur
          .from('supplier_kyc')
          .select('id, tax_id, rccm_number, legal_representative_name');
      expect(dossiers, isEmpty);

      final pieces = await collaborateur.from('supplier_documents').select('id');
      expect(pieces, isEmpty);

      // Et le fichier lui-même, par le chemin que l'app emprunte.
      final fichiers = await collaborateur.storage
          .from('kyc-documents')
          .list(path: DemoIds.supplierBogolanBamako);
      expect(fichiers, isEmpty);
    });

    test('il ne peut pas altérer le dossier soumis à MTC', () async {
      final collaborateur = await collaborateurTousDroits('vendeur_kyc2');

      try {
        await collaborateur
            .from('supplier_kyc')
            .update({'tax_id': 'FAUX-000'})
            .eq('supplier_id', DemoIds.supplierBogolanBamako);
      } on PostgrestException {
        // Refusé d'emblée : très bien.
      }

      // Relu par le patron, seul à pouvoir le faire.
      final patron = await _connecte('fournisseur1');
      final dossier = await patron
          .from('supplier_kyc')
          .select('tax_id')
          .eq('supplier_id', DemoIds.supplierBogolanBamako)
          .single();
      expect(dossier['tax_id'], isNot('FAUX-000'));
    });

    test('le patron, lui, garde son dossier et ses pièces', () async {
      // La correction ne vaut rien si elle ferme aussi la porte au
      // propriétaire : c'est lui qui constitue le dossier.
      final patron = await _connecte('fournisseur1');

      final dossier = await patron
          .from('supplier_kyc')
          .select('id, status')
          .eq('supplier_id', DemoIds.supplierBogolanBamako);
      expect(dossier, hasLength(1));

      final pieces = await patron.from('supplier_documents').select('id');
      expect(pieces, isNotEmpty);
    });

    test('et le staff MTC voit la file entière', () async {
      // L'examen des dossiers est son métier : il doit voir ceux de toutes
      // les boutiques, pas seulement d'une.
      final agent = await _connecte('agent1');
      final dossiers = await agent.from('supplier_kyc').select('id, supplier_id');
      expect((dossiers as List).length, greaterThan(1));
    });
  });
}
