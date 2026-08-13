import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

/// "Profil" tab of `SupplierShell` — the editable storefront profile
/// (description, adresse, horaires...) lands in the storefront lot. For now
/// this is where account-level actions (logout) live, matching where the
/// client role keeps them (`SettingsScreen`, reached from its own "Profil"
/// tab) rather than on the dashboard.
class SupplierAccountScreen extends ConsumerWidget {
  const SupplierAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (user != null) ...[
              Text(user.displayName, style: Theme.of(context).textTheme.titleLarge),
              Text(
                user.usernameOrPhone,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            const Expanded(
              child: MtcComingSoon(
                title: 'Profil de la boutique — bientôt disponible',
                subtitle:
                    'Description, adresse, horaires et zone de livraison arriveront ici.',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Déconnexion'),
            ),
          ],
        ),
      ),
    );
  }
}
