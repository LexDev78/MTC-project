import 'package:flutter/material.dart';

/// Read-only star rating display. Deliberately kept in amber — the
/// established idiom for ratings — separate from the Mali-gold brand accent
/// used elsewhere, so the two don't visually collide.
class MtcRatingStars extends StatelessWidget {
  const MtcRatingStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.showValue = true,
    this.ratingCount,
    this.asStars = false,
  });

  final double rating;
  final double size;
  final bool showValue;
  final int? ratingCount;

  /// Dessine les **cinq** étoiles, remplies jusqu'à [rating], au lieu de la
  /// pastille compacte « ★ 4,6 ».
  ///
  /// La pastille convient à une moyenne, qu'on lit comme un chiffre. Elle ne
  /// convient pas à une note individuelle : avec `showValue: false` elle se
  /// réduisait à une étoile unique, identique pour un avis à 1 et un avis à
  /// 5. Vu en capture sur la fiche produit, pas en test.
  final bool asStars;

  @override
  Widget build(BuildContext context) {
    if (asStars) {
      final remplies = rating.round().clamp(0, 5);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= remplies ? Icons.star_rounded : Icons.star_border_rounded,
              size: size,
              color: Colors.amber,
            ),
          if (showValue) ...[
            const SizedBox(width: 4),
            Text(
              rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: size * 0.85,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size, color: Colors.amber),
        const SizedBox(width: 2),
        if (showValue)
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.85,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (ratingCount != null)
          Text(
            ' ($ratingCount)',
            style: TextStyle(
              fontSize: size * 0.75,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
