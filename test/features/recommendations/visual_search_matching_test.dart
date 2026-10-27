@Tags(['integration'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';

import '../../support/supabase_test_harness.dart';

// Le rapprochement d'une photo avec le catalogue (`0084`).
//
// Aucun modèle n'est appelé ici, et c'est délibéré : ce qui se vérifie est
// ce que la **base** garantit une fois l'empreinte calculée — l'ordre des
// résultats, le seuil qui évite de présenter du hasard, et les produits qui
// n'ont rien à y faire. La qualité du vecteur, elle, dépend du fournisseur
// de modèle et ne se teste pas ici.

/// Un vecteur unitaire de la dimension attendue, concentré sur un axe.
///
/// Deux axes différents donnent des vecteurs orthogonaux (similarité 0) ;
/// un axe légèrement bruité reste très proche de lui-même. De quoi mettre
/// en scène « se ressemble » et « n'a rien à voir » sans aucune image.
List<double> _axis(int index, {double noise = 0}) {
  final random = Random(index);
  final values = List<double>.filled(1024, 0);
  values[index] = 1;
  if (noise > 0) {
    for (var i = 0; i < 1024; i++) {
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

  test(
    'une photo proche d\'un produit le ramène en tête, loin devant les autres',
    () async {
      await upsertEmbeddingAsAdmin(productId: bogolan, embedding: _axis(3));
      await upsertEmbeddingAsAdmin(productId: smartphone, embedding: _axis(800));

      // La photo d'un tissu : presque le vecteur du tissu, un peu bruité.
      final resultats = await searchByEmbeddingAsAdmin(
        embedding: _axis(3, noise: 0.02),
      );

      expect(resultats, isNotEmpty);
      expect(resultats.first.productId, bogolan);
      expect(resultats.first.similarity, greaterThan(0.9));
      // Le smartphone est orthogonal : il tombe sous le seuil et n'est pas
      // proposé du tout.
      expect(resultats.map((r) => r.productId), isNot(contains(smartphone)));
    },
  );

  test(
    'une photo sans rapport ne ramène rien plutôt que les moins éloignés',
    () async {
      await upsertEmbeddingAsAdmin(productId: bogolan, embedding: _axis(3));
      await upsertEmbeddingAsAdmin(productId: smartphone, embedding: _axis(800));

      // Un axe qu'aucun produit n'occupe. Sans seuil, la base rendrait
      // quand même les deux : du hasard présenté comme un résultat.
      final resultats = await searchByEmbeddingAsAdmin(embedding: _axis(500));
      expect(resultats, isEmpty);
    },
  );

  test(
    'un produit retiré de la vente ne ressort pas d\'une recherche par photo',
    () async {
      await upsertEmbeddingAsAdmin(productId: bogolan, embedding: _axis(3));

      final avant = await searchByEmbeddingAsAdmin(
        embedding: _axis(3, noise: 0.02),
      );
      expect(avant.map((r) => r.productId), contains(bogolan));

      // Le fournisseur met son produit en pause. Son empreinte reste en
      // base — la recalculer à chaque changement de statut n'aurait aucun
      // sens — donc c'est la recherche qui doit l'écarter.
      final supplier = createTestSupabaseClient();
      await supplier.auth.signInWithPassword(
        email: pseudoEmail('fournisseur1'),
        password: 'password123',
      );
      await supplier
          .from('products')
          .update({'status': 'paused'})
          .eq('id', bogolan);
      await supplier.dispose();

      final apres = await searchByEmbeddingAsAdmin(
        embedding: _axis(3, noise: 0.02),
      );
      expect(apres.map((r) => r.productId), isNot(contains(bogolan)));
    },
  );

  test('les empreintes ne sont lisibles par personne', () async {
    await upsertEmbeddingAsAdmin(productId: bogolan, embedding: _axis(3));

    // Ni connecté, ni anonyme : les vecteurs du catalogue n'ont aucune
    // raison de quitter la base, et les exposer livrerait son empreinte à
    // qui sait lire du JSON (`0083`).
    final client = createTestSupabaseClient();
    await client.auth.signInWithPassword(
      email: pseudoEmail('client1'),
      password: 'password123',
    );
    await expectLater(
      client.from('product_embeddings').select(),
      throwsA(isA<PostgrestException>()),
    );
    await client.dispose();

    final anon = createTestSupabaseClient();
    await expectLater(
      anon.from('product_embeddings').select(),
      throwsA(isA<PostgrestException>()),
    );
    await anon.dispose();
  });

  test(
    'la file d\'indexation ne retient que ce qui a besoin d\'être indexé',
    () async {
      final admin = createTestSupabaseClient();
      await admin.auth.signInWithPassword(
        email: pseudoEmail('fournisseur1'),
        password: 'password123',
      );
      await admin.dispose();

      final avant = await _needingEmbedding();
      expect(avant, contains(bogolan));

      await upsertEmbeddingAsAdmin(
        productId: bogolan,
        embedding: _axis(3),
        sourceImageUrl: await _firstImageOf(bogolan),
      );

      // Indexé depuis la photo courante : il sort de la file.
      expect(await _needingEmbedding(), isNot(contains(bogolan)));
    },
  );
}

Future<List<String>> _needingEmbedding() async {
  final rows = await fetchProductsNeedingEmbeddingAsAdmin();
  return [for (final row in rows) row.productId];
}

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
