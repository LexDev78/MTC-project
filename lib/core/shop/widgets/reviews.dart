import 'package:flutter/material.dart';

import '../shop_icons.dart';
import '../shop_tokens.dart';

/// Les étoiles du kit (`Star_filled.svg`), demi-étoiles comprises.
class ShopRatingStars extends StatelessWidget {
  const ShopRatingStars({super.key, required this.rating, this.size = 20});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final vide = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.08);
    return Semantics(
      label: 'Note : ${rating.toStringAsFixed(1)} sur 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: EdgeInsets.only(right: i == 4 ? 0 : size / 5),
              child: SizedBox.square(
                dimension: size,
                child: Stack(
                  children: [
                    ShopIcon(ShopIcons.starFilled, size: size, color: vide),
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: (rating - i).clamp(0, 1).toDouble(),
                        child: ShopIcon(
                          ShopIcons.starFilled,
                          size: size,
                          color: ShopColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// La note à donner (maquette « Add review » du kit) : cinq grandes étoiles
/// grises, jaunes jusqu'à celle qu'on touche. `0` : rien de choisi.
///
/// Chaque étoile dit ce qu'elle vaut (« 4 étoiles ») : c'est ce que lit un
/// lecteur d'écran, et ce qu'un test touche.
class StarRatingField extends StatelessWidget {
  const StarRatingField({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vide = theme.colorScheme.onSurface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.2 : 0.1,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var n = 1; n <= 5; n++)
          IconButton(
            tooltip: n == 1 ? '1 étoile' : '$n étoiles',
            isSelected: n <= value,
            onPressed: () => onChanged(n),
            icon: TweenAnimationBuilder<double>(
              // Rejoue le petit rebond quand l'étoile change d'état.
              key: ValueKey(n <= value),
              tween: Tween(begin: 0.7, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, echelle, child) =>
                  Transform.scale(scale: echelle, child: child),
              child: ShopIcon(
                ShopIcons.starFilled,
                size: size,
                color: n <= value ? ShopColors.warning : vide,
              ),
            ),
          ),
      ],
    );
  }
}

/// La réponse publique du vendeur sous un avis, rattachée par un filet
/// violet.
class SellerReply extends StatelessWidget {
  const SellerReply({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        ShopSizes.padding * 0.75,
        ShopSizes.padding / 2,
        ShopSizes.padding / 2,
        ShopSizes.padding / 2,
      ),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: ShopColors.primary, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Réponse du vendeur',
            style: theme.textTheme.labelMedium?.copyWith(
              color: ShopColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: TextStyle(color: theme.colorScheme.onSurface, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Le résumé des avis (`ReviewCard` du kit) : la note sur 5, le nombre
/// d'avis, les étoiles, et la répartition en barres à droite.
class RatingSummaryCard extends StatelessWidget {
  const RatingSummaryCard({
    super.key,
    required this.rating,
    required this.reviewCount,
    required this.countsByStar,
  });

  final double rating;
  final int reviewCount;

  /// Le nombre d'avis à 5, 4, 3, 2 et 1 étoile, dans cet ordre.
  final List<int> countsByStar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ShopSizes.padding),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(ShopSizes.radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: '${rating.toStringAsFixed(1).replaceAll('.', ',')} ',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(text: '/5', style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
                Text(reviewCount == 1 ? 'Sur 1 avis' : 'Sur $reviewCount avis'),
                const SizedBox(height: ShopSizes.padding),
                ShopRatingStars(rating: rating),
              ],
            ),
          ),
          const SizedBox(width: ShopSizes.padding),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < 5; i++)
                  RateBar(
                    star: 5 - i,
                    value: reviewCount == 0
                        ? 0
                        : (i < countsByStar.length ? countsByStar[i] : 0) /
                              reviewCount,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une barre de répartition : « 4 ★ » et sa part en jaune.
class RateBar extends StatelessWidget {
  const RateBar({super.key, required this.star, required this.value});

  final int star;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: star == 1 ? 0 : ShopSizes.padding / 2),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              star == 1 ? '1 étoile' : '$star étoiles',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          const SizedBox(width: ShopSizes.padding / 2),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ShopSizes.radius),
              child: LinearProgressIndicator(
                minHeight: 6,
                color: ShopColors.warning,
                backgroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.05,
                ),
                value: value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un avis d'acheteur en carte grise (maquette « Reviews ») : initiales,
/// nom, ancienneté, étoiles, puis le texte entre guillemets.
class ReviewTile extends StatelessWidget {
  const ReviewTile({
    super.key,
    required this.author,
    required this.timeAgo,
    required this.rating,
    required this.comment,
    this.title,
    this.footer,
  });

  final String author;
  final String timeAgo;
  final double rating;
  final String comment;

  /// Le titre de l'avis, quand l'acheteur en a donné un : une ligne à
  /// l'encre, au-dessus du texte.
  final String? title;

  /// Photos, réponse du vendeur.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ShopSizes.padding),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(ShopSizes.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  author.isEmpty ? '?' : author.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: ShopSizes.padding / 2),
              // Le nom prend toute la place libre, pas la moitié : un
              // `Spacer` à côté d'un `Flexible` la lui disputait.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, contraintes) {
                    final nom = Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    );
                    final quand = Text(
                      timeAgo,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    );
                    // Trop étroit pour les deux sur une ligne (petit écran,
                    // texte agrandi) : l'ancienneté passe sous le nom.
                    if (contraintes.maxWidth < 120) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [nom, quand],
                      );
                    }
                    return Row(
                      children: [
                        Flexible(child: nom),
                        const SizedBox(width: ShopSizes.padding / 2),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: contraintes.maxWidth * 0.6,
                          ),
                          child: quand,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: ShopSizes.padding / 2),
              ShopRatingStars(rating: rating, size: 16),
            ],
          ),
          if (title case final titre? when titre.trim().isNotEmpty) ...[
            const SizedBox(height: ShopSizes.padding),
            Text(
              titre,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
          if (comment.isNotEmpty) ...[
            SizedBox(
              height: title?.trim().isNotEmpty ?? false
                  ? ShopSizes.padding / 4
                  : ShopSizes.padding,
            ),
            Text(
              '« $comment »',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: ShopSizes.padding / 2),
            footer!,
          ],
        ],
      ),
    );
  }
}
