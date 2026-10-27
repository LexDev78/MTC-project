import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_colors.dart';
import 'package:mtc_app/core/widgets/animated_count_badge.dart';

/// One destination in a [CurvedIconNavBar]: its outlined/filled icon pair,
/// accessible name, and an optional live count badge (e.g. unread messages).
class NavBarDestination {
  const NavBarDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;

  /// Accessible name — there's no visible text (icon-only bar), so this is
  /// what a screen reader announces and what shows up as a long-press
  /// tooltip.
  final String label;

  /// Shown as a small count badge on the icon when > 0.
  final int badgeCount;
}

/// A bottom navigation bar whose top edge dips into a smooth notch under
/// the selected icon, which floats above the bar inside a circular bubble
/// (soft gradient fill, translucent, ringed by an arc border). The notch
/// and bubble both slide smoothly to the newly selected icon's position.
class CurvedIconNavBar extends StatefulWidget {
  const CurvedIconNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<NavBarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const double barHeight = 64;
  static const double bubbleDiameter = 56;
  static const double bubbleOverflow = 24;

  @override
  State<CurvedIconNavBar> createState() => _CurvedIconNavBarState();
}

class _CurvedIconNavBarState extends State<CurvedIconNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  late Animation<double> _position = _fractionTween(
    widget.selectedIndex,
    widget.selectedIndex,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  int _n = 0;

  Tween<double> _fractionTween(int fromIndex, int toIndex) {
    final n = widget.destinations.length;
    double fractionOf(int index) => (index + 0.5) / n;
    return Tween<double>(begin: fractionOf(fromIndex), end: fractionOf(toIndex));
  }

  /// The icon for [destination], wrapped in a live count badge (hidden
  /// automatically when its count is 0).
  Widget _iconFor(NavBarDestination destination, {required bool selected}) {
    return AnimatedCountBadge(
      count: destination.badgeCount,
      child: Icon(selected ? destination.selectedIcon : destination.icon),
    );
  }

  @override
  void didUpdateWidget(covariant CurvedIconNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _position =
          _fractionTween(oldWidget.selectedIndex, widget.selectedIndex).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _n = widget.destinations.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: CurvedIconNavBar.barHeight + CurvedIconNavBar.bubbleOverflow,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: CurvedIconNavBar.barHeight,
                child: AnimatedBuilder(
                  animation: _position,
                  builder: (context, _) => CustomPaint(
                    painter: _NotchBarPainter(
                      bumpFraction: _position.value,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.navBarDark
                          : AppColors.navBarLight,
                    ),
                    child: _iconRow(),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _position,
                builder: (context, _) {
                  final centerX = _position.value * constraints.maxWidth;
                  return Positioned(
                    left: centerX - CurvedIconNavBar.bubbleDiameter / 2,
                    bottom:
                        CurvedIconNavBar.barHeight -
                        CurvedIconNavBar.bubbleDiameter * 0.46,
                    child: _Bubble(
                      child: _iconFor(
                        widget.destinations[widget.selectedIndex.clamp(
                          0,
                          _n - 1,
                        )],
                        selected: true,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconRow() {
    return Row(
      children: List.generate(_n, (index) {
        final destination = widget.destinations[index];
        final selected = index == widget.selectedIndex;
        return Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            label: destination.label,
            child: Tooltip(
              message: destination.label,
              excludeFromSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onDestinationSelected(index),
                child: SizedBox(
                  height: CurvedIconNavBar.barHeight,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _position,
                      builder: (context, _) {
                        final n = _n;
                        final indexFraction = (index + 0.5) / n;
                        final distanceInSlots =
                            (_position.value - indexFraction).abs() * n;
                        final opacity = distanceInSlots.clamp(0.0, 1.0);
                        return Opacity(
                          opacity: opacity,
                          child: IconTheme(
                            data: IconThemeData(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                            child: _iconFor(destination, selected: false),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CurvedIconNavBar.bubbleDiameter,
      height: CurvedIconNavBar.bubbleDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Fond opaque : la bulle dépasse largement au-dessus de la barre,
        // donc sur une page claire un dégradé translucide laissait l'icône
        // blanche quasi invisible — l'onglet sélectionné se lisait moins
        // bien que les autres, l'inverse de ce qu'il doit faire. Le dégradé
        // (clair en haut à gauche) et l'anneau blanc sont conservés.
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 0.9,
          colors: [AppColors.brandPrimary, AppColors.brandPrimaryDeep],
        ),
        // L'anneau reprend le fond de la page (quasi blanc en clair, donc
        // identique à avant) : la bulle a l'air découpée dans l'écran. En
        // dur, ce blanc traçait un cerceau éclatant sur un fond presque noir.
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimaryDeep.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconTheme(
        data: const IconThemeData(color: Colors.white),
        child: Center(child: child),
      ),
    );
  }
}

/// Paints the bar's background with a smooth concave notch centered at
/// [bumpFraction] (0..1 across the bar's width), so the selected icon's
/// bubble nests into the bar instead of just sitting on top of it.
class _NotchBarPainter extends CustomPainter {
  _NotchBarPainter({required this.bumpFraction, required this.color});

  final double bumpFraction;

  /// Le violet de marque en clair, sa version profonde en sombre — voir
  /// [AppColors.navBarDark] pour le pourquoi.
  final Color color;

  static const double topRadius = 28;
  static const double notchHalfWidth = 34;
  static const double notchDepth = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final bumpX = bumpFraction * size.width;

    // L'encoche est *soustraite* de la barre arrondie plutôt que tracée
    // dans la même ligne de contour. Dessiner les deux d'un seul trait
    // (coin arrondi, puis `lineTo` vers le début de l'encoche) suppose que
    // l'encoche commence après le coin : sur le premier et le dernier
    // onglet elle commence *avant*, le tracé repartait en arrière et
    // peignait un éperon en pointe à côté de la bulle. Une différence de
    // chemins n'a pas cette hypothèse : où qu'elle tombe, l'encoche creuse
    // simplement la silhouette, y compris dans l'épaule d'un coin.
    final bar = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Offset.zero & size,
          topLeft: const Radius.circular(topRadius),
          topRight: const Radius.circular(topRadius),
        ),
      );

    // Refermée bien au-dessus de la barre pour que la soustraction porte
    // sur toute la hauteur du creux, même quand il mord dans un coin.
    final notch = Path()
      ..moveTo(bumpX - notchHalfWidth, -notchDepth)
      ..lineTo(bumpX - notchHalfWidth, 0)
      ..cubicTo(
        bumpX - notchHalfWidth * 0.45,
        0,
        bumpX - notchHalfWidth * 0.7,
        notchDepth,
        bumpX,
        notchDepth,
      )
      ..cubicTo(
        bumpX + notchHalfWidth * 0.7,
        notchDepth,
        bumpX + notchHalfWidth * 0.45,
        0,
        bumpX + notchHalfWidth,
        0,
      )
      ..lineTo(bumpX + notchHalfWidth, -notchDepth)
      ..close();

    canvas.drawPath(
      Path.combine(PathOperation.difference, bar, notch),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _NotchBarPainter oldDelegate) =>
      oldDelegate.bumpFraction != bumpFraction || oldDelegate.color != color;
}
