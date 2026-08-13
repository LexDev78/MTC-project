import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/supplier_onboarding/presentation/providers/supplier_kyc_providers.dart';

/// "Tableau de bord" tab — the first branch of `SupplierShell`, shared by
/// both supplier roles. Content is role-specific (verification state for a
/// fournisseur tiers, the KYC review entry point for MTC staff); the other
/// five tabs stay identical between roles, see `SupplierShell`.
class SupplierHomeScreen extends ConsumerWidget {
  const SupplierHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: switch (user) {
          SupplierTiersUser() => _TiersHome(user: user),
          SupplierPrincipalUser() => _PrincipalHome(user: user),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _TiersHome extends StatelessWidget {
  const _TiersHome({required this.user});

  final SupplierTiersUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenue, ${user.businessName}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        _VerificationBadge(status: user.verificationStatus),
        const SizedBox(height: AppSpacing.sm),
        MtcRatingStars(rating: user.ratingAverage, ratingCount: user.ratingCount),
        // `unverified` never reaches this screen — the router forces it
        // straight to the onboarding wizard (see `route_guards.dart`). Only
        // `rejected` needs a way back in.
        if (user.verificationStatus == VerificationStatus.rejected) ...[
          const SizedBox(height: AppSpacing.md),
          MtcPrimaryButton(
            label: 'Corriger mon dossier',
            onPressed: () => context.push(AppRoutes.supplierOnboarding),
          ),
        ],
      ],
    );
  }
}

class _PrincipalHome extends ConsumerWidget {
  const _PrincipalHome({required this.user});

  final SupplierPrincipalUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenue, ${user.displayName}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        RoleBadge(
          label: user.staffRole == StaffRole.admin ? 'Administrateur' : 'Agent',
          color: Theme.of(context).colorScheme.primary,
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        const _KycQueueButton(),
      ],
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      VerificationStatus.verified => RoleBadge(
        label: 'Identité vérifiée',
        color: scheme.primary,
        icon: Icons.verified_rounded,
      ),
      VerificationStatus.pending => RoleBadge(
        label: 'Vérification en cours',
        color: scheme.tertiary,
        icon: Icons.hourglass_top_rounded,
      ),
      VerificationStatus.rejected => RoleBadge(
        label: 'Vérification refusée',
        color: scheme.error,
        icon: Icons.error_outline_rounded,
      ),
      VerificationStatus.unverified => RoleBadge(
        label: 'Non vérifié',
        color: scheme.onSurfaceVariant,
        icon: Icons.help_outline_rounded,
      ),
    };
  }
}

class _KycQueueButton extends ConsumerWidget {
  const _KycQueueButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(kycReviewQueueProvider).valueOrNull ?? const [];
    return OutlinedButton.icon(
      onPressed: () => context.push(AppRoutes.supplierPrincipalKycQueue),
      icon: const Icon(Icons.fact_check_outlined),
      label: Text(
        queue.isEmpty
            ? 'Vérification des fournisseurs'
            : 'Vérification des fournisseurs (${queue.length})',
      ),
    );
  }
}
