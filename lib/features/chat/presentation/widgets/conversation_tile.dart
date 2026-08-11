import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';

import '../../domain/entities/chat.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasUnread = conversation.unreadCount > 0;

    return ListTile(
      onTap: () => context.push(AppRoutes.chatThread(conversation.id)),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(Icons.storefront_rounded, color: scheme.onPrimaryContainer),
      ),
      title: Text(conversation.supplierName),
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
                '${conversation.unreadCount}',
                style: TextStyle(fontSize: 10, color: scheme.onPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
