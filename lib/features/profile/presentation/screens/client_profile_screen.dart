import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/shop/shop.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../notifications/domain/entities/notification_preferences.dart';
import '../../../notifications/presentation/controllers/notification_preferences_controller.dart';

/// Le compte du client, d'après l'écran « Profile » du kit : la carte de
/// l'utilisateur, puis les entrées par section, et la déconnexion en rouge.
///
/// Les sections du kit sans équivalent ici (retours, moyens de paiement
/// enregistrés, portefeuille, langue, aide) sont laissées de côté plutôt que
/// pointées vers des écrans vides.
///
/// Les libellés « Mes commandes », « Mes adresses », « Paramètres » et
/// « Déconnexion » sont ceux que les parcours d'intégration retrouvent.
class ClientProfileScreen extends ConsumerWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final messages = ref.watch(totalUnreadCountProvider);
    final reglages = ref.watch(notificationPreferencesProvider).valueOrNull;
    final email = ref.watch(contactEmailProvider).valueOrNull;

    Widget compte(int n) =>
        n == 0 ? const SizedBox.shrink() : CountPill(count: n);

    return Scaffold(
      // Une colonne et non une liste paresseuse : le menu est court, et
      // chaque entrée — la déconnexion tout en bas comprise — existe dès
      // l'ouverture, pour le lecteur d'écran comme pour les tests.
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: ShopSizes.padding * 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (user != null)
              ProfileCard(
                name: user.displayName,
                subtitle: email ?? user.phoneNumber,
                avatarPath: switch (user) {
                  ClientUser(:final avatarPath) => avatarPath,
                  _ => null,
                },
                onTap: () => context.push(AppRoutes.clientProfileInfo),
              ),
            const _Section('Compte'),
            ChevronListTile(
              icon: ShopIcons.order,
              title: 'Mes commandes',
              onTap: () => context.push(AppRoutes.clientOrders),
            ),
            ChevronListTile(
              icon: ShopIcons.wishlist,
              title: 'Mes favoris',
              onTap: () => context.go(AppRoutes.clientFavorites),
            ),
            ChevronListTile(
              icon: ShopIcons.address,
              title: 'Mes adresses',
              onTap: () => context.push(AppRoutes.clientProfileEdit),
            ),
            ChevronListTile(
              icon: ShopIcons.chat,
              title: 'Messages',
              trailing: compte(messages),
              showDivider: false,
              onTap: () => context.push(AppRoutes.clientChat),
            ),
            const _Section('Personnalisation'),
            ChevronListTile(
              icon: ShopIcons.notification,
              title: 'Notifications',
              // Comme « Notification — Off » dans le kit : la ligne mène aux
              // réglages et dit leur état. La liste, elle, est derrière la
              // cloche de l'en-tête.
              trailingText: switch (reglages) {
                null => null,
                NotificationPreferences(enabled: false) => 'Coupées',
                final r when r.isAllOn => 'Activées',
                _ => 'En partie',
              },
              onTap: () => context.push(AppRoutes.clientNotificationSettings),
            ),
            ChevronListTile(
              icon: ShopIcons.setting,
              title: 'Paramètres',
              showDivider: false,
              onTap: () => context.push(AppRoutes.clientSettings),
            ),
            const _Section('Sécurité'),
            ChevronListTile(
              icon: ShopIcons.message,
              title: 'Adresse e-mail',
              // L'adresse elle-même quand il y en a une : c'est la réponse
              // à « est-ce que j'en ai mis une ? », sans ouvrir l'écran.
              trailingText: email == null ? 'Ajouter' : null,
              onTap: () => context.push(AppRoutes.accountEmail),
            ),
            ChevronListTile(
              icon: ShopIcons.lock,
              title: 'Mot de passe',
              showDivider: false,
              onTap: () => context.push(AppRoutes.accountPassword),
            ),
            const SizedBox(height: ShopSizes.padding),
            ChevronListTile(
              icon: ShopIcons.logout,
              title: 'Déconnexion',
              danger: true,
              showDivider: false,
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un titre de section du menu (« Account », « Personalization » du kit).
class _Section extends StatelessWidget {
  const _Section(this.titre);

  final String titre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ShopSizes.padding,
        ShopSizes.padding * 1.5,
        ShopSizes.padding,
        ShopSizes.padding / 2,
      ),
      child: Text(titre, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
