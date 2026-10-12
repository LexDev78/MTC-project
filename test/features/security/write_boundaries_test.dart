@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';

import '../../support/supabase_test_harness.dart';

// Ce qu'une session cliente ne doit **pas** pouvoir écrire.
//
// Ces frontières étaient ouvertes parce que l'app faisait elle-même les
// écritures dérivées d'un avis (la moyenne du fournisseur, sa recopie sur
// ses produits, la notification). Elles sont passées côté serveur (`0063`,
// `0064`), et ce fichier vérifie qu'on ne peut plus les franchir depuis une
// session ordinaire.
//
// Chaque test part de `client2`, qui a réellement laissé un avis sur Bogolan
// Bamako dans le jeu de démonstration : c'est exactement le compte à qui la
// RLS accordait ces droits.
Future<SupabaseClient> _signIn(String usernameOrPhone) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(usernameOrPhone),
    password: 'password123',
  );
  return client;
}

void main() {
  const supplierId = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'; // Bogolan Bamako
  const productId = 'b0fe527e-1f73-55e6-b24e-4d985576d473';
  const clientAwaId = '04060d99-e34d-520e-8b75-631ff4d3c10c';

  late SupabaseClient reviewer;

  setUp(() async {
    await resetAndSeed();
    reviewer = await _signIn('client2');
  });

  tearDown(() async {
    await reviewer.dispose();
  });

  /// Lit la fiche fournisseur sans session : elle est publique en lecture,
  /// donc c'est bien l'écriture qu'on teste et non la visibilité.
  Future<Map<String, dynamic>> readSupplier() async {
    final anon = createTestSupabaseClient();
    final row = await anon
        .from('suppliers')
        .select('business_name, public_phone_numbers, rating_average, '
            'rating_count, is_open, deleted_at')
        .eq('id', supplierId)
        .single();
    await anon.dispose();
    return row;
  }

  test(
    'un client ayant laissé un avis ne peut plus toucher la fiche du '
    'fournisseur',
    () async {
      final before = await readSupplier();

      // Chacune de ces écritures passait : renommer la boutique, détourner
      // ses appels, la fermer, la supprimer, fixer sa note.
      final attempts = <String, Map<String, Object?>>{
        'nom': {'business_name': 'Boutique détournée'},
        'téléphones': {'public_phone_numbers': ['+22300000000']},
        'fermeture': {'is_open': false},
        'suppression': {'deleted_at': DateTime.now().toUtc().toIso8601String()},
        'note': {'rating_average': 1.0, 'rating_count': 9999},
      };

      for (final entry in attempts.entries) {
        // PostgREST peut refuser (droit de colonne) ou ne toucher aucune
        // ligne (policy) : les deux sont acceptables, c'est l'**effet** qui
        // compte.
        try {
          await reviewer
              .from('suppliers')
              .update(entry.value)
              .eq('id', supplierId);
        } on PostgrestException {
          // refusé d'emblée : très bien
        }
      }

      expect(
        await readSupplier(),
        before,
        reason: 'la fiche du fournisseur doit être intacte',
      );
    },
  );

  test(
    'un client ayant laissé un avis ne peut plus toucher les produits du '
    'fournisseur',
    () async {
      final anon = createTestSupabaseClient();
      final before = await anon
          .from('products')
          .select('name, price_fcfa, stock_quantity, status, rating_average')
          .eq('id', productId)
          .single();
      await anon.dispose();

      for (final patch in <Map<String, Object?>>[
        {'price_fcfa': 1},
        {'name': 'Détourné'},
        {'stock_quantity': 0},
        {'rating_average': 1.0},
      ]) {
        try {
          await reviewer.from('products').update(patch).eq('id', productId);
        } on PostgrestException {
          // refusé d'emblée : très bien
        }
      }

      final anonAfter = createTestSupabaseClient();
      final after = await anonAfter
          .from('products')
          .select('name, price_fcfa, stock_quantity, status, rating_average')
          .eq('id', productId)
          .single();
      await anonAfter.dispose();
      // Le prix compte double : `place_order` le lit dans cette table, donc
      // un prix modifiable par un client serait un prix choisi par lui.
      expect(after, before);
    },
  );

  test(
    'un compte connecté ne peut plus écrire de notification, ni pour un '
    'autre ni pour lui-même',
    () async {
      await expectLater(
        reviewer.from('notifications').insert({
          'id': 'forgee-1',
          'user_id': clientAwaId,
          'type': 'order_status_update',
          'title': 'Commande bloquée',
          'body': 'Appelez le 70 00 00 00 pour débloquer votre colis.',
        }),
        throwsA(isA<PostgrestException>()),
        reason:
            'c\'était le vecteur : un texte arbitraire, à n\'importe quel '
            'destinataire, depuis l\'intérieur de l\'app',
      );

      final theirs = await fetchNotificationsForUserAsAdmin(clientAwaId);
      expect(theirs.any((n) => n['id'] == 'forgee-1'), isFalse);
    },
  );

  test(
    'déposer un avis met bien à jour la note, et une seule fois',
    () async {
      // Le chemin légitime continue de fonctionner, et le cumul est celui
      // d'avant : la note de démonstration n'est pas écrasée.
      final before = await readSupplier();
      final beforeCount = before['rating_count'] as int;
      final beforeAverage = (before['rating_average'] as num).toDouble();

      final awa = await _signIn('client1');
      final groupRow = await awa
          .from('order_supplier_groups')
          .select('id, order_id')
          .eq('id', 'efbd44fe-a725-533d-ba6c-a9c867b161cb')
          .single();

      await awa.rpc('submit_review', params: {
        'p_order_id': groupRow['order_id'],
        'p_supplier_group_id': groupRow['id'],
        'p_stars': 5,
        'p_comment': 'Parfait.',
      });

      final after = await readSupplier();
      expect(after['rating_count'], beforeCount + 1);
      expect(
        (after['rating_average'] as num).toDouble(),
        closeTo(
          ((beforeAverage * beforeCount) + 5) / (beforeCount + 1),
          0.0001,
        ),
      );

      // Un second dépôt sur la même commande est refusé : sans quoi la note
      // se gonflerait d'un avis répété.
      await expectLater(
        awa.rpc('submit_review', params: {
          'p_order_id': groupRow['order_id'],
          'p_supplier_group_id': groupRow['id'],
          'p_stars': 5,
          'p_comment': 'Encore parfait.',
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect((await readSupplier())['rating_count'], beforeCount + 1);

      await awa.dispose();
    },
  );

  test(
    'un client ne peut pas noter la commande d\'un autre',
    () async {
      // La commande livrée d'Awa, notée par Moussa : la RPC doit refuser,
      // sinon n'importe qui noterait n'importe quelle boutique.
      final anon = createTestSupabaseClient();
      await expectLater(
        reviewer.rpc('submit_review', params: {
          'p_order_id': '8b306ef7-cb08-5523-bb49-08b41eabc9ac',
          'p_supplier_group_id': 'efbd44fe-a725-533d-ba6c-a9c867b161cb',
          'p_stars': 1,
          'p_comment': 'Pas ma commande.',
        }),
        throwsA(isA<PostgrestException>()),
      );
      await anon.dispose();
    },
  );
}
