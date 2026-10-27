import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

/// Which `supplierId` the signed-in user's product/order/finance/message
/// screens operate on. A fournisseur tiers manages their own account
/// (`supplierId == user.id`, a 1:1 relationship); every "fournisseur
/// principal" staff member (agent or admin) instead shares one single
/// storefront — the official MTC catalog — the same way several employees
/// share one shop. This is what lets `SupplierShell`'s six tabs reuse the
/// exact same screens for both roles: the screens read this provider
/// instead of `currentUser.id` directly.
final operatingSupplierIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return switch (user) {
    // `shopId` et non `id` : un collaborateur opère la boutique de son
    // patron (`0093`). Rendre son propre identifiant le renverrait vers une
    // boutique qui n'existe pas, et tous les écrans d'ici afficheraient du
    // vide sans dire pourquoi.
    final SupplierTiersUser u => u.shopId,
    SupplierPrincipalUser() => DemoIds.supplierMtcOfficiel,
    _ => null,
  };
});

/// Ce que le compte connecté a le droit de faire sur la boutique qu'il
/// opère — voir `SupplierTiersAccess`.
///
/// Les écrans s'en servent pour masquer ce qui serait de toute façon refusé
/// par la base : un bouton qui mène à un refus est pire qu'un bouton
/// absent. Les policies restent la vraie garde ; ceci n'est que de la
/// politesse.
final supplierCanProvider = Provider.family<bool, String>((ref, permission) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return switch (user) {
    final SupplierTiersUser u => u.can(permission),
    // Le staff MTC opère la boutique officielle sans restriction.
    SupplierPrincipalUser() => true,
    _ => false,
  };
});

/// Vrai si le compte connecté **possède** la boutique, par opposition à y
/// collaborer. Garde les quatre gestes qui ne se délèguent pas : l'argent,
/// le dossier de vérification, la suppression du compte, et la gestion de
/// l'équipe.
final isSupplierOwnerProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return switch (user) {
    final SupplierTiersUser u => u.isOwner,
    SupplierPrincipalUser() => true,
    _ => false,
  };
});

/// The top-level path prefix (`/supplier-tiers` or `/supplier-principal`)
/// a screen shared by both roles should push drill-down routes under, so
/// e.g. the product list can open the product form at a route that stays
/// inside whichever shell it's currently running in (`route_guards.dart`
/// keeps the two zones separate). Defaults to the tiers prefix — the
/// fallback is never actually reached since every screen that reads this
/// is itself behind the role-gated shell.
final supplierRoutePrefixProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user is SupplierPrincipalUser
      ? '/supplier-principal'
      : '/supplier-tiers';
});
