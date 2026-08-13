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
    SupplierTiersUser(:final id) => id,
    SupplierPrincipalUser() => DemoIds.supplierMtcOfficiel,
    _ => null,
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
