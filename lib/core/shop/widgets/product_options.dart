import 'package:flutter/material.dart';

import '../shop_icons.dart';
import '../shop_tokens.dart';
import 'misc.dart';

/// La quantité du kit (`ProductQuantity`) : deux boutons cerclés de 40 et
/// le nombre au milieu.
class ShopQuantityStepper extends StatelessWidget {
  const ShopQuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.label = 'Quantité',
    this.compact = false,
  });

  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  /// `null` : sans titre au-dessus (ligne de panier).
  final String? label;

  /// 32 au lieu de 40, pour une ligne de panier.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cote = compact ? 32.0 : 40.0;
    Widget bouton(String icon, VoidCallback? onTap, String tooltip) =>
        SizedBox.square(
          dimension: cote,
          child: Tooltip(
            message: tooltip,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.square(cote),
              ),
              child: ShopIcon(icon, size: compact ? 18 : 24),
            ),
          ),
        );
    final rangee = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        bouton(ShopIcons.minus, onDecrement, 'Retirer un'),
        SizedBox(
          width: cote,
          child: Center(
            child: Text(
              '$quantity',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: compact ? 14 : 18,
              ),
            ),
          ),
        ),
        bouton(ShopIcons.plus1, onIncrement, 'Ajouter un'),
      ],
    );
    if (label == null) return rangee;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label!, style: theme.textTheme.titleSmall),
        const SizedBox(height: ShopSizes.padding),
        rangee,
      ],
    );
  }
}

/// Une pastille de couleur (`ColorDot` du kit), cochée quand choisie.
class ColorDot extends StatelessWidget {
  const ColorDot({
    super.key,
    required this.color,
    this.isActive = false,
    this.onTap,
    this.semanticLabel,
    this.image,
  });

  final Color color;
  final bool isActive;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Une photo de l'article dans cette couleur, à la place de l'aplat.
  final Widget? image;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ShopSizes.duration,
          padding: EdgeInsets.all(isActive ? ShopSizes.padding / 4 : 0),
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? ShopColors.primary : Colors.transparent,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color,
                radius: 20,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null) ClipOval(child: image),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: isActive ? 1 : 0,
                duration: ShopSizes.duration,
                child: const CheckMark(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une [ColorDot] et son nom dessous : les couleurs d'un catalogue
/// d'artisans ne se reconnaissent pas toujours à la pastille (« Indigo »,
/// « Ocre », ou une photo).
///
/// [onTap] à `null` : la couleur n'existe pas avec ce qui est déjà choisi,
/// elle reste visible mais estompée.
class ColorOption extends StatelessWidget {
  const ColorOption({
    super.key,
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
    this.image,
  });

  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;
  final Widget? image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorDot(
                color: color,
                image: image,
                isActive: isActive,
                onTap: onTap,
                semanticLabel: label,
              ),
              const SizedBox(height: ShopSizes.padding / 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isActive
                      ? ShopColors.primary
                      : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une taille, en rond cerclé (`SizeButton` du kit). S'élargit pour les
/// libellés plus longs que « XL » (« 42 », « Unique »).
class SizeButton extends StatelessWidget {
  const SizeButton({
    super.key,
    required this.text,
    required this.isActive,
    required this.onTap,
    this.uppercase = true,
  });

  final String text;
  final bool isActive;
  final VoidCallback? onTap;

  /// Les tailles du kit sont des codes (« s », « xl ») ; des valeurs saisies
  /// par un fournisseur (« 500 g », « 128 Go ») gardent leur casse.
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final rond = text.length <= 3;
    return SizedBox(
      height: 40,
      width: rond ? 40 : null,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: rond
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: ShopSizes.padding),
          minimumSize: const Size(40, 40),
          shape: rond ? const CircleBorder() : const StadiumBorder(),
          side: isActive
              ? const BorderSide(color: ShopColors.primary, width: 1.5)
              : null,
        ),
        child: Text(
          uppercase ? text.toUpperCase() : text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isActive
                ? ShopColors.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// « En stock » en vert, « Indisponible » en rouge.
class AvailabilityTag extends StatelessWidget {
  const AvailabilityTag({super.key, required this.isAvailable, this.label});

  final bool isAvailable;

  /// Un libellé plus précis (« Plus que 3 en stock »).
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ShopSizes.padding / 2),
      decoration: BoxDecoration(
        color: isAvailable ? ShopColors.success : ShopColors.error,
        borderRadius: BorderRadius.circular(ShopSizes.radius / 2),
      ),
      child: Text(
        label ?? (isAvailable ? 'En stock' : 'Indisponible'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
