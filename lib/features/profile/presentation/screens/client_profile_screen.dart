import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/animated_count_badge.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

class ClientProfileScreen extends ConsumerWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final unreadCount = ref.watch(totalUnreadCountProvider);
    final unreadNotificationCount = user == null
        ? 0
        : ref.watch(unreadNotificationCountProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: scheme.primaryContainer,
            child: Icon(
              Icons.person_rounded,
              size: 36,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (user != null) ...[
            Text(
              user.displayName,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            Text(
              user.phoneNumber,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Mes commandes'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.clientOrders),
          ),
          ListTile(
            leading: AnimatedCountBadge(
              count: unreadCount,
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            title: const Text('Messages'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.clientChat),
          ),
          ListTile(
            leading: AnimatedCountBadge(
              count: unreadNotificationCount,
              child: const Icon(Icons.notifications_outlined),
            ),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.clientNotifications),
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Mes adresses'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.clientProfileEdit),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Paramètres'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.clientSettings),
          ),
        ],
      ),
    );
  }
}
