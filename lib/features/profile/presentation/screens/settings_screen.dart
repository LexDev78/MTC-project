import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/theme_mode_controller.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/presentation/controllers/auth_controller.dart';

/// Une suppression de compte ne se fait pas d'un geste : on la confirme,
/// comme toute action définitive de l'app.
Future<void> _confirmAndDeleteAccount(
  BuildContext context,
  WidgetRef ref,
) async {
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
          style: TextButton.styleFrom(foregroundColor: ShopColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer mon compte'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final success = await ref
      .read(authControllerProvider.notifier)
      .deleteAccount();
  if (!success && context.mounted) {
    final error = ref.read(authControllerProvider).error;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(messagePourUtilisateur(error))));
  }
}

/// Les réglages du client, au style des « Preferences » du kit : le thème
/// en choix exclusif, puis la suppression du compte, en rouge.
///
/// La déconnexion est dans le menu du profil, tout en bas, comme dans le
/// kit — elle n'est plus ici.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final theme = Theme.of(context);

    void choisir(ThemeMode? mode) {
      if (mode == null) return;
      ref.read(themeModeControllerProvider.notifier).setThemeMode(mode);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ShopSizes.screenMargin,
          ShopSizes.padding,
          ShopSizes.screenMargin,
          ShopSizes.screenMargin,
        ),
        children: [
          Text('Apparence', style: theme.textTheme.titleSmall),
          const SizedBox(height: ShopSizes.padding / 2),
          Text(
            'Le thème du téléphone suit son réglage clair ou sombre.',
            style: theme.textTheme.bodyMedium,
          ),
          for (final (mode, libelle) in const [
            (ThemeMode.system, 'Thème du téléphone'),
            (ThemeMode.light, 'Clair'),
            (ThemeMode.dark, 'Sombre'),
          ])
            ShopRadioTile<ThemeMode>(
              title: libelle,
              value: mode,
              groupValue: themeMode,
              onChanged: choisir,
            ),
          const SizedBox(height: ShopSizes.padding * 2),
          Text('Compte', style: theme.textTheme.titleSmall),
          const SizedBox(height: ShopSizes.padding / 2),
          ChevronListTile(
            icon: ShopIcons.delete,
            title: 'Supprimer mon compte',
            danger: true,
            showDivider: false,
            contentPadding: EdgeInsets.zero,
            onTap: () => _confirmAndDeleteAccount(context, ref),
          ),
        ],
      ),
    );
  }
}
