import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/app_notification.dart';
import '../notification_center_logic.dart';
import '../providers/notification_providers.dart';

/// "Notifications" côté fournisseur et collaborateur — atteint par la cloche
/// du « Tableau de bord » (`operatingSupplierIdProvider` : voir la doc de
/// `AppNotification.userId` pour ce qu'il désigne selon le rôle).
///
/// Le client a son propre écran, au style du kit
/// (`ClientNotificationsScreen`) ; les deux partagent la même logique
/// (`NotificationCenterLogic`) — seule l'apparence diffère.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen>
    with NotificationCenterLogic {
  @override
  Widget build(BuildContext context) {
    final userId = watchNotificationOwner();
    if (userId == null) {
      return const Scaffold(body: MtcLoadingView());
    }
    final notificationsAsync = ref.watch(notificationsProvider(userId));
    final notifications = notificationsAsync.valueOrNull ?? const [];
    final nonLues = notifications.where(isUnreadHere).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Notifications'),
            if (nonLues > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              _CompteurNonLues(nonLues),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Tout marquer comme lu',
            onPressed: nonLues == 0
                ? null
                : () => markAllRead(userId, notifications),
          ),
        ],
      ),
      body: AsyncValueWidget(
        value: notificationsAsync,
        data: (notifications) {
          if (notifications.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Aucune notification pour le moment',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                nonLue: isUnreadHere(notification),
                onTap: () => openNotification(notification),
              );
            },
          );
        },
      ),
    );
  }
}

/// Le nombre de notifications non lues, à côté du titre de l'écran.
class _CompteurNonLues extends StatelessWidget {
  const _CompteurNonLues(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: count == 1 ? '1 non lue' : '$count non lues',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('compteur-non-lues'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.nonLue,
    required this.onTap,
  });

  final AppNotification notification;

  /// Non lue *pour cet écran* : une notification ouverte ici perd sa
  /// pastille tout de suite, sans attendre le serveur.
  final bool nonLue;

  final VoidCallback onTap;

  IconData get _icon => switch (notification.type) {
    NotificationType.newOrder => Icons.receipt_long_outlined,
    NotificationType.newMessage => Icons.chat_bubble_outline_rounded,
    NotificationType.lowStock => Icons.warning_amber_rounded,
    NotificationType.kycDecision => Icons.verified_outlined,
    NotificationType.payoutDecision => Icons.account_balance_wallet_outlined,
    NotificationType.newReview => Icons.star_outline_rounded,
    NotificationType.orderStatusUpdate => Icons.local_shipping_outlined,
    NotificationType.newComment => Icons.forum_outlined,
    NotificationType.characteristicTypeDecision => Icons.tune_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: nonLue ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // La pastille, devant chaque notification non lue — une teinte
            // de fond à elle seule passait inaperçue.
            SizedBox(
              width: 10,
              child: nonLue
                  ? Semantics(
                      label: 'Non lue',
                      child: Container(
                        key: ValueKey('non-lue-${notification.id}'),
                        height: 10,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(_icon, color: scheme.onPrimaryContainer),
            ),
          ],
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: nonLue ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        subtitle: Text(notification.body),
        trailing: Text(
          DateFormatter.relative(notification.createdAt),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        onTap: onTap,
      ),
    );
  }
}
