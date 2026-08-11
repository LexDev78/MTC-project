import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/favorite_controller.dart';
import '../providers/favorite_providers.dart';

/// Heart icon kept in red regardless of theme when active — like star
/// ratings staying amber, "favorite = red heart" is a strong enough
/// universal idiom that tying it to the brand's semantic error color would
/// be more confusing, not less.
class FavoriteToggleButton extends ConsumerWidget {
  const FavoriteToggleButton({
    super.key,
    required this.productId,
    this.size = 24,
    this.inactiveColor,
  });

  final String productId;
  final double size;

  /// Defaults to the theme's `onSurfaceVariant`; pass `Colors.white` when
  /// overlaying a colored image/placeholder (see `product_card.dart`).
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(productId));
    final resolvedInactiveColor =
        inactiveColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return IconButton(
      icon: TweenAnimationBuilder<double>(
        key: ValueKey(isFavorite),
        tween: Tween(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite ? Colors.red : resolvedInactiveColor,
        ),
      ),
      iconSize: size,
      onPressed: () =>
          ref.read(favoriteControllerProvider.notifier).toggle(productId),
    );
  }
}
