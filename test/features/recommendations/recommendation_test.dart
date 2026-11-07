@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/features/catalog/data/datasources/supabase_product_datasource.dart';
import 'package:mtc_app/features/catalog/data/repositories/supabase_product_repository.dart';
import 'package:mtc_app/features/recommendations/data/datasources/supabase_recommendation_datasource.dart';
import 'package:mtc_app/features/recommendations/data/repositories/supabase_recommendation_repository.dart';
import 'package:mtc_app/features/recommendations/domain/entities/suggestion_reason.dart';

import '../../support/supabase_test_harness.dart';

// Le fil « Pour vous » de bout en bout : les traces que l'app envoie
// (`log_activity_event`, `0081`) et le classement qui les relit
// (`get_recommended_products`, `0082`).
void main() {
  setUp(resetAndSeed);

  SupabaseRecommendationRepository repositoryFor(SupabaseClient client) =>
      SupabaseRecommendationRepository(
        SupabaseRecommendationDatasource(client),
        SupabaseProductRepository(SupabaseProductDatasource(client)),
      );

  Future<SupabaseRecommendationRepository> signIn(String identifiant) async {
    final client = createTestSupabaseClient();
    await client.auth.signInWithPassword(
      email: pseudoEmail(identifiant),
      password: 'password123',
    );
    return repositoryFor(client);
  }

  test(
    'sans session, le classement est fermé et la trace ne fait pas échouer',
    () async {
      final repository = repositoryFor(createTestSupabaseClient());

      // Fermé à `anon` (`0082`) : c'est le provider qui court-circuite
      // l'appel hors session, pas la base qui rend une liste vide.
      await expectLater(
        repository.fetchSuggestions(),
        throwsA(isA<PostgrestException>()),
      );
      // Refusé de même, mais avalé par la datasource : aucune exception ne
      // remonte jusqu'à l'écran.
      await repository.logSearch('bogolan');
    },
  );

  test(
    'un compte connecté reçoit un fil sans doublon, chaque produit justifié',
    () async {
      final repository = await signIn('client1');

      final suggestions = await repository.fetchSuggestions();

      expect(suggestions, isNotEmpty);
      final ids = [for (final s in suggestions) s.product.id];
      expect(ids.toSet(), hasLength(ids.length));
      expect(suggestions.every((s) => s.reason != null), isTrue);
    },
  );

  test('ouvrir une catégorie la fait remonter en tête du fil', () async {
    final repository = await signIn('client1');

    // Une catégorie que le fil ne propose qu'en dernier : celle du produit
    // le moins bien classé, pour que le déplacement soit visible.
    final before = await repository.fetchSuggestions();
    final target = before.last.product.category;

    for (var i = 0; i < 10; i++) {
      await repository.logCategoryOpen(target);
    }

    final after = await repository.fetchSuggestions();
    expect(after.first.reason, SuggestionReason.affinity);
    expect(after.first.product.category, target);
  });

  test(
    'un produit consulté sort de la section « d’après ce que vous consultez »',
    () async {
      final repository = await signIn('client1');

      final category =
          (await repository.fetchSuggestions()).last.product.category;
      for (var i = 0; i < 10; i++) {
        await repository.logCategoryOpen(category);
      }
      final viewed = (await repository.fetchSuggestions()).first;
      expect(viewed.reason, SuggestionReason.affinity);

      await repository.logProductView(viewed.product.id);

      final after = await repository.fetchSuggestions();
      final affinityIds = [
        for (final s in after)
          if (s.reason == SuggestionReason.affinity) s.product.id,
      ];
      expect(affinityIds, isNot(contains(viewed.product.id)));
    },
  );

  test('une trace sur un produit inconnu est ignorée sans erreur', () async {
    final repository = await signIn('client1');

    await repository.logProductView('produit-inexistant');
    await repository.logCartAdd('produit-inexistant');
    // Une recherche vide n'est même pas envoyée.
    await repository.logSearch('   ');
  });
}
