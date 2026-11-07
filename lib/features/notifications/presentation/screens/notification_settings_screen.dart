import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';

import '../../domain/entities/notification_preferences.dart';
import '../controllers/notification_preferences_controller.dart';

/// Les réglages de notification, d'après la maquette « Notifications » du
/// kit : le maître interrupteur, puis une ligne par sorte de notification
/// que le client reçoit vraiment, et « Réinitialiser » pour tout rouvrir.
///
/// Les sortes que MTC n'envoie pas (promotions, localisation, paiements)
/// n'ont pas d'interrupteur : il ne commanderait rien.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _enregistrer(
    BuildContext context,
    WidgetRef ref,
    NotificationPreferences suivants,
  ) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationPreferencesProvider.notifier).save(suivants);
    } catch (erreur) {
      messager.showSnackBar(
        SnackBar(
          content: Text(
            messagePourUtilisateur(
              erreur,
              repli: 'Le réglage n\'a pas pu être enregistré.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reglages = ref.watch(notificationPreferencesProvider);
    final actuels = reglages.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: actuels == null || actuels.isAllOn
                ? null
                : () =>
                      _enregistrer(context, ref, NotificationPreferences.allOn),
            child: const Text('Réinitialiser'),
          ),
          const SizedBox(width: ShopSizes.padding / 2),
        ],
      ),
      body: reglages.when(
        skipLoadingOnReload: true,
        loading: () => ListView(
          padding: const EdgeInsets.all(ShopSizes.screenMargin),
          children: [
            for (var i = 0; i < 4; i++) ...[
              const Skeleton(height: 48),
              const SizedBox(height: ShopSizes.padding * 1.5),
            ],
          ],
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'Vos réglages n\'ont pas pu être chargés',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(notificationPreferencesProvider),
            child: const Text('Réessayer'),
          ),
        ),
        data: (p) {
          // Coupées en bloc : les lignes gardent leur réglage pour le jour
          // où l'on rouvre, mais ne se touchent plus.
          ValueChanged<bool>? si(
            NotificationPreferences Function(bool) suivants,
          ) =>
              p.enabled ? (v) => _enregistrer(context, ref, suivants(v)) : null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.screenMargin,
              ShopSizes.padding / 2,
              ShopSizes.screenMargin,
              ShopSizes.screenMargin,
            ),
            children: [
              ShopSwitchTile(
                title: 'Autoriser les notifications',
                subtitle:
                    'Coupées, plus rien n\'arrive : ni dans la liste, ni sur '
                    'votre téléphone.',
                value: p.enabled,
                onChanged: (v) =>
                    _enregistrer(context, ref, p.copyWith(enabled: v)),
              ),
              Opacity(
                opacity: p.enabled ? 1 : 0.4,
                child: Column(
                  children: [
                    ShopSwitchTile(
                      title: 'Suivi de mes commandes',
                      subtitle:
                          'Confirmation, préparation, livraison ou annulation '
                          'de vos commandes.',
                      value: p.orderUpdates,
                      onChanged: si((v) => p.copyWith(orderUpdates: v)),
                    ),
                    ShopSwitchTile(
                      title: 'Messages des boutiques',
                      subtitle: 'Quand une boutique vous écrit.',
                      value: p.messages,
                      onChanged: si((v) => p.copyWith(messages: v)),
                    ),
                    ShopSwitchTile(
                      title: 'Réponses à vos commentaires',
                      subtitle:
                          'Quand on vous répond sous un produit que vous avez '
                          'commenté.',
                      value: p.comments,
                      onChanged: si((v) => p.copyWith(comments: v)),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ShopSizes.padding * 1.5),
              Text(
                'Une notification coupée n\'est ni affichée, ni envoyée. Vos '
                'commandes restent toujours visibles dans « Mes commandes ».',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
        },
      ),
    );
  }
}
