import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../providers/chat_providers.dart';
import '../widgets/conversation_tile.dart';

/// "Messages" tab of `SupplierShell` — shared by both supplier roles via
/// `operatingSupplierIdProvider`. Reuses `ChatThreadScreen` as-is when a
/// tile is tapped (already agnostic of which side is viewing).
class SupplierConversationListScreen extends ConsumerWidget {
  const SupplierConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierId = ref.watch(operatingSupplierIdProvider);
    if (supplierId == null) {
      return const Scaffold(body: MtcLoadingView());
    }

    final conversationsAsync = ref.watch(
      supplierConversationsProvider(supplierId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: AsyncValueWidget(
        value: conversationsAsync,
        data: (conversations) {
          if (conversations.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Aucune conversation pour le moment',
              subtitle: 'Les messages de vos clients arriveront ici.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => ConversationTile(
              conversation: conversations[index],
              unreadCount: conversations[index].unreadCountSupplier,
            ),
          );
        },
      ),
    );
  }
}
