import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/app/theme/theme_mode_controller.dart';
import 'package:mtc_app/features/auth/presentation/controllers/auth_controller.dart';

/// Mirrors `order_detail_screen.dart`'s "Annuler cette commande ?" dialog —
/// the only other irreversible-action confirmation in the app — rather than
/// the instant, no-confirmation delete already used for a single address.
Future<void> _confirmAndDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer votre compte ?'),
      content: const Text(
        'Votre compte sera désactivé et vous serez déconnecté. Cette action '
        'est définitive.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Retour'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer mon compte'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final success = await ref.read(authControllerProvider.notifier).deleteAccount();
  if (!success && context.mounted) {
    final error = ref.read(authControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Apparence', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Système'),
                icon: Icon(Icons.brightness_auto_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Clair'),
                icon: Icon(Icons.light_mode_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Sombre'),
                icon: Icon(Icons.dark_mode_rounded),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) => ref
                .read(themeModeControllerProvider.notifier)
                .setThemeMode(selection.first),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Déconnexion'),
            contentPadding: EdgeInsets.zero,
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Supprimer mon compte',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            contentPadding: EdgeInsets.zero,
            onTap: () => _confirmAndDeleteAccount(context, ref),
          ),
        ],
      ),
    );
  }
}
