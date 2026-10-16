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

  // A supplier tiers with no KYC dossier submitted yet has nothing to
  // manage — its "home" is the onboarding wizard, not the dashboard.
  // `rejected` still goes to the dashboard (it surfaces the rejection
  // reason with a way back into the wizard); `pending`/`verified` do too.
  final needsOnboarding = user is SupplierTiersUser && user.needsOnboarding;

  final roleHome = switch (user.role) {
    UserRole.client => AppRoutes.clientHome,
    UserRole.supplierTiers => needsOnboarding
        ? AppRoutes.supplierOnboarding
        : AppRoutes.supplierTiersDashboard,
    UserRole.supplierPrincipal => AppRoutes.supplierPrincipalDashboard,
    // Un livreur non encore validé atterrit sur la même liste : elle porte
    // le message d'attente. Lui réserver un écran à part doublerait les
    // chemins pour un état qui dure le temps d'une validation.
    UserRole.livreur => AppRoutes.courierHome,
  };

  // Avant tout le reste, y compris le dossier de vérification : tant que le
  // code dicté par le patron n'est pas remplacé, ce compte n'est à
  // personne — il le connaît, et quiconque était à portée de voix aussi.
  if (user is SupplierTiersUser && user.mustChangePassword) {
    return path == AppRoutes.changePassword ? null : AppRoutes.changePassword;
  }
  // Et une fois changé, cet écran n'a plus lieu d'être : y revenir par
  // l'historique renverrait sur un formulaire sans objet.
  if (path == AppRoutes.changePassword) return roleHome;

  if (isAuthRoute) {
    // Fresh sign-in from the login form gets a beat on the loading
    // animation before landing on the dashboard; a restored session (app
    // launched already logged in) goes straight there.
    return ref.read(justLoggedInProvider) ? AppRoutes.loading : roleHome;
  }

  final isClientArea = path.startsWith('/client');
  final isTiersArea = path.startsWith('/supplier-tiers');
  final isPrincipalArea = path.startsWith('/supplier-principal');
  final isCourierArea = path.startsWith('/livreur');

  final inOwnArea = switch (user.role) {
    UserRole.client => isClientArea,
    UserRole.supplierTiers => isTiersArea,
    UserRole.supplierPrincipal => isPrincipalArea,
    UserRole.livreur => isCourierArea,
  };

  final inAnyRoleArea =
      isClientArea || isTiersArea || isPrincipalArea || isCourierArea;
  if (inAnyRoleArea && !inOwnArea) return roleHome;

  if (user is SupplierTiersUser) {
    final onOnboarding = path == AppRoutes.supplierOnboarding;
    if (needsOnboarding && !onOnboarding) return AppRoutes.supplierOnboarding;
    // Nothing left to do in the wizard once a dossier has at least been
    // submitted once — `pending`/`verified` can't navigate back to it.
    // `rejected` is deliberately excluded here so it stays reachable.
    final doneWithOnboarding =
        user.verificationStatus == VerificationStatus.pending ||
        user.verificationStatus == VerificationStatus.verified;
    if (doneWithOnboarding && onOnboarding) {
      return AppRoutes.supplierTiersDashboard;
    }

    // Un collaborateur n'arrive pas, par une adresse, là où son patron ne
    // lui a pas donné accès. La coquille masque déjà l'onglet ; ceci ferme
    // le chemin direct — une notification qui mène à une commande, un lien
    // repris d'une session précédente.
    //
    // La base refuserait de toute façon, mais elle refuserait **après**
    // avoir ouvert un écran vide : le collaborateur y verrait une panne
    // plutôt qu'une permission manquante.
    if (!user.isOwner) {
      final interdite = _permissionManquante(user, path);
      if (interdite) return AppRoutes.supplierTiersDashboard;
    }
  }

  return null;
}

/// Vrai si [path] appartient à une partie de l'interface fournisseur que ce
/// collaborateur n'a pas le droit d'ouvrir.
///
/// Les préfixes suivent les branches déclarées dans `app_router.dart`. Le
/// tableau de bord et le profil n'y figurent pas : ils restent ouverts à
/// tous, leur contenu se restreignant de lui-même.
bool _permissionManquante(SupplierTiersUser user, String path) {
  // Les préfixes les plus longs d'abord : `/account/promotions` doit être
  // jugé sur « remises », pas sur la règle plus large de `/account`.
  const parties = <String, String>{
    '/supplier-tiers/account/promotions': 'promotions',
    '/supplier-tiers/account/promo-codes': 'promotions',
    '/supplier-tiers/account/reviews': 'reviews',
    '/supplier-tiers/account/location': 'storefront',
    '/supplier-tiers/products': 'products',
    '/supplier-tiers/orders': 'orders',
    '/supplier-tiers/messages': 'messages',
  };
  for (final entry in parties.entries) {
    if (path.startsWith(entry.key) && !user.can(entry.value)) return true;
  }

  // Ces trois-là ne s'accordent jamais, quelle que soit la case cochée :
  // l'argent, le dossier qui engage l'identité du patron, et la gestion de
  // l'équipe — sans quoi le premier invité évincerait celui qui l'a fait
  // entrer.
  const jamais = [
    '/supplier-tiers/finances',
    '/supplier-tiers/account/collaborators',
    '/supplier-tiers/onboarding',
  ];
  return jamais.any(path.startsWith);
}
