import 'package:flutter/material.dart';

import '../shop_icons.dart';
import '../shop_tokens.dart';
import 'misc.dart' show StatusPill;
import 'reviews.dart' show ShopRatingStars;
import 'shop_image.dart';

/// Les états d'une boutique en pastilles : ouverte ou fermée, identité
/// vérifiée, boutique officielle de MTC. Le client les lit sans lire.
class StoreBadges extends StatelessWidget {
  const StoreBadges({
    super.key,
    required this.isOpen,
    this.verified = false,
    this.official = false,
  });

  final bool isOpen;
  final bool verified;
  final bool official;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ShopSizes.padding / 2,
      runSpacing: ShopSizes.padding / 2,
      children: [
        StatusPill(
          label: isOpen ? 'Ouverte' : 'Fermée',
          color: isOpen ? ShopColors.success : ShopColors.error,
        ),
        if (verified)
          const StatusPill(label: 'Identité vérifiée', color: ShopColors.price),
        if (official)
          const StatusPill(label: 'MTC officiel', color: ShopColors.primary),
      ],
    );
  }
}

/// La note d'une boutique : les étoiles et « 4,6 · 135 avis », ou « Pas
/// encore d'avis » — jamais cinq étoiles vides qui passeraient pour une
/// mauvaise note.
class StoreRating extends StatelessWidget {
  const StoreRating({
    super.key,
    required this.rating,
    required this.count,
    this.starSize = 14,
  });

  final double rating;
  final int count;
  final double starSize;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    if (count == 0) return Text('Pas encore d\'avis', style: style);
    final note = rating.toStringAsFixed(1).replaceAll('.', ',');
    return Row(
      children: [
        ShopRatingStars(rating: rating, size: starSize),
        const SizedBox(width: ShopSizes.padding / 2),
        Flexible(
          child: Text(
            '$note · $count avis',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// La pastille ronde d'une boutique, avec l'icône des boutiques du kit.
class StoreAvatar extends StatelessWidget {
  const StoreAvatar({super.key, this.radius = 28});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: ShopColors.primary.withValues(alpha: 0.12),
      child: ShopIcon(
        ShopIcons.stores,
        size: radius,
        color: ShopColors.primary,
      ),
    );
  }
}

/// Une boutique dans une liste : sa bannière quand elle en a une, sa
/// pastille, son nom, sa ville et ce qu'elle vend, sa note, ses états.
/// Toute la carte s'ouvre, comme les cartes produit du kit.
class ShopStoreCard extends StatelessWidget {
  const ShopStoreCard({
    super.key,
    required this.name,
    required this.city,
    required this.rating,
    required this.ratingCount,
    required this.productCount,
    this.bannerPath,
    this.isOpen = true,
    this.verified = false,
    this.official = false,
    this.onTap,
  });

  final String name;
  final String city;
  final double rating;
  final int ratingCount;
  final int productCount;

  /// Le chemin de la bannière dans le bucket `supplier-branding`.
  final String? bannerPath;
  final bool isOpen;
  final bool verified;
  final bool official;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final banniere = bannerPath;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShopSizes.radius),
        side: BorderSide(width: 1.5, color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(ShopSizes.padding / 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (banniere != null) ...[
                AspectRatio(
                  aspectRatio: 3,
                  child: ShopImage(
                    banniere,
                    bucket: 'supplier-branding',
                    cacheWidth: 700,
                  ),
                ),
                const SizedBox(height: ShopSizes.padding / 2),
              ],
              Padding(
                padding: const EdgeInsets.all(ShopSizes.padding / 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const StoreAvatar(radius: 24),
                        const SizedBox(width: ShopSizes.padding * 0.75),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$city · ${productCount == 1 ? '1 produit' : '$productCount produits'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: ShopSizes.padding / 4),
                              StoreRating(rating: rating, count: ratingCount),
                            ],
                          ),
                        ),
                        ShopIcon(
                          ShopIcons.miniRight,
                          color: theme.iconTheme.color?.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                    const SizedBox(height: ShopSizes.padding * 0.75),
                    StoreBadges(
                      isOpen: isOpen,
                      verified: verified,
                      official: official,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
