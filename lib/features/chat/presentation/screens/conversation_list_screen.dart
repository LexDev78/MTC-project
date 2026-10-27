import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';

import '../../domain/entities/chat.dart';
import '../providers/chat_providers.dart';

/// Les conversations du client avec les boutiques, au style du kit : la
/// même rangée que les notifications — pastille, nom de la boutique, dernier
/// message, ancienneté — et le nombre de messages non lus en pastille.
///
/// Le côté fournisseur garde sa propre liste (`SupplierConversationListScreen`).
class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: conversations.when(
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
          title: 'Vos messages n\'ont pas pu être chargés',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(conversationsProvider),
            child: const Text('Réessayer'),
          ),
        ),
        data: (liste) {
          if (liste.isEmpty) {
            return const IllustratedMessage(
              illustration: ShopIllustration.help,
              title: 'Aucune conversation',
              message:
                  'Écrivez à une boutique depuis la page d\'un produit : vos '
                  'échanges arriveront ici.',
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
            itemBuilder: (context, index) =>
                _Conversation(conversation: liste[index]),
          );
        },
      ),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nonLus = conversation.unreadCountClient;
    final apercu = conversation.lastMessagePreview.isEmpty
        ? 'Nouvelle conversation'
        : conversation.lastMessagePreview;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => context.push(AppRoutes.chatThread(conversation.id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ShopSizes.padding),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: ShopColors.primary.withValues(alpha: 0.12),
                  child: const ShopIcon(
                    ShopIcons.stores,
                    color: ShopColors.primary,
                  ),
                ),
                const SizedBox(width: ShopSizes.padding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.supplierName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: nonLus > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          const SizedBox(width: ShopSizes.padding / 2),
                          Text(
                            DateFormatter.relative(conversation.lastMessageAt),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: ShopSizes.padding / 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              apercu,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                // Le message pas encore lu se lit à l'encre.
                                color: nonLus > 0
                                    ? theme.colorScheme.onSurface
                                    : null,
                              ),
                            ),
                          ),
                          // Fermée par le client : la boutique ne peut plus
                          // lui écrire, et il doit pouvoir le retrouver.
                          if (conversation.isClosed) ...[
                            const SizedBox(width: ShopSizes.padding / 2),
                            const StatusPill(
                              label: 'Fermée',
                              color: ShopColors.black60,
                            ),
                          ],
                          if (nonLus > 0) ...[
                            const SizedBox(width: ShopSizes.padding / 2),
                            Semantics(
                              label: nonLus == 1
                                  ? '1 message non lu'
                                  : '$nonLus messages non lus',
                              excludeSemantics: true,
                              child: CountPill(count: nonLus),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
