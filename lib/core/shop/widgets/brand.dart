import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../shop_icons.dart';
import '../shop_theme.dart';
import '../shop_tokens.dart';

/// Le logo de la charte MTC : le dauphin et ses vagues dans leur pastille
/// blanche, ombrée sur le bandeau.
///
/// Le dauphin est tracé en vectoriel d'après la charte
/// (`assets/brand/logo_mtc.svg`, posé comme dans la pastille de la charte).
class MtcLogo extends StatelessWidget {
  const MtcLogo({super.key, this.size = 88});

  final double size;

  static const asset = 'assets/brand/logo_mtc.svg';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        // Le rayon de la charte : 27 % du côté.
        borderRadius: BorderRadius.circular(size * 0.27),
        boxShadow: [
          BoxShadow(
            color: const Color(0x553C28C8),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      // Le nom « MTC » suit toujours le logo et se lit, lui.
      child: SvgPicture.asset(
        asset,
        width: size,
        height: size,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Le nom « MTC » sous le logo : ExtraBold, lettres espacées de 0,18 em.
class MtcWordmark extends StatelessWidget {
  const MtcWordmark({super.key, this.size = 27, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final espacement = size * 0.18;
    // Flutter espace aussi après la dernière lettre : autant à gauche, et
    // le mot est centré sur son encre.
    return Padding(
      padding: EdgeInsets.only(left: espacement),
      child: Text(
        'MTC',
        style: TextStyle(
          fontFamily: ShopTheme.fontFamily,
          fontSize: size,
          fontWeight: FontWeight.w800,
          height: 1.26,
          letterSpacing: espacement,
          color: color,
        ),
      ),
    );
  }
}

/// Un dégradé linéaire au sens de CSS (`linear-gradient(135deg, …)`), celui
/// des maquettes : la ligne passe par le centre à l'angle donné, et les
/// coins opposés prennent exactement la première et la dernière couleur.
/// Un `LinearGradient` d'un coin à l'autre suivrait la diagonale du
/// rectangle, qui n'est à 45° que sur un carré.
ui.Gradient degradeCss(Rect rect, double degres, List<Color> couleurs) {
  final a = degres * math.pi / 180;
  final direction = Offset(math.sin(a), -math.cos(a));
  final demi =
      (rect.width * math.sin(a).abs() + rect.height * math.cos(a).abs()) / 2;
  return ui.Gradient.linear(
    rect.center - direction * demi,
    rect.center + direction * demi,
    couleurs,
  );
}

/// Les deux bandeaux des maquettes : l'accueil, plus haut, et la connexion.
enum MtcBandeau {
  /// « Bienvenue ! » : grand logo, pas de retour.
  accueil(
    hauteur: 312,
    logoHaut: 25,
    logo: 112,
    nom: 31,
    ecartNom: 13,
    decorations: [
      _Decor.point(296, 70, 6),
      _Decor.point(334, 106, 12),
      _Decor.point(64, 238, 10),
      _Decor.vaguelette(54, 110),
      _Decor.vaguelette(326, 236),
    ],
  ),

  /// « Bon retour ! » : logo plus petit, retour à l'accueil possible.
  connexion(
    hauteur: 232,
    logoHaut: 16,
    logo: 88,
    nom: 27,
    ecartNom: 10,
    decorations: [
      _Decor.point(300, 64, 6),
      _Decor.point(338, 106, 12),
      _Decor.point(70, 206, 10),
      _Decor.vaguelette(46, 140),
      _Decor.vaguelette(324, 194),
    ],
  );

  const MtcBandeau({
    required this.hauteur,
    required this.logoHaut,
    required this.logo,
    required this.nom,
    required this.ecartNom,
    required List<_Decor> decorations,
  }) : _decors = decorations;

  /// Sous la barre d'état, jusqu'au creux de la vague blanche.
  final double hauteur;

  /// Haut du logo, sous la barre d'état.
  final double logoHaut;
  final double logo;
  final double nom;
  final double ecartNom;

  /// Points et vaguelettes, en coordonnées de maquette (390 pt de large,
  /// barre d'état de 47 pt comprise).
  final List<_Decor> _decors;
}

/// Le bandeau de l'accueil et de la connexion : le dégradé de la charte à
/// 135°, ses points et ses vaguelettes, le logo et le nom, puis deux vagues
/// qui s'ouvrent sur la page.
///
/// Les vagues sont celles des maquettes, mesurées puis ajustées en
/// courbes (écart moyen sous 0,4 pt) ; elles s'étirent en largeur et
/// gardent leur hauteur. La vague de devant prend la couleur de la toile :
/// le bandeau se fond dans la page, en clair comme en sombre.
class MtcBrandBand extends StatelessWidget {
  const MtcBrandBand({super.key, required this.bandeau, this.onBack});

  final MtcBandeau bandeau;

  /// Le retour en haut à gauche (connexion ouverte depuis l'accueil).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final toile = Theme.of(context).scaffoldBackgroundColor;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Sur le dégradé, des icônes claires dans la barre d'état, quel que
      // soit le mode : l'écran pose les siennes pour la toile.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: SizedBox(
        height: haut + bandeau.hauteur,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _PeintreBandeau(
                    toile: toile,
                    decors: bandeau._decors,
                    barreEtat: haut,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: haut + bandeau.logoHaut,
              child: Column(
                children: [
                  MtcLogo(size: bandeau.logo),
                  SizedBox(height: bandeau.ecartNom),
                  MtcWordmark(size: bandeau.nom),
                ],
              ),
            ),
            if (onBack != null)
              Positioned(
                left: 16,
                top: haut + 3,
                child: _BoutonRetour(onTap: onBack!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Le rond translucide et son chevron, en haut du bandeau.
class _BoutonRetour extends StatelessWidget {
  const _BoutonRetour({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Dessiné à la main : le rôle de bouton se déclare, sinon un lecteur
    // d'écran ne lit que « Retour ».
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Tooltip(
          message: 'Retour',
          child: Material(
            color: Colors.white.withValues(alpha: 0.18),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: const SizedBox.square(
                dimension: 44,
                child: Center(
                  child: ShopIcon(
                    ShopIcons.miniLeft,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un point ou une vaguelette du bandeau, centré en (x, y).
class _Decor {
  const _Decor.point(this.x, this.y, this.diametre) : vaguelette = false;
  const _Decor.vaguelette(this.x, this.y) : diametre = 0, vaguelette = true;

  final double x;
  final double y;
  final double diametre;
  final bool vaguelette;
}

class _PeintreBandeau extends CustomPainter {
  _PeintreBandeau({
    required this.toile,
    required this.decors,
    required this.barreEtat,
  });

  final Color toile;
  final List<_Decor> decors;
  final double barreEtat;

  /// Barre d'état des maquettes (iPhone de 390 × 844 pt).
  static const _barreMaquette = 47.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = degradeCss(rect, 135, ShopColors.gradient),
    );

    final echelle = size.width / 390;
    final blanc = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final trait = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final decor in decors) {
      final centre = Offset(
        decor.x * echelle,
        decor.y - _barreMaquette + barreEtat,
      );
      if (decor.vaguelette) {
        // Un « ~ » de 30 × 13 pt, comme sur les maquettes.
        final o = centre - const Offset(15, 6.5);
        canvas.drawPath(
          Path()
            ..moveTo(o.dx + 1.5, o.dy + 9)
            ..cubicTo(
              o.dx + 4,
              o.dy + 4,
              o.dx + 6.5,
              o.dy + 1.5,
              o.dx + 10,
              o.dy + 1.5,
            )
            ..cubicTo(
              o.dx + 15,
              o.dy + 1.5,
              o.dx + 18,
              o.dy + 12,
              o.dx + 23,
              o.dy + 12,
            )
            ..cubicTo(
              o.dx + 25.5,
              o.dy + 12,
              o.dx + 27.5,
              o.dy + 9.5,
              o.dx + 28.5,
              o.dy + 6.5,
            ),
          trait,
        );
      } else {
        canvas.drawCircle(centre, decor.diametre / 2, blanc);
      }
    }

    // La vague claire, puis celle de devant, à la couleur de la toile.
    canvas.drawPath(
      _vague(size, const [46, 184.9, 100.5, 243.9, -26.3, 32]),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawPath(
      _vague(size, const [36, 177.8, 73.1, 217.1, -39.2, 15.5]),
      Paint()..color = toile,
    );
  }

  /// Une vague mesurée sur les maquettes : profondeurs au-dessus du bas du
  /// bandeau aux deux bords, et deux points de contrôle (x en largeur de
  /// maquette, 390).
  Path _vague(Size size, List<double> v) {
    final k = size.width / 390;
    final bas = size.height;
    return Path()
      ..moveTo(0, bas - v[0])
      ..cubicTo(
        v[1] * k,
        bas - v[2],
        v[3] * k,
        bas - v[4],
        size.width,
        bas - v[5],
      )
      ..lineTo(size.width, bas)
      ..lineTo(0, bas)
      ..close();
  }

  @override
  bool shouldRepaint(_PeintreBandeau ancien) =>
      ancien.toile != toile ||
      ancien.decors != decors ||
      ancien.barreEtat != barreEtat;
}

/// Le bouton secondaire des maquettes (« Se connecter » sous « Créer un
/// compte ») : fond de la toile, contour au dégradé de la charte, libellé
/// violet.
class GradientOutlinedButton extends StatelessWidget {
  const GradientOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;
    const rayon = BorderRadius.all(Radius.circular(16));
    final bouton = DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: rayon,
        gradient: LinearGradient(colors: ShopColors.gradient),
      ),
      child: Padding(
        // Le contour : 1,5 pt de dégradé autour du fond.
        padding: const EdgeInsets.all(1.5),
        child: Material(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.all(Radius.circular(14.5)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              height: 53,
              width: double.infinity,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: ShopTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: sombre
                        ? ShopColors.primaryLight
                        : ShopColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Dessiné à la main : il se déclare bouton aux lecteurs d'écran.
    return MergeSemantics(
      child: Semantics(button: true, enabled: onPressed != null, child: bouton),
    );
  }
}

/// Le bouton principal des maquettes : 56 pt de haut, coins de 16 pt, le
/// dégradé de la charte à 90° et son halo violet.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null && !isLoading;
    const rayon = BorderRadius.all(Radius.circular(16));
    final bouton = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: rayon,
        boxShadow: [
          if (actif)
            BoxShadow(
              color: ShopColors.primary.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: rayon,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                for (final couleur in ShopColors.gradient)
                  onPressed == null ? couleur.withValues(alpha: 0.4) : couleur,
              ],
            ),
          ),
          child: InkWell(
            onTap: actif ? onPressed : null,
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Center(
                child: isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          fontFamily: ShopTheme.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    // Dessiné à la main : il se déclare bouton aux lecteurs d'écran, avec
    // son libellé même quand la roue le remplace.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: actif,
        label: isLoading ? label : null,
        child: bouton,
      ),
    );
  }
}
