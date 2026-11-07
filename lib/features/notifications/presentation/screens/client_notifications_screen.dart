import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';

import '../../domain/entities/app_notification.dart';
import '../notification_center_logic.dart';
import '../providers/notification_providers.dart';

/// Les notifications du client, d'après les maquettes « Notification » et
/// « No notification » du kit : une pastille de couleur par sorte de
/// notification, le point orange tant qu'elle n'est pas lue, le texte et
/// son ancienneté.
///
/// Ouvrir, marquer et relire passent par `NotificationCenterLogic`, la
/// même logique que l'écran des fournisseurs.
class ClientNotificationsScreen extends ConsumerStatefulWidget {
  const ClientNotificationsScreen({super.key});

  @override
  ConsumerState<ClientNotificationsScreen> createState() =>
      _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState
    extends ConsumerState<ClientNotificationsScreen>
    with NotificationCenterLogic {
  @override
  Widget build(BuildContext context) {
    final userId = watchNotificationOwner();
    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ShopColors.primary),
        ),
      );
    }
    final notifications = ref.watch(notificationsProvider(userId));
    final liste = notifications.valueOrNull ?? const <AppNotification>[];
    final nonLues = liste.where(isUnreadHere).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Notifications'),
            if (nonLues > 0) ...[
              const SizedBox(width: ShopSizes.padding / 2),
              Semantics(
                label: nonLues == 1 ? '1 non lue' : '$nonLues non lues',
                excludeSemantics: true,
                child: CountPill(
                  key: const ValueKey('compteur-non-lues'),
                  count: nonLues,
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Réglages des notifications',
            onPressed: () => context.push(AppRoutes.clientNotificationSettings),
            icon: const ShopIcon(ShopIcons.setting),
          ),
          IconButton(
            tooltip: 'Tout marquer comme lu',
            onPressed: nonLues == 0 ? null : () => markAllRead(userId, liste),
            icon: ShopIcon(
              ShopIcons.doublecheck,
              color: nonLues == 0
                  ? Theme.of(context).iconTheme.color?.withValues(alpha: 0.3)
                  : null,
            ),
          ),
          const SizedBox(width: ShopSizes.padding / 2),
        ],
      ),
      body: notifications.when(
        skipLoadingOnReload: true,
        loading: () => ListView(
          padding: const EdgeInsets.all(ShopSizes.screenMargin),
          children: [
            for (var i = 0; i < 5; i++) ...[
              const Skeleton(height: 64),
              const SizedBox(height: ShopSizes.padding),
            ],
          ],
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'Vos notifications n\'ont pas pu être chargées',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(notificationsProvider(userId)),
            child: const Text('Réessayer'),
          ),
        ),
        data: (liste) {
          if (liste.isEmpty) {
            return const IllustratedMessage(
              illustration: ShopIllustration.noResult,
              title: 'Aucune notification',
              message:
                  'Les nouvelles de vos commandes, de vos livraisons et des '
                  'boutiques à qui vous écrivez arriveront ici.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.screenMargin,
              0,
              ShopSizes.screenMargin,
              ShopSizes.screenMargin,
            ),
            itemCount: liste.length,
            itemBuilder: (context, index) {
              final notification = liste[index];
              final (icone, couleur) = _apparence(notification.type);
              return NotificationTile(
                icon: icone,
                color: couleur,
                title: notification.title,
                body: notification.body,
                timeAgo: DateFormatter.relative(notification.createdAt),
                unread: isUnreadHere(notification),
                unreadKey: ValueKey('non-lue-${notification.id}'),
                onTap: () => openNotification(notification),
              );
            },
          );
        },
      ),
    );
  }

  /// L'icône du kit et la couleur de sa pastille, par sorte de notification
  /// — comme la maquette, où chaque sorte a sa teinte.
  static (String, Color) _apparence(NotificationType type) => switch (type) {
    NotificationType.orderStatusUpdate => (
      ShopIcons.delivery,
      ShopColors.price,
    ),
    NotificationType.newOrder => (ShopIcons.order, ShopColors.price),
    NotificationType.newMessage => (ShopIcons.chat, ShopColors.primary),
    NotificationType.newComment => (ShopIcons.message, ShopColors.primary),
    NotificationType.newReview => (ShopIcons.starFilled, ShopColors.warning),
    NotificationType.lowStock => (ShopIcons.product, ShopColors.warning),
    NotificationType.kycDecision => (ShopIcons.doublecheck, ShopColors.success),
    NotificationType.payoutDecision => (ShopIcons.wallet, ShopColors.success),
    NotificationType.characteristicTypeDecision => (
      ShopIcons.setting,
      ShopColors.price,
    ),
  };
}
