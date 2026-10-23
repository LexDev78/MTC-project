import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/features/recommendations/domain/entities/recent_search.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';

/// L'historique des recherches (maquette « History » du kit), groupé par
/// jour, avec « Tout effacer ».
///
/// Toucher une recherche la relance : l'écran se ferme en la rendant à la
/// recherche, qui la valide.
///
/// C'est le journal qui nourrit « Pour vous » : effacer ici retire aussi la
/// recherche des suggestions, et l'écran le dit avant de tout effacer.
class SearchHistoryScreen extends ConsumerWidget {
  const SearchHistoryScreen({super.key});

  Future<void> _effacer(
    BuildContext context,
    WidgetRef ref, {
    String? recherche,
  }) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(recommendationRepositoryProvider)
          .forgetSearches(query: recherche);
      ref.invalidate(recentSearchesProvider);
      if (recherche == null) {
        messager.showSnackBar(
          const SnackBar(content: Text('Votre historique est effacé.')),
        );
      }
    } catch (erreur) {
      messager.showSnackBar(
        SnackBar(
          content: Text(
            messagePourUtilisateur(
              erreur,
              repli: 'L\'historique n\'a pas pu être effacé.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _toutEffacer(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer l\'historique ?'),
        content: const Text(
          'Vos recherches passées ne serviront plus à vous proposer des '
          'articles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ShopColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) {
      await _effacer(context, ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentes = ref.watch(recentSearchesProvider);
    final liste = recentes.valueOrNull ?? const <RecentSearch>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          if (liste.isNotEmpty)
            TextButton(
              onPressed: () => _toutEffacer(context, ref),
              child: const Text('Tout effacer'),
            ),
          const SizedBox(width: ShopSizes.padding),
        ],
      ),
      body: recentes.when(
        skipLoadingOnReload: true,
        loading: () => ListView(
          padding: const EdgeInsets.all(ShopSizes.screenMargin),
          children: [
            for (var i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: ShopSizes.padding),
                child: Skeleton(height: 24),
              ),
          ],
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'L\'historique n\'a pas pu être chargé',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(recentSearchesProvider),
            child: const Text('Réessayer'),
          ),
        ),
        data: (recherches) {
          if (recherches.isEmpty) {
            return const IllustratedMessage(
              illustration: ShopIllustration.emptyState,
              title: 'Aucune recherche',
              message: 'Vos recherches apparaîtront ici.',
            );
          }
          final parJour = groupBy(
            recherches,
            (RecentSearch r) => DateTime(
              r.searchedAt.year,
              r.searchedAt.month,
              r.searchedAt.day,
            ),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.screenMargin,
              ShopSizes.padding,
              ShopSizes.screenMargin,
              ShopSizes.screenMargin,
            ),
            children: [
              for (final (index, MapEntry(key: jour, value: duJour))
                  in parJour.entries.indexed) ...[
                Padding(
                  padding: EdgeInsets.only(
                    top: index == 0 ? 0 : ShopSizes.padding * 2,
                    bottom: ShopSizes.padding / 4,
                  ),
                  child: Text(
                    DateFormatter.dayHeading(jour),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final (rang, r) in duJour.indexed)
                  SearchHistoryTile(
                    text: r.query,
                    showClock: false,
                    onTap: () => context.pop(r.query),
                    onRemove: () => _effacer(context, ref, recherche: r.query),
                    showDivider: rang < duJour.length - 1,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
