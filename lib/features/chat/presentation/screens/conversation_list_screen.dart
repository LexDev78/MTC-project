import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../providers/chat_providers.dart';
import '../widgets/conversation_tile.dart';

class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: AsyncValueWidget(
        value: conversationsAsync,
        data: (conversations) {
          if (conversations.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Aucune conversation pour le moment',
              subtitle: "Contactez un fournisseur depuis la page d'un produit.",
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => ConversationTile(
              conversation: conversations[index],
              unreadCount: conversations[index].unreadCountClient,
            ),
          );
        },
      ),
    );
  }
}
