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
  });

  final double rating;
  final double size;
  final bool showValue;
  final int? ratingCount;

  @override
  Widget build(BuildContext context) {
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
