@Tags(['integration'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';

import '../../support/supabase_test_harness.dart';

// La structure qui rendra possible un modèle maison (`0085`, `0086`, `0087`).
//
// Rien ici n'entraîne quoi que ce soit : ce qui se vérifie, c'est ce que la
// base garantit **avant** qu'un modèle existe — que deux modèles puissent
// cohabiter sans se mélanger, que les étiquettes ne soient pas falsifiables,
// et que la mesure porte sur ce qu'elle annonce.
//
// Ces garanties comptent plus que la qualité du modèle qui viendra : un
// espace vectoriel silencieusement mélangé ou un jeu d'entraînement
// empoisonné produisent un modèle médiocre sans que rien ne le signale.

/// Un vecteur unitaire concentré sur un axe, de la dimension demandée.
///
/// Deux axes différents sont orthogonaux (similarité 0), un axe bruité reste
/// très proche de lui-même. De quoi mettre en scène « se ressemble » et
/// « n'a rien à voir » sans aucune image.
List<double> _axis(int index, {int dim = 1024, double noise = 0}) {
  final random = Random(index);
  final values = List<double>.filled(dim, 0);
  values[index % dim] = 1;
  if (noise > 0) {
    for (var i = 0; i < dim; i++) {
      values[i] += (random.nextDouble() - 0.5) * noise;
    }
  }
  final norm = sqrt(values.fold<double>(0, (s, v) => s + v * v));
  return [for (final v in values) v / norm];
}

void main() {
  const bogolan = 'b0fe527e-1f73-55e6-b24e-4d985576d473';
  const smartphone = 'b3fff077-755b-578a-b5ec-1e00139e3029';

  setUp(resetAndSeed);

  group('cohabitation de deux modèles', () {
    test('chaque modèle a son espace, et ils ne se mélangent pas', () async {
      // Le même vecteur, deux produits, deux modèles. Si les espaces se
      // mélangeaient, chaque recherche ramènerait les deux produits — et
      // comparerait des empreintes issues de modèles différents, ce qui ne
      // veut rien dire.
      await upsertEmbeddingAsAdmin(
        productId: bogolan,
        embedding: _axis(3),
        model: 'modele-a',
      );
      await upsertEmbeddingAsAdmin(
        productId: smartphone,
        embedding: _axis(3),
        model: 'modele-b',
      );

      final parA = await searchByEmbeddingAsAdmin(
        embedding: _axis(3, noise: 0.02),
        model: 'modele-a',
      );
      expect(parA.map((r) => r.productId), [bogolan]);

      final parB = await searchByEmbeddingAsAdmin(
        embedding: _axis(3, noise: 0.02),
        model: 'modele-b',
      );
      expect(parB.map((r) => r.productId), [smartphone]);
    });

    test('un modèle absent du registre est refusé', () async {
      // La faute de frappe est le pire des cas : elle créerait un troisième
      // espace vectoriel, qui ne ressortirait jamais d'une recherche et ne
      // manquerait à personne.
      await expectLater(
        _upsertRaw(
          productId: bogolan,
          embedding: _axis(3),
          model: 'voyage-multimodal-3.6',
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('une sortie de dimension inattendue est refusée', () async {
      await registerAiModelAsAdmin(name: 'maison-768', dim: 768);

      // Un modèle qui change sa sortie sans changer de nom mélangerait
      // d'anciens et de nouveaux vecteurs dans la même colonne, sous le même
      // nom. Mieux vaut l'échec.
      await expectLater(
        _upsertRaw(
          productId: bogolan,
          embedding: _axis(3, dim: 512),
          model: 'maison-768',
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('un modèle de 768 dimensions classe comme en 768 natif', () async {
      // Le remplissage par zéros ne change pas la similarité cosinus : un
      // modèle plus court que la colonne doit donc donner exactement le même
      // classement. C'est ce qui permet de ne pas migrer la colonne à chaque
      // changement de modèle.
      await registerAiModelAsAdmin(name: 'maison-768', dim: 768);
      await upsertEmbeddingAsAdmin(
        productId: bogolan,
        embedding: _axis(3, dim: 768),
        model: 'maison-768',
      );
      await upsertEmbeddingAsAdmin(
        productId: smartphone,
        embedding: _axis(500, dim: 768),
        model: 'maison-768',
      );

      final resultats = await searchByEmbeddingAsAdmin(
        embedding: _axis(3, dim: 768, noise: 0.02),
        model: 'maison-768',
      );
      expect(resultats.first.productId, bogolan);
      expect(resultats.first.similarity, greaterThan(0.9));
      expect(resultats.map((r) => r.productId), isNot(contains(smartphone)));
    });

    test('la file d\'indexation est propre à chaque modèle', () async {
      await registerAiModelAsAdmin(name: 'candidat', dim: 1024);
      final image = await _firstImageOf(bogolan);

      await upsertEmbeddingAsAdmin(
        productId: bogolan,
        embedding: _axis(3),
        sourceImageUrl: image,
      );

      // Indexé pour le modèle par défaut, donc sorti de sa file…
      final pourDefaut = await fetchProductsNeedingEmbeddingAsAdmin(
        model: 'test-model',
      );
      expect(pourDefaut.map((r) => r.productId), isNot(contains(bogolan)));

      // …mais entièrement à indexer pour le candidat. C'est ce qui permet de
      // préparer une bascule en tâche de fond.
      final pourCandidat = await fetchProductsNeedingEmbeddingAsAdmin(
        model: 'candidat',
      );
      expect(pourCandidat.map((r) => r.productId), contains(bogolan));
    });
  });

  group('le signal d\'entraînement', () {
    test('un client ne peut pas fabriquer une recherche', () async {
      // Pouvoir insérer ici, ce serait pouvoir fabriquer des exemples et des
      // étiquettes — c'est-à-dire empoisonner le modèle qu'on en tirera.
      final client = await _signIn('client1');
      await expectLater(
        client.client.from('visual_search_queries').insert({
          'user_id': client.userId,
          'image_path': 'faux/chemin.jpg',
          'model': 'test-model',
        }),
        throwsA(isA<PostgrestException>()),
      );
      await client.client.dispose();
    });

    test('on ne peut étiqueter qu\'un produit réellement proposé', () async {
      final client = await _signIn('client1');
      final queryId = await recordVisualSearchQueryAsAdmin(
        userId: client.userId,
        imagePath: '${client.userId}/photo.jpg',
        candidates: [(productId: bogolan, similarity: 0.8)],
      );

      // Le smartphone n'a jamais été proposé pour cette photo : l'associer
      // apprendrait au modèle le contraire de ce qu'on veut.
      await client.client.rpc(
        'record_visual_search_click',
        params: {'p_query_id': queryId, 'p_product_id': smartphone},
      );
      expect(await fetchVisualSearchClicksAsAdmin(queryId), isEmpty);

      // Le tissu, lui, figurait dans les résultats.
      await client.client.rpc(
        'record_visual_search_click',
        params: {'p_query_id': queryId, 'p_product_id': bogolan},
      );
      expect(await fetchVisualSearchClicksAsAdmin(queryId), [bogolan]);

      await client.client.dispose();
    });

    test('on n\'étiquette pas la recherche de quelqu\'un d\'autre', () async {
      final premier = await _signIn('client1');
      final queryId = await recordVisualSearchQueryAsAdmin(
        userId: premier.userId,
        imagePath: '${premier.userId}/photo.jpg',
        candidates: [(productId: bogolan, similarity: 0.8)],
      );
      await premier.client.dispose();

      final autre = await _signIn('client2');
      await autre.client.rpc(
        'record_visual_search_click',
        params: {'p_query_id': queryId, 'p_product_id': bogolan},
      );
      expect(await fetchVisualSearchClicksAsAdmin(queryId), isEmpty);
      await autre.client.dispose();
    });

    test('chacun voit ses recherches et peut les effacer', () async {
      final premier = await _signIn('client1');
      await recordVisualSearchQueryAsAdmin(
        userId: premier.userId,
        imagePath: '${premier.userId}/photo.jpg',
        candidates: [(productId: bogolan, similarity: 0.8)],
      );

      final autre = await _signIn('client2');
      await recordVisualSearchQueryAsAdmin(
        userId: autre.userId,
        imagePath: '${autre.userId}/photo.jpg',
        candidates: [(productId: smartphone, similarity: 0.7)],
      );

      // Une photo prise par quelqu'un reste à lui : il la voit, et lui seul.
      final vues = await premier.client
          .from('visual_search_queries')
          .select('image_path');
      expect(vues, hasLength(1));
      expect(
        (vues as List).cast<Map<String, dynamic>>().first['image_path'],
        '${premier.userId}/photo.jpg',
      );

      final effacees = await premier.client.rpc(
        'delete_my_visual_search_history',
      );
      expect(effacees, 1);
      expect(
        await premier.client.from('visual_search_queries').select(),
        isEmpty,
      );

      // Le fichier, lui, ne peut pas être supprimé en SQL : Supabase le
      // refuse, et avec raison — la ligne partirait, le blob resterait, et
      // plus rien n'en garderait la trace. La base enregistre donc
      // l'intention, que `ml/purge_queries.py` exécute (`0088`).
      expect(
        await fetchStoragePurgeQueueAsAdmin(),
        ['${premier.userId}/photo.jpg'],
      );

      // Celle de l'autre n'a pas bougé.
      expect(
        await autre.client.from('visual_search_queries').select(),
        hasLength(1),
      );

      await premier.client.dispose();
      await autre.client.dispose();
    });
  });

  group('export et mesure', () {
    test(
      'l\'export porte le clic en positif et les candidats écartés en négatifs',
      () async {
        final client = await _signIn('client1');
        final queryId = await recordVisualSearchQueryAsAdmin(
          userId: client.userId,
          imagePath: '${client.userId}/photo.jpg',
          candidates: [
            (productId: bogolan, similarity: 0.82),
            (productId: smartphone, similarity: 0.41),
          ],
        );
        await client.client.rpc(
          'record_visual_search_click',
          params: {'p_query_id': queryId, 'p_product_id': bogolan},
        );
        await client.client.dispose();

        final pairs = await exportTrainingPairsAsAdmin();
        expect(pairs, hasLength(1));

        final positifs = (pairs.first['positives'] as List)
            .cast<Map<String, dynamic>>();
        expect(positifs.map((p) => p['product_id']), [bogolan]);
        expect(positifs.single['signal'], 'click');

        // Le produit proposé et non retenu : un négatif difficile, qui
        // ressemble déjà à la photo. C'est ce qui reste à apprendre.
        expect(pairs.first['negatives'], [smartphone]);
      },
    );

    test('une mise au panier pèse plus lourd qu\'un clic', () async {
      final client = await _signIn('client1');
      final queryId = await recordVisualSearchQueryAsAdmin(
        userId: client.userId,
        imagePath: '${client.userId}/photo.jpg',
        candidates: [(productId: bogolan, similarity: 0.82)],
      );
      await client.client.rpc(
        'record_visual_search_click',
        params: {'p_query_id': queryId, 'p_product_id': bogolan},
      );
      // « A ouvert la fiche » dit qu'un résultat était crédible ; « a mis au
      // panier » dit que c'était le bon.
      await client.client.rpc(
        'log_activity_event',
        params: {'p_kind': 'cart_add', 'p_product_id': bogolan},
      );
      await client.client.dispose();

      final pairs = await exportTrainingPairsAsAdmin();
      final positifs = (pairs.single['positives'] as List)
          .cast<Map<String, dynamic>>();
      final poids = {
        for (final p in positifs) p['signal'] as String: p['weight'] as num,
      };
      expect(poids['click'], 1);
      expect(poids['cart_add'], greaterThan(poids['click']!));
    });

    test('une recherche sans étiquette n\'est pas exportée', () async {
      final client = await _signIn('client1');
      await recordVisualSearchQueryAsAdmin(
        userId: client.userId,
        imagePath: '${client.userId}/photo.jpg',
        candidates: [(productId: bogolan, similarity: 0.82)],
      );
      await client.client.dispose();

      // Sans positif, il n'y a rien à quoi opposer les négatifs.
      expect(await exportTrainingPairsAsAdmin(), isEmpty);
    });

    test('les photos de l\'étalon sortent de l\'entraînement', () async {
      final client = await _signIn('client1');
      final queryId = await recordVisualSearchQueryAsAdmin(
        userId: client.userId,
        imagePath: '${client.userId}/photo.jpg',
        candidates: [
          (productId: bogolan, similarity: 0.82),
          (productId: smartphone, similarity: 0.41),
        ],
      );
      await client.client.rpc(
        'record_visual_search_click',
        params: {'p_query_id': queryId, 'p_product_id': bogolan},
      );
      await client.client.dispose();

      expect(await exportTrainingPairsAsAdmin(), hasLength(1));

      // Promue au rang d'étalon, la photo quitte l'entraînement. C'est cette
      // seule condition qui empêche de mesurer un modèle sur ce qu'il a déjà
      // vu — et donc d'annoncer un succès qui ne se reproduira pas.
      expect(await promoteQueriesToEvalAsAdmin(), 1);
      expect(await exportTrainingPairsAsAdmin(), isEmpty);
    });

    test('une recherche à deux clics ne devient pas un étalon', () async {
      final client = await _signIn('client1');
      final queryId = await recordVisualSearchQueryAsAdmin(
        userId: client.userId,
        imagePath: '${client.userId}/photo.jpg',
        candidates: [
          (productId: bogolan, similarity: 0.82),
          (productId: smartphone, similarity: 0.78),
        ],
      );
      for (final produit in [bogolan, smartphone]) {
        await client.client.rpc(
          'record_visual_search_click',
          params: {'p_query_id': queryId, 'p_product_id': produit},
        );
      }
      await client.client.dispose();

      // Deux produits ouverts depuis la même photo : la personne hésitait.
      // Un étalon se construit sur des cas nets.
      expect(await promoteQueriesToEvalAsAdmin(), 0);
      expect(await fetchEvalExamplesAsAdmin(), isEmpty);
    });

    test('la note d\'un modèle reflète le rang du bon produit', () async {
      // Deux photos d'étalon : la première désigne le tissu, la seconde le
      // smartphone. Les deux empreintes de requête pointeront vers le tissu
      // — donc une réponse juste, une fausse.
      final client = await _signIn('client1');
      for (final cas in [
        (chemin: 'photo-tissu.jpg', attendu: bogolan),
        (chemin: 'photo-tel.jpg', attendu: smartphone),
      ]) {
        final queryId = await recordVisualSearchQueryAsAdmin(
          userId: client.userId,
          imagePath: '${client.userId}/${cas.chemin}',
          candidates: [(productId: cas.attendu, similarity: 0.8)],
        );
        await client.client.rpc(
          'record_visual_search_click',
          params: {'p_query_id': queryId, 'p_product_id': cas.attendu},
        );
      }
      await client.client.dispose();
      expect(await promoteQueriesToEvalAsAdmin(), 2);

      await upsertEmbeddingAsAdmin(
        productId: bogolan,
        embedding: _axis(3),
        model: 'a-mesurer',
      );
      await upsertEmbeddingAsAdmin(
        productId: smartphone,
        embedding: _axis(800),
        model: 'a-mesurer',
      );

      // Les deux requêtes pointent vers l'axe du tissu.
      for (final exemple in await fetchEvalExamplesAsAdmin()) {
        await upsertEvalEmbeddingAsAdmin(
          exampleId: exemple.id,
          model: 'a-mesurer',
          embedding: _axis(3, noise: 0.02),
        );
      }

      final note = await evaluateModelRecallAsAdmin(model: 'a-mesurer', k: 1);
      expect(note.examples, 2);
      // Le tissu est trouvé au rang 1, le smartphone au rang 2.
      expect(note.found, 1);
      expect(note.recall, closeTo(0.5, 0.001));
      // MRR = (1/1 + 1/2) / 2 : il distingue ce que recall@1 confond.
      expect(note.mrr, closeTo(0.75, 0.001));
    });
  });
}

/// Une session cliente, avec son identifiant — celui que la fonction edge
/// transmettrait après avoir validé le jeton.
Future<({SupabaseClient client, String userId})> _signIn(String username) async {
  final client = createTestSupabaseClient();
  final session = await client.auth.signInWithPassword(
    email: pseudoEmail(username),
    password: 'password123',
  );
  return (client: client, userId: session.user!.id);
}

/// L'écriture sans passer par le harnais, pour vérifier ce que la base
/// refuse — le harnais déclare le modèle au passage, ce qui masquerait
/// justement le refus attendu.
Future<void> _upsertRaw({
  required String productId,
  required List<double> embedding,
  required String model,
}) => upsertEmbeddingRawAsAdmin(
  productId: productId,
  embedding: embedding,
  model: model,
);

Future<String> _firstImageOf(String productId) async {
  final anon = createTestSupabaseClient();
  final row = await anon
      .from('products')
      .select('image_urls')
      .eq('id', productId)
      .single();
  await anon.dispose();
  return (row['image_urls'] as List).first as String;
}
