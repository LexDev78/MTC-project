import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Minimal landing screen for MTC's own staff accounts this pass. Elevated
/// permissions (managing MTC's own catalog, handling delivery-on-behalf
/// orders) are built in a later iteration.
class SupplierPrincipalDashboardScreen extends ConsumerWidget {
  const SupplierPrincipalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MTC — Espace staff'),
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
            if (user is SupplierPrincipalUser) ...[
              Text(
                'Bienvenue, ${user.displayName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              RoleBadge(
                label: user.staffRole == StaffRole.admin
                    ? 'Administrateur'
                    : 'Agent',
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.badge_outlined,
              ),
            ],
            const Expanded(
              child: MtcComingSoon(
                title: 'Console MTC — bientôt disponible',
                subtitle:
                    'La gestion du catalogue officiel et des livraisons arrive prochainement.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
