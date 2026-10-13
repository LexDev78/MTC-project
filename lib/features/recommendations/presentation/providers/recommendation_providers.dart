import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';

import '../../data/datasources/supabase_recommendation_datasource.dart';
import '../../data/repositories/supabase_recommendation_repository.dart';
import '../../domain/entities/suggestion_reason.dart';
import '../../domain/repositories/recommendation_repository.dart';

final recommendationDatasourceProvider =
    Provider<SupabaseRecommendationDatasource>((ref) {
      return SupabaseRecommendationDatasource(ref.watch(supabaseClientProvider));
    });

final recommendationRepositoryProvider = Provider<RecommendationRepository>((ref) {
  return SupabaseRecommendationRepository(
    ref.watch(recommendationDatasourceProvider),
    ref.watch(productRepositoryProvider),
  );
});

/// Le fil « Pour vous ».
///
/// Un `FutureProvider` et non un `StreamProvider`, contrairement au reste du
/// catalogue : le classement dépend d'un historique qui bouge à chaque
/// consultation, et le recalculer en direct ferait sauter les vignettes sous
/// le doigt du client pendant qu'il fait défiler. Le fil se recharge aux
/// moments où il est légitime qu'il change — ouverture de l'écran,
/// `ref.invalidate` sur un tirer-pour-rafraîchir, connexion d'un autre
/// compte.
///
/// Dépend de [currentUserProvider] pour cette dernière raison : sans ça, le
/// fil du compte précédent resterait affiché après un changement de session.
final recommendedFeedProvider = FutureProvider<List<ProductSuggestion>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return const [];
  return ref.watch(recommendationRepositoryProvider).fetchSuggestions();
});
