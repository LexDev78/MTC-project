import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import 'app_routes.dart';

/// Role-based redirect logic, consulted by [GoRouter] on every navigation
/// attempt and whenever its `refreshListenable` fires (see `app_router.dart`,
/// which notifies on every `currentUserProvider` state change).
String? authRedirect(Ref ref, GoRouterState state) {
  final authState = ref.read(currentUserProvider);
  final path = state.uri.path;

  if (authState.isLoading) {
    return path == AppRoutes.splash ? null : AppRoutes.splash;
  }

  final user = authState.valueOrNull;
  final isAuthRoute =
      path == AppRoutes.splash ||
      path == AppRoutes.welcome ||
      path == AppRoutes.login ||
      path.startsWith(AppRoutes.signUp);

  if (user == null) {
    return isAuthRoute ? null : AppRoutes.login;
  }

  final roleHome = switch (user.role) {
    UserRole.client => AppRoutes.clientHome,
    UserRole.supplierTiers => AppRoutes.supplierTiersDashboard,
    UserRole.supplierPrincipal => AppRoutes.supplierPrincipalDashboard,
  };

  if (isAuthRoute) {
    // Fresh sign-in from the login form gets a beat on the loading
    // animation before landing on the dashboard; a restored session (app
    // launched already logged in) goes straight there.
    return ref.read(justLoggedInProvider) ? AppRoutes.loading : roleHome;
  }

  final isClientArea = path.startsWith('/client');
  final isTiersArea = path.startsWith('/supplier-tiers');
  final isPrincipalArea = path.startsWith('/supplier-principal');

  final inOwnArea = switch (user.role) {
    UserRole.client => isClientArea,
    UserRole.supplierTiers => isTiersArea,
    UserRole.supplierPrincipal => isPrincipalArea,
  };

  final inAnySupplierOrClientArea =
      isClientArea || isTiersArea || isPrincipalArea;
  if (inAnySupplierOrClientArea && !inOwnArea) return roleHome;

  return null;
}
