import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/favorite_toggle_button.dart';

import '../../domain/entities/suggestion_reason.dart';
import '../providers/recommendation_providers.dart';

/// Le fil « Pour vous », en tête de l'accueil.
///
/// Des carrousels horizontaux groupés par raison, et non une grille : la
/// place en tête d'écran est empruntée au catalogue, qui reste la raison
/// d'être de l'accueil. Le fil doit se parcourir d'un pouce et se laisser
/// dépasser, pas occuper le premier écran entier.
///
/// Groupé parce que `get_recommended_products` rend déjà ses suggestions
/// dans l'ordre des sources (`0082`) : les produits qui partagent une raison
/// sont contigus, et un simple découpage en séries donne des sections dont
/// le titre est l'explication. Une justification par vignette répéterait
/// « Les mieux notés du catalogue » sous quinze cartes.
///
/// Invisible — et non « vide » — quand il n'y a rien à montrer : personne
/// n'est connecté, le catalogue est vide, ou la lecture a échoué. Un fil de
/// suggestions est un bonus ; un encart d'erreur à cet endroit coûterait
/// plus au client que l'absence de l'encart.
class RecommendedFeed extends ConsumerWidget {
  const RecommendedFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(recommendedFeedProvider);

    return feed.maybeWhen(
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();
        final groups = _groupByReason(suggestions);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final group in groups) _ReasonSection(group: group),
            const SizedBox(height: AppSpacing.xs),
          ],
        );
      },
      // Chargement et erreur rendent la même chose : rien. Un squelette
      // animé en tête d'accueil ferait sauter le catalogue vers le bas à
      // l'arrivée des données.
      orElse: () => const SizedBox.shrink(),
    );
  }

  /// Découpe la liste en séries contiguës de même raison, en préservant
  /// l'ordre du classement. Les suggestions sans raison connue (une source
  /// ajoutée en base et pas encore dans l'enum) rejoignent la série
  /// précédente plutôt que de la couper en deux.
  static List<_ReasonGroup> _groupByReason(List<ProductSuggestion> suggestions) {
    final groups = <_ReasonGroup>[];
    for (final suggestion in suggestions) {
      final reason = suggestion.reason;
      if (groups.isNotEmpty && (reason == null || groups.last.reason == reason)) {
        groups.last.suggestions.add(suggestion);
        continue;
      }
      if (reason == null) continue;
      groups.add(_ReasonGroup(reason: reason, suggestions: [suggestion]));
    }
    return groups;
  }
}

class _ReasonGroup {
  _ReasonGroup({required this.reason, required this.suggestions});

  final SuggestionReason reason;
  final List<ProductSuggestion> suggestions;
}

class _ReasonSection extends StatelessWidget {
  const _ReasonSection({required this.group});

  final _ReasonGroup group;

  /// La hauteur du carrousel. Fixée plutôt que mesurée : `ProductCard` est
  /// réglée sur un ratio de 0.54 en grille (`product_grid.dart`), donc une
  /// carte de 160 de large y tient à peu près. Un `ListView` horizontal doit
  /// de toute façon borner sa hauteur.
  static const double _cardWidth = 160;
  static const double _carouselHeight = 300;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            group.reason.label,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: _carouselHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: group.suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final product = group.suggestions[index].product;
              return SizedBox(
                width: _cardWidth,
                child: ProductCard(
                  product: product,
                  overlay: FavoriteToggleButton(
                    productId: product.id,
                    size: 20,
                    inactiveColor: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
