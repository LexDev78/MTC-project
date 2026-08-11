import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Minimal landing screen for the "Fournisseur tiers" role this pass.
/// Product/stock management, delivery-mode choices, and order handling for
/// this role are built in a later iteration — the domain seams already
/// exist (see `catalog`/`orders` repositories) so that work is additive.
class SupplierTiersDashboardScreen extends ConsumerWidget {
  const SupplierTiersDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace fournisseur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Déconnexion',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user is SupplierTiersUser) ...[
              Text(
                'Bienvenue, ${user.businessName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              _VerificationBadge(status: user.verificationStatus),
              const SizedBox(height: AppSpacing.sm),
              MtcRatingStars(
                rating: user.ratingAverage,
                ratingCount: user.ratingCount,
              ),
            ],
            const Expanded(
              child: MtcComingSoon(
                title: 'Tableau de bord fournisseur — bientôt disponible',
                subtitle:
                    'La gestion des produits, du stock et des livraisons arrive dans une prochaine mise à jour.',
              ),
            ),
          ],
        ),
      ),
      backgroundColor: scheme.surface,
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
