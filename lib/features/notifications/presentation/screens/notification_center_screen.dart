import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/entities/app_notification.dart';
import '../controllers/notification_controller.dart';
import '../providers/notification_providers.dart';

/// "Notifications" — reached from a bell icon on the supplier/staff
/// "Tableau de bord" tab (`operatingSupplierIdProvider` — see
/// `AppNotification.userId`'s doc comment for what that resolves to for
/// each role), or from a bell next to the cart / a "Notifications" entry in
/// the client's Profil menu (plain `currentUserProvider.id` there, since a
/// client has no operating supplier). One shared screen either way — only
/// the tap-routing in [_NotificationTile] branches on which kind of account
/// is viewing.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    // `notificationsProvider` isn't autoDispose (the home header's bell
    // badge keeps it alive for the whole session) and there's no Realtime
    // subscription on this table (see the datasource's doc comment) — so
    // without this, a notification created by another session/device while
    // this one was already watching the same userId would sit unseen until
    // an unrelated rebuild happened to invalidate it. Forcing one fresh
    // fetch whenever this screen actually opens is what makes "see it on
    // your next visit" (the datasource's documented promise) literally true.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final operatingSupplierId = ref.read(operatingSupplierIdProvider);
      final currentUser = ref.read(currentUserProvider).valueOrNull;
      final userId = operatingSupplierId ?? currentUser?.id;
      if (userId != null) ref.invalidate(notificationsProvider(userId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final operatingSupplierId = ref.watch(operatingSupplierIdProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final userId = operatingSupplierId ?? currentUser?.id;
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
    NotificationType.orderStatusUpdate => Icons.local_shipping_outlined,
  };

  /// Where tapping this notification should land — the conversation for a
  /// `newMessage`, the order for a `newOrder`/`orderStatusUpdate`, `null`
  /// for every other type (no detail route to send those to yet) or when
  /// [AppNotification.referenceId] is missing (notifications created
  /// before this field existed). Branches on client vs. supplier exactly
  /// like `ConversationTile`, since this screen now serves both.
  String? _routeFor(WidgetRef ref) {
    final referenceId = notification.referenceId;
    if (referenceId == null) return null;
    final isClient = ref.read(currentUserProvider).valueOrNull is ClientUser;
    final prefix = ref.read(supplierRoutePrefixProvider);
    return switch (notification.type) {
      NotificationType.newMessage =>
        isClient ? AppRoutes.chatThread(referenceId) : '$prefix/messages/$referenceId',
      NotificationType.newOrder ||
      NotificationType.orderStatusUpdate =>
        isClient ? AppRoutes.orderDetail(referenceId) : '$prefix/orders/$referenceId',
      NotificationType.lowStock ||
      NotificationType.kycDecision ||
      NotificationType.payoutDecision ||
      NotificationType.newReview => null,
    };
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    if (!notification.isRead) {
      await ref
          .read(notificationControllerProvider.notifier)
          .markRead(notification.id);
    }
    final route = _routeFor(ref);
    if (route != null && context.mounted) {
      unawaited(context.push(route));
    }
  }

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
        onTap: () => unawaited(_handleTap(context, ref)),
      ),
    );
  }
}
