import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/entities/app_notification.dart';
import '../controllers/notification_controller.dart';
import '../providers/notification_providers.dart';

/// "Notifications" — reached from a bell icon on the "Tableau de bord" tab,
/// shared by both supplier roles via `operatingSupplierIdProvider` (see
/// `AppNotification.userId`'s doc comment for what that resolves to for
/// each role), the same placement logic as the Lot 9/10 sub-screens.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(operatingSupplierIdProvider);
    if (userId == null) {
      return const Scaffold(body: MtcLoadingView());
    }
    final notificationsAsync = ref.watch(notificationsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Tout marquer comme lu',
            onPressed: () => ref
                .read(notificationControllerProvider.notifier)
                .markAllRead(userId),
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
            itemBuilder: (context, index) =>
                _NotificationTile(notification: notifications[index]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  IconData get _icon => switch (notification.type) {
    NotificationType.newOrder => Icons.receipt_long_outlined,
    NotificationType.newMessage => Icons.chat_bubble_outline_rounded,
    NotificationType.lowStock => Icons.warning_amber_rounded,
    NotificationType.kycDecision => Icons.verified_outlined,
    NotificationType.payoutDecision => Icons.account_balance_wallet_outlined,
    NotificationType.newReview => Icons.star_outline_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: notification.isRead ? null : scheme.primaryContainer.withValues(alpha: 0.25),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(_icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(notification.title),
        subtitle: Text(notification.body),
        trailing: Text(
          DateFormatter.relative(notification.createdAt),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        onTap: notification.isRead
            ? null
            : () => ref
                  .read(notificationControllerProvider.notifier)
                  .markRead(notification.id),
      ),
    );
  }
}
