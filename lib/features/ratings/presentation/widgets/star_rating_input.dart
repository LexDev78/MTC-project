import 'package:flutter/material.dart';

class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final filled = starValue <= value;
        return IconButton(
          iconSize: 36,
          onPressed: () => onChanged(starValue),
          icon: TweenAnimationBuilder<double>(
            key: ValueKey(filled),
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_border_rounded,
              color: Colors.amber,
            ),
          ),
        );
      }),
    );
  }
}
