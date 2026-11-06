@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';

import '../../support/supabase_test_harness.dart';

// Le rapport du 06/11/2026 (`0153`), mené comme lui : par l'API, avec la
// seule clé publique de l'app. Le détail de chaque règle est dans
// `supabase/snippets/verif_0153.sql` ; ici, ce que de vraies requêtes —
// une seule qui en porte deux cents, ou trente à la fois — peuvent encore
// faire.
Future<SupabaseClient> _connecte(String identifiant) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(identifiant),
    password: 'password123',
  );
  addTearDown(client.dispose);
  return client;
}

Future<String> _varianteParDefaut(String productId) async {
  final client = createTestSupabaseClient();
  addTearDown(client.dispose);
  final row = await client
      .from('product_variants')
      .select('id')
      .eq('product_id', productId)
      .eq('is_default', true)
      .single();
  return row['id'] as String;
}

Future<int> _stock(String varianteId) async {
  final client = createTestSupabaseClient();
  addTearDown(client.dispose);
  final row = await client
      .from('product_variants')
      .select('stock_quantity')
      .eq('id', varianteId)
      .single();
  return row['stock_quantity'] as int;
}

/// Une commande d'un seul article, livrée par la boutique.
Future<String> _commander(
  SupabaseClient client, {
  required String produit,
  required String boutique,
  required String variante,
  int quantite = 1,
}) async {
  return await client.rpc(
        'place_order',
        params: {
          'p_client_display_name_snapshot': 'x',
          'p_client_phone_snapshot': '+22370000002',
          'p_groups': [
            {
              'supplier_id': boutique,
              'supplier_name': 'x',
              'delivery_mode': 'self_delivery',
              'items': [
                {
                  'product_id': produit,
                  'variant_id': variante,
                  'quantity': quantite,
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
      )
      as String;
}

Matcher _refusAvec(String extrait) => throwsA(
  isA<PostgrestException>().having((e) => e.message, 'message', contains(extrait)),
);

/// Ce que [action] a donné : `null` si elle passe, le message sinon.
Future<String?> _issue(Future<Object?> Function() action) async {
  try {
    await action();
    return null;
  } on PostgrestException catch (e) {
    return e.message;
  }
}

Future<int> _notificationsDeLaBoutique(
  SupabaseClient boutique,
  String type,
  String reference,
) async {
  final rows = await boutique
      .from('notifications')
      .select('id')
      .eq('type', type)
      .eq('reference_id', reference);
  return rows.length;
}

void main() {
  setUp(resetAndSeed);

  group('le stock retenu par une commande non payée', () {
    test('onze sacs de riz non payés sont refusés, dix passent', () async {
      final moussa = await _connecte('client2');
      final riz = await _varianteParDefaut(DemoIds.product015);
      // Assez de stock pour que ce soit le plafond, pas la rupture, qui
      // refuse.
      await adjustVariantStockAsAdmin(variantId: riz, quantityDelta: 50);
      final avant = await _stock(riz);

      await expectLater(
        _commander(
          moussa,
          produit: DemoIds.product015,
          boutique: DemoIds.supplierAlimentationSegou,
          variante: riz,
          quantite: 11,
        ),
        _refusAvec('10 exemplaires au plus par client'),
      );
      expect(await _stock(riz), avant, reason: 'la commande refusée ne retient rien');

      await _commander(
        moussa,
        produit: DemoIds.product015,
        boutique: DemoIds.supplierAlimentationSegou,
        variante: riz,
        quantite: 10,
      );
      expect(await _stock(riz), avant - 10);
    });

    test('six commandes simultanées chez une boutique : trois passent', () async {
      final moussa = await _connecte('client2');
      final boubou = await _varianteParDefaut(DemoIds.product002);
      final avant = await _stock(boubou);

      final issues = await Future.wait(
        List.generate(
          6,
          (_) => _issue(
            () => _commander(
              moussa,
              produit: DemoIds.product002,
              boutique: DemoIds.supplierBogolanBamako,
              variante: boubou,
            ),
          ),
        ),
      );

      expect(issues.where((m) => m == null), hasLength(3), reason: '$issues');
      expect(
        issues.whereType<String>(),
        everyElement(contains('Vous avez déjà 3 commandes en cours chez Bogolan Bamako')),
      );
      expect(await _stock(boubou), avant - 3);
    });

    test('une commande que la boutique ne confirme pas sous 24 h s\'annule et rend son stock', () async {
      final awa = await _connecte('client1');
      final boubou = await _varianteParDefaut(DemoIds.product002);
      final avant = await _stock(boubou);
      final commande = await _commander(
        awa,
        produit: DemoIds.product002,
        boutique: DemoIds.supplierBogolanBamako,
        variante: boubou,
      );
      expect(await _stock(boubou), avant - 1);

      // Une heure de moins que le délai : rien ne bouge.
      await ageOrderAsAdmin(orderId: commande, hours: 23);
      expect(await cancelUnconfirmedOrdersAsAdmin(), 0);

      await ageOrderAsAdmin(orderId: commande, hours: 25);
      expect(await cancelUnconfirmedOrdersAsAdmin(), 1);

      final groupe = await awa
          .from('order_supplier_groups')
          .select('status, cancelled_by, cancellation_reason')
          .eq('order_id', commande)
          .single();
      expect(groupe['status'], 'cancelled');
      expect(groupe['cancelled_by'], 'mtc');
      expect(groupe['cancellation_reason'], 'la boutique ne l\'a pas confirmée sous 24 h');
      expect(await _stock(boubou), avant);

      final avis = await awa
          .from('notifications')
          .select('body')
          .eq('reference_id', commande)
          .eq('type', 'order_status_update');
      expect(
        avis.map((n) => n['body']),
        contains('Votre commande a été annulée : la boutique ne l\'a pas confirmée sous 24 h.'),
      );
    });
  });

  group('le rythme des messages et des commentaires', () {
    test('deux cents messages en une requête sont refusés en bloc', () async {
      final awa = await _connecte('client1');
      Future<int> combien() async => (await awa
              .from('chat_messages')
              .select('id')
              .eq('conversation_id', DemoIds.convAwaBogolan))
          .length;
      final avant = await combien();

      await expectLater(
        awa.from('chat_messages').insert([
          for (var i = 0; i < 200; i++)
            {
              'id': 'rythme-lot-$i',
              'conversation_id': DemoIds.convAwaBogolan,
              'sender_id': DemoIds.clientAwa,
              'text': 'Message $i',
            },
        ]),
        _refusAvec('Vous envoyez trop de messages à la suite'),
      );
      expect(await combien(), avant);
    });

    test('trente envois simultanés : vingt passent, et la boutique n\'est notifiée qu\'une fois', () async {
      final awa = await _connecte('client1');
      final bogolan = await _connecte('fournisseur1');
      final avant = await _notificationsDeLaBoutique(
        bogolan,
        'new_message',
        DemoIds.convAwaBogolan,
      );

      final issues = await Future.wait(
        List.generate(
          30,
          (i) => _issue(
            () => awa.from('chat_messages').insert({
              'id': 'rythme-$i',
              'conversation_id': DemoIds.convAwaBogolan,
              'sender_id': DemoIds.clientAwa,
              'text': 'Message $i',
            }),
          ),
        ),
      );

      expect(issues.where((m) => m == null), hasLength(20), reason: '$issues');
      expect(
        await _notificationsDeLaBoutique(bogolan, 'new_message', DemoIds.convAwaBogolan),
        avant + 1,
      );
    });

    test('deux cents commentaires en une requête sont refusés, un commentaire passe', () async {
      final awa = await _connecte('client1');
      final bogolan = await _connecte('fournisseur1');
      Map<String, dynamic> commentaire(String id) => {
        'id': id,
        'product_id': DemoIds.product002,
        'supplier_id': DemoIds.supplierBogolanBamako,
        'author_id': DemoIds.clientAwa,
        'author_name': 'Awa',
        'text': 'Encore une question',
      };
      final avant = await _notificationsDeLaBoutique(
        bogolan,
        'new_comment',
        DemoIds.product002,
      );

      await expectLater(
        awa.from('product_comments').insert([
          for (var i = 0; i < 200; i++) commentaire('rythme-com-$i'),
        ]),
        _refusAvec('Vous envoyez trop de commentaires à la suite'),
      );
      expect(
        await _notificationsDeLaBoutique(bogolan, 'new_comment', DemoIds.product002),
        avant,
      );

      await awa.from('product_comments').insert(commentaire('rythme-com-seul'));
      expect(
        await _notificationsDeLaBoutique(bogolan, 'new_comment', DemoIds.product002),
        avant + 1,
      );
    });

    // Les messages d'une conversation se suivent déjà — la garde de
    // fermeture verrouille la conversation. Rien de tel sous un produit :
    // seul le verrou de `throttle_posts` tient le compte quand trente
    // requêtes arrivent ensemble.
    test('trente commentaires simultanés : dix passent', () async {
      final awa = await _connecte('client1');
      final issues = await Future.wait(
        List.generate(
          30,
          (i) => _issue(
            () => awa.from('product_comments').insert({
              'id': 'rythme-par-$i',
              'product_id': DemoIds.product002,
              'supplier_id': DemoIds.supplierBogolanBamako,
              'author_id': DemoIds.clientAwa,
              'author_name': 'Awa',
              'text': 'Question $i',
            }),
          ),
        ),
      );
      expect(issues.where((m) => m == null), hasLength(10), reason: '$issues');
    });
  });
}
