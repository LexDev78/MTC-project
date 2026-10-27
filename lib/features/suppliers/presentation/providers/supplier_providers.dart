import '../../domain/entities/supplier_collaborator.dart';
import '../../domain/entities/supplier_dashboard_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart'
    show SupplierType;

import '../../data/datasources/supabase_supplier_datasource.dart';
import '../../data/repositories/supabase_supplier_repository.dart';
import '../../domain/entities/supplier_profile.dart';
import '../../domain/repositories/supplier_repository.dart';

final supplierDatasourceProvider = Provider<SupabaseSupplierDatasource>((ref) {
  return SupabaseSupplierDatasource(ref.watch(supabaseClientProvider));
});

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupabaseSupplierRepository(ref.watch(supplierDatasourceProvider));
});

final supplierDetailProvider = FutureProvider.family<SupplierProfile, String>((
  ref,
  id,
) {
  return ref.watch(supplierRepositoryProvider).getById(id);
});

/// L'adresse de retrait de la boutique opérée, pour l'écran qui la tient à
/// jour. La fiche de [supplierDetailProvider] ne la porte plus (`0133`).
///
/// `autoDispose` : relue à chaque ouverture de l'écran, et jamais gardée en
/// mémoire au-delà — c'est une adresse, souvent celle d'un domicile.
final myShopLocationProvider = FutureProvider.autoDispose<ShopLocation?>((
  ref,
) {
  return ref.watch(supplierRepositoryProvider).fetchMyShopLocation();
});

/// « Boutiques du Mali » : les boutiques que le client peut visiter, MTC
/// Officiel d'abord, puis les plus suivies — le nombre d'avis dit mieux
/// qu'une moyenne la confiance qu'une boutique a gagnée : un 5/5 sur un seul
/// avis ne passe pas devant 4,8 sur deux cents.
final listedShopsProvider = FutureProvider.autoDispose<List<SupplierProfile>>((
  ref,
) async {
  final boutiques = await ref.watch(supplierRepositoryProvider).fetchListed();
  return [...boutiques]..sort((a, b) {
    final officielle =
        (b.supplierType == SupplierType.principal ? 1 : 0) -
        (a.supplierType == SupplierType.principal ? 1 : 0);
    if (officielle != 0) return officielle;
    final avis = b.ratingCount.compareTo(a.ratingCount);
    if (avis != 0) return avis;
    return a.businessName.compareTo(b.businessName);
  });
});

/// Les chiffres du tableau de bord.
///
/// `autoDispose` : on les relit en entrant sur l'écran d'accueil, et on ne
/// les garde pas en mémoire pendant qu'on travaille ailleurs. Des ventes du
/// jour affichées d'hier valent moins que rien.
final supplierDashboardStatsProvider =
    FutureProvider.autoDispose<SupplierDashboardStats>((ref) {
      return ref.watch(supplierRepositoryProvider).fetchDashboardStats();
    });

/// L'équipe de la boutique.
///
/// `autoDispose` : on la relit en entrant sur l'écran. Une liste d'accès
/// gardée en mémoire pendant qu'on travaille ailleurs vieillirait sans
/// qu'on s'en aperçoive — et c'est une liste de qui peut faire quoi.
final supplierCollaboratorsProvider =
    FutureProvider.autoDispose<List<SupplierCollaborator>>((ref) {
      return ref.watch(supplierRepositoryProvider).fetchCollaborators();
    });

/// Les écritures sur l'équipe. Un `AsyncNotifier` plutôt que des appels
/// directs depuis l'écran : chaque geste doit invalider la liste, et
/// l'oublier une seule fois donnerait un écran qui ment.
class SupplierCollaboratorController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Rend le mot de passe à usage unique, ou `null` si la création a
  /// échoué. L'écran doit le montrer aussitôt : il ne se relit pas.
  Future<String?> create({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required Set<String> permissions,
  }) async {
    state = const AsyncLoading();
    ({String userId, String temporaryPassword})? cree;
    state = await AsyncValue.guard(() async {
      cree = await ref
          .read(supplierRepositoryProvider)
          .createCollaborator(
            displayName: displayName,
            usernameOrPhone: usernameOrPhone,
            phoneNumber: phoneNumber,
            permissions: permissions,
          );
    });
    if (state.hasError) return null;
    ref.invalidate(supplierCollaboratorsProvider);
    return cree?.temporaryPassword;
  }

  Future<bool> setPermissions({
    required String userId,
    required Set<String> permissions,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(supplierRepositoryProvider)
          .setCollaboratorPermissions(
            userId: userId,
            permissions: permissions,
          ),
    );
    if (!state.hasError) ref.invalidate(supplierCollaboratorsProvider);
    return !state.hasError;
  }

  Future<bool> remove(String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(supplierRepositoryProvider).removeCollaborator(userId),
    );
    if (!state.hasError) ref.invalidate(supplierCollaboratorsProvider);
    return !state.hasError;
  }

  Future<bool> reactivate(String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(supplierRepositoryProvider).reactivateCollaborator(userId),
    );
    if (!state.hasError) ref.invalidate(supplierCollaboratorsProvider);
    return !state.hasError;
  }
}

final supplierCollaboratorControllerProvider =
    AsyncNotifierProvider<SupplierCollaboratorController, void>(
      SupplierCollaboratorController.new,
    );
