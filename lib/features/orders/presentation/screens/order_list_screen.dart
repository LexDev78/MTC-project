import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/search_text.dart';

import '../../domain/entities/order.dart';
import '../../domain/order_reference.dart';
import '../providers/order_history_filter.dart';
import '../providers/order_providers.dart';
import '../widgets/order_cards.dart';
import '../widgets/order_period_sheet.dart';

/// Les commandes du client, d'après la maquette « Orders » du kit : une
/// recherche, puis l'historique rangé par étape, chaque rubrique avec son
/// compte.
///
/// L'étape est celle de la commande entière (`order.status`) : une commande
/// partagée entre plusieurs boutiques n'apparaît qu'une fois, à l'étape que
/// l'agrégat retient — le groupe le plus avancé tant que tout n'est pas
/// arrivé (`order_overall_status`, `0112`). Le détail par boutique reste sur
/// la fiche.
class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final _champ = TextEditingController();

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  /// Une commande répond à [texte] par son numéro, une de ses boutiques ou
  /// un de ses articles.
  bool _correspond(Order commande, String texte) => matchesAnySearch([
    commande.reference,
    for (final g in commande.supplierGroups) ...[
      g.supplierName,
      for (final i in g.items) i.productNameSnapshot,
    ],
  ], texte);

  Future<void> _filtrer(OrderPeriod actuelle) async {
    final choix = await showOrderPeriodSheet(context, current: actuelle);
    if (choix == null || !mounted) return;
    ref.read(orderPeriodProvider.notifier).state = choix;
  }

  @override
  Widget build(BuildContext context) {
    final periode = ref.watch(orderPeriodProvider);
    final commandes = ref.watch(ordersInPeriodProvider);
    final texte = _champ.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Commandes')),
      body: commandes.when(
        skipLoadingOnReload: true,
        loading: () => ListView(
          padding: const EdgeInsets.all(ShopSizes.screenMargin),
          children: [
            const Skeleton(height: 56),
            const SizedBox(height: ShopSizes.padding * 2),
            for (var i = 0; i < 5; i++) ...[
              const Skeleton(height: 24),
              const SizedBox(height: ShopSizes.padding * 1.5),
            ],
          ],
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'Vos commandes n\'ont pas pu être chargées',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(ordersForUserProvider),
            child: const Text('Réessayer'),
          ),
        ),
        data: (liste) {
          final trouvees = texte.isEmpty
              ? const <Order>[]
              : [
                  for (final c in liste)
                    if (_correspond(c, texte)) c,
                ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.screenMargin,
              ShopSizes.padding,
              ShopSizes.screenMargin,
              ShopSizes.screenMargin,
            ),
            children: [
              ShopSearchField(
                hintText: 'Trouver une commande…',
                controller: _champ,
                onChanged: (_) => setState(() {}),
                onFilterTap: () => _filtrer(periode),
                filterActive: periode != OrderPeriod.all,
                filterTooltip: 'Filtrer par période',
              ),
              const SizedBox(height: ShopSizes.padding * 1.5),
              if (texte.isNotEmpty) ...[
                if (trouvees.isEmpty)
                  IllustratedMessage(
                    compact: true,
                    illustration: ShopIllustration.noResult,
                    title: 'Aucune commande trouvée',
                    message:
                        'Rien ne répond à « $texte »${periode.suffix}. '
                        'Cherchez un numéro de commande, une boutique ou un '
                        'article.',
                  )
                else
                  for (final commande in trouvees) ...[
                    OrderCard(order: commande),
                    const SizedBox(height: ShopSizes.padding),
                  ],
              ] else ...[
                Text(
                  'Historique des commandes',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (periode != OrderPeriod.all) ...[
                  const SizedBox(height: ShopSizes.padding / 4),
                  Text(
                    'Sur les ${periode.label.toLowerCase()}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: ShopSizes.padding / 2),
                // Sans période, une liste vide veut dire « jamais commandé ».
                // Sur une période, les rubriques à zéro le disent mieux.
                if (liste.isEmpty && periode == OrderPeriod.all)
                  const IllustratedMessage(
                    compact: true,
                    illustration: ShopIllustration.emptyState,
                    title: 'Pas encore de commande',
                    message:
                        'Vos commandes apparaîtront ici dès le premier achat.',
                  )
                else
                  for (final rubrique in OrderHistoryCategory.values)
                    StatusCountTile(
                      icon: rubrique.icon,
                      label: rubrique.label,
                      color: rubrique.color,
                      count: liste
                          .where(
                            (c) =>
                                OrderHistoryCategory.of(c.status) == rubrique,
                          )
                          .length,
                      onTap: () => context.push(
                        AppRoutes.ordersByCategory(rubrique.name),
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Les commandes d'une rubrique de l'historique, en cartes du kit.
class OrdersByCategoryScreen extends ConsumerWidget {
  const OrdersByCategoryScreen({super.key, required this.category});

  final OrderHistoryCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periode = ref.watch(orderPeriodProvider);
    final commandes = ref.watch(ordersInPeriodProvider);
    return Scaffold(
      appBar: AppBar(title: Text(category.label)),
      body: commandes.when(
        skipLoadingOnReload: true,
        loading: () => ListView(
          padding: const EdgeInsets.all(ShopSizes.screenMargin),
          children: const [
            Skeleton(height: 260),
            SizedBox(height: ShopSizes.padding),
            Skeleton(height: 260),
          ],
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'Vos commandes n\'ont pas pu être chargées',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(ordersForUserProvider),
            child: const Text('Réessayer'),
          ),
        ),
        data: (liste) {
          // Déjà triées de la plus récente à la plus ancienne par le dépôt.
          final visibles = [
            for (final c in liste)
              if (OrderHistoryCategory.of(c.status) == category) c,
          ];
          if (visibles.isEmpty) {
            return IllustratedMessage(
              illustration: ShopIllustration.emptyState,
              title: '${category.emptyTitle}${periode.suffix}',
              message: category.emptyMessage,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.screenMargin,
              ShopSizes.padding,
              ShopSizes.screenMargin,
              ShopSizes.screenMargin,
            ),
            itemCount: visibles.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: ShopSizes.padding),
            itemBuilder: (context, index) => OrderCard(order: visibles[index]),
          );
        },
      ),
    );
  }
}
