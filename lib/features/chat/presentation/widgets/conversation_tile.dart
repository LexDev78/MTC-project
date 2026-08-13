import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/entities/chat.dart';

class ConversationTile extends ConsumerWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.unreadCount,
  });

  final ChatConversation conversation;

  /// Explicit rather than read off [conversation] directly so the same
  /// tile serves both sides — a client's list shows `unreadCountClient`,
  /// a supplier's list shows `unreadCountSupplier`.
  final int unreadCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasUnread = unreadCount > 0;
    final isClient = ref.watch(currentUserProvider).valueOrNull is ClientUser;
    final title = isClient
        ? conversation.supplierName
        : conversation.clientDisplayNameSnapshot;

    return ListTile(
      onTap: () => context.push(
        isClient
            ? AppRoutes.chatThread(conversation.id)
            : '${ref.read(supplierRoutePrefixProvider)}/messages/${conversation.id}',
      ),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(
          isClient ? Icons.storefront_rounded : Icons.person_rounded,
          color: scheme.onPrimaryContainer,
        ),
      ),
      title: Text(title),
      subtitle: Text(
        conversation.lastMessagePreview.isEmpty
            ? 'Nouvelle conversation'
            : conversation.lastMessagePreview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormatter.relative(conversation.lastMessageAt),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          if (hasUnread) ...[
            const SizedBox(height: AppSpacing.xs),
            CircleAvatar(
              radius: 9,
              backgroundColor: scheme.primary,
              child: Text(
                '$unreadCount',
                style: TextStyle(fontSize: 10, color: scheme.onPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
