// Animation d'introduction « MALI TRADE CONNECT » pour Flutter.
// Aucune dépendance externe : un seul widget, dessiné avec CustomPainter.
//
// Séquence (18 s) :
//   0.4 – 3.2   le contour du Mali se trace (données géographiques réelles)
//   2.8 – 5.8   les filières (producteurs) puis les marchés (acheteurs) apparaissent
//   5.6 – 11.4  les connexions se tracent, les échanges circulent
//   10.6 – 12.6 les flux s'effacent, la carte se remplit aux couleurs du drapeau
//   12.6 – 15   le titre apparaît en haut, au centre
//
// Utilisation :
//   MaliTradeConnectIntro(onFinished: () => Navigator.of(context).pushReplacement(...))
// Un toucher passe l'animation ; une fois terminée, il la rejoue.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const Color _ink = Color(0xFF070D14);
const Color _text = Color(0xFFEEF3F6);
const Color _gold = Color(0xFFFCD116);
const Color _green = Color(0xFF14B53A);
const Color _red = Color(0xFFCE1126);
const Color _cyan = Color(0xFF4FD1E8);
const Color _mint = Color(0xFF7EE8C8);

const double _total = 18.0;

/// Contour du Mali : longitude, latitude, en alternance.
const List<double> _maliLonLat = [
  -12.17, 14.62, -11.83, 14.8, -11.67, 15.39, -11.35, 15.41, -10.65, 15.13, -10.09, 15.33,
  -9.7, 15.26, -9.55, 15.49, -5.54, 15.5, -5.32, 16.2, -5.49, 16.32, -5.97, 20.64,
  -6.45, 24.96, -4.92, 24.98, -1.55, 22.79, 1.82, 20.61, 2.06, 20.14, 2.68, 19.86,
  3.15, 19.69, 3.16, 19.06, 4.27, 19.16, 4.27, 16.85, 3.72, 16.18, 3.64, 15.57,
  2.75, 15.41, 1.39, 15.32, 1.02, 14.97, 0.38, 14.93, -0.27, 14.92, -0.52, 15.12,
  -1.07, 14.97, -2, 14.56, -2.19, 14.25, -2.97, 13.8, -3.1, 13.54, -3.52, 13.34,
  -4.01, 13.47, -4.28, 13.23, -4.43, 12.54, -5.22, 11.71, -5.2, 11.38, -5.47, 10.95,
  -5.4, 10.37, -5.82, 10.22, -6.05, 10.1, -6.21, 10.52, -6.49, 10.41, -6.67, 10.43,
  -6.85, 10.14, -7.62, 10.15, -7.9, 10.3, -8.03, 10.21, -8.34, 10.49, -8.28, 10.79,
  -8.41, 10.91, -8.62, 10.81, -8.58, 11.14, -8.38, 11.39, -8.79, 11.81, -8.9, 12.09,
  -9.13, 12.31, -9.33, 12.33, -9.57, 12.19, -9.89, 12.06, -10.16, 11.84, -10.59, 11.92,
  -10.87, 12.18, -11.04, 12.21, -11.3, 12.08, -11.46, 12.08, -11.51, 12.44, -11.47, 12.76,
  -11.55, 13.14, -11.93, 13.42, -12.12, 13.99,
];

class _Producer {
  const _Producer(this.name, this.lon, this.lat);
  final String name;
  final double lon;
  final double lat;
}

const List<_Producer> _producers = [
  _Producer('Or', -11.0, 13.3),
  _Producer('Arachide', -9.4, 13.9),
  _Producer('Mangues', -8.6, 11.5),
  _Producer('Karité', -7.4, 10.9),
  _Producer('Coton', -5.4, 11.6),
  _Producer('Sésame', -6.6, 12.7),
  _Producer('Riz', -5.9, 14.0),
  _Producer('Bétail', -3.4, 14.8),
  _Producer('Sel', -4.0, 22.2),
];

class _Buyer {
  const _Buyer(this.name, this.angleDeg);
  final String name;
  final double angleDeg; // 0 = nord, sens horaire
}

const List<_Buyer> _buyers = [
  _Buyer('Europe', -12),
  _Buyer('Moyen-Orient', 48),
  _Buyer('Asie', 92),
  _Buyer("Afrique de l'Est", 132),
  _Buyer("Afrique de l'Ouest", 180),
  _Buyer('Amérique du Sud', 232),
  _Buyer('Amérique du Nord', 302),
];

/// Paires (indice producteur, indice acheteur).
const List<List<int>> _pairs = [
  [0, 1], [0, 0], [4, 2], [4, 0], [3, 0], [3, 6], [2, 0], [2, 4], [6, 4],
  [1, 2], [1, 5], [7, 4], [7, 1], [5, 2], [5, 3], [8, 4], [8, 3],
];

double _e(double t, double a, double b) {
  final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

Color _a(Color c, double o) => c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

class MaliTradeConnectIntro extends StatefulWidget {
  const MaliTradeConnectIntro({super.key, this.onFinished});

  /// Appelé une fois l'animation terminée (ou passée d'un toucher).
  final VoidCallback? onFinished;

  @override
  State<MaliTradeConnectIntro> createState() => _MaliTradeConnectIntroState();
}

class _MaliTradeConnectIntroState extends State<MaliTradeConnectIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  _Geo? _geo;
  Size _geoSize = Size.zero;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_total * 1000).round()),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onFinished?.call();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1; // mouvement réduit : on affiche directement l'image finale
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onTap() {
    if (_c.isCompleted) {
      _c.forward(from: 0);
    } else {
      _c.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mali Trade Connect. Relier le Mali aux marchés du monde.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: ColoredBox(
          color: _ink,
          child: LayoutBuilder(builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            if (_geo == null || _geoSize != size) {
              _geo = _Geo(size);
              _geoSize = size;
            }
            final geo = _geo!;
            return AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value * _total;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _IntroPainter(geo, t)),
                    _Title(t: t),
                  ],
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final a = _e(t, 12.6, 14.0);
    final bar = _e(t, 13.2, 14.2);
    final tag = _e(t, 13.8, 15.0);
    if (a <= 0) return const SizedBox.shrink();
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Opacity(
            opacity: a,
            child: Transform.translate(
              offset: Offset(0, (1 - a) * -14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'MALI ', style: TextStyle(color: _gold)),
                        TextSpan(text: 'TRADE CONNECT', style: TextStyle(color: _text)),
                      ]),
                      style: TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Transform.scale(
                    scaleX: bar,
                    child: SizedBox(
                      width: 190,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: const Row(children: [
                          Expanded(child: ColoredBox(color: _green, child: SizedBox.expand())),
                          Expanded(child: ColoredBox(color: _gold, child: SizedBox.expand())),
                          Expanded(child: ColoredBox(color: _red, child: SizedBox.expand())),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: tag,
                    child: const Text(
                      'Relier le Mali aux marchés du monde',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _text, fontSize: 16, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Géométrie calculée une fois par taille d'écran.
class _Geo {
  _Geo(this.size) {
    final w = size.width, h = size.height;
    center = Offset(w / 2, h * 0.54);
    final s = math.min(w * 0.64, h * 0.40);

    // Projection simple (longitude corrigée par le cosinus de la latitude).
    const lon0 = -3.95, lat0 = 17.55;
    final kx = math.cos(lat0 * math.pi / 180);
    double minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
    final raw = <Offset>[];
    for (var i = 0; i < _maliLonLat.length; i += 2) {
      final x = (_maliLonLat[i] - lon0) * kx;
      final y = -(_maliLonLat[i + 1] - lat0);
      raw.add(Offset(x, y));
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    scale = s / math.max(maxX - minX, maxY - minY);
    final mx = (minX + maxX) / 2, my = (minY + maxY) / 2;
    Offset toScreen(double lon, double lat) => Offset(
          center.dx + ((lon - lon0) * kx - mx) * scale,
          center.dy + (-(lat - lat0) - my) * scale,
        );

    mapPath = Path();
    for (var i = 0; i < raw.length; i++) {
      final p = Offset(center.dx + (raw[i].dx - mx) * scale, center.dy + (raw[i].dy - my) * scale);
      if (i == 0) {
        mapPath.moveTo(p.dx, p.dy);
      } else {
        mapPath.lineTo(p.dx, p.dy);
      }
    }
    mapPath.close();
    mapMetric = mapPath.computeMetrics().first;
    bounds = mapPath.getBounds();

    prodPts = [for (final p in _producers) toScreen(p.lon, p.lat)];

    final rx = w * 0.44, ry = h * 0.38;
    ringRx = rx;
    ringRy = ry;
    buyPts = [
      for (final b in _buyers)
        Offset(
          center.dx + rx * math.sin(b.angleDeg * math.pi / 180),
          center.dy - ry * math.cos(b.angleDeg * math.pi / 180),
        ),
    ];

    arcs = [];
    for (final pr in _pairs) {
      final a = prodPts[pr[0]], b = buyPts[pr[1]];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final ctrl = mid + (mid - center) * 0.3;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
      final m = path.computeMetrics().first;
      arcs.add(_Arc(a, b, path, m));
    }

    final rnd = math.Random(7);
    stars = [
      for (var i = 0; i < 150; i++)
        _Star(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h), 0.4 + rnd.nextDouble() * 1.1,
            rnd.nextDouble() * 6.28, 0.25 + rnd.nextDouble() * 0.55),
    ];
  }

  final Size size;
  late final Offset center;
  late final double scale;
  late final Path mapPath;
  late final ui.PathMetric mapMetric;
  late final Rect bounds;
  late final List<Offset> prodPts;
  late final List<Offset> buyPts;
  late final double ringRx;
  late final double ringRy;
  late final List<_Arc> arcs;
  late final List<_Star> stars;
}

class _Arc {
  _Arc(this.a, this.b, this.path, this.metric);
  final Offset a, b;
  final Path path;
  final ui.PathMetric metric;
}

class _Star {
  const _Star(this.p, this.r, this.phase, this.alpha);
  final Offset p;
  final double r, phase, alpha;
}

class _IntroPainter extends CustomPainter {
  _IntroPainter(this.g, this.t);
  final _Geo g;
  final double t;

  static final Paint _fill = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Fond : dégradé profond et étoiles.
    _fill
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height * 0.45),
        math.max(size.width, size.height) * 0.75,
        const [Color(0xFF10202C), Color(0xFF05090E)],
      )
      ..maskFilter = null
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, _fill);
    _fill.shader = null;
    for (final s in g.stars) {
      final tw = 0.65 + 0.35 * math.sin(t * 1.5 + s.phase);
      _fill.color = _a(const Color(0xFFDCE8FF), s.alpha * tw);
      canvas.drawCircle(s.p, s.r, _fill);
    }

    final netA = (1 - _e(t, 10.8, 12.0));
    final flowA = (1 - _e(t, 10.6, 11.6));

    // Anneaux du réseau.
    final ringA = _e(t, 4.2, 5.4) * netA;
    if (ringA > 0) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _a(_cyan, 0.10 * ringA);
      for (final k in const [0.55, 0.8, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(center: g.center, width: g.ringRx * 2 * k, height: g.ringRy * 2 * k),
          ring,
        );
      }
    }

    _drawMap(canvas);
    _drawArcs(canvas, flowA);
    _drawProducers(canvas, netA);
    _drawBuyers(canvas, netA);
  }

  void _drawMap(Canvas canvas) {
    final path = g.mapPath;

    // Remplissage sombre pendant le tracé, puis couleurs du drapeau.
    final dark = _e(t, 2.4, 3.6);
    if (dark > 0) {
      canvas.drawPath(path, Paint()..color = _a(const Color(0xFF0D1822), 0.85 * dark));
    }
    final fa = _e(t, 11.0, 12.6);
    if (fa > 0) {
      canvas.save();
      canvas.clipPath(path);
      final b = g.bounds;
      final third = b.width / 3;
      final cols = [_green, _gold, _red];
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(
          Rect.fromLTWH(b.left + third * i - 0.5, b.top, third + 1, b.height),
          Paint()..color = _a(cols[i], fa),
        );
      }
      // Ombrage doux pour donner du volume.
      canvas.drawRect(
        b,
        Paint()
          ..shader = ui.Gradient.linear(
            b.topCenter,
            b.bottomCenter,
            [_a(Colors.black, 0.05 * fa), _a(Colors.black, 0.32 * fa)],
          ),
      );
      // Reflet qui traverse la carte à l'apparition des couleurs.
      final sweep = _e(t, 11.4, 13.4);
      if (sweep > 0 && sweep < 1) {
        final x = b.left - b.width * 0.3 + sweep * b.width * 1.6;
        canvas.drawRect(
          Rect.fromLTWH(x - b.width * 0.12, b.top, b.width * 0.24, b.height),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(x - b.width * 0.12, 0),
              Offset(x + b.width * 0.12, 0),
              [_a(Colors.white, 0), _a(Colors.white, 0.28), _a(Colors.white, 0)],
              const [0, 0.5, 1],
            ),
        );
      }
      canvas.restore();
    }

    // Contour qui se trace.
    final p = _e(t, 0.4, 3.2);
    if (p <= 0) return;
    final len = g.mapMetric.length;
    final traced = p >= 1 ? path : g.mapMetric.extractPath(0, len * p);
    canvas.drawPath(
      traced,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round
        ..color = _a(_gold, 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      traced,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFF3C4),
    );
    if (p < 1) {
      final tan = g.mapMetric.getTangentForOffset(len * p);
      if (tan != null) _glowDot(canvas, tan.position, 4.5, _gold, 1);
    }
  }

  void _drawArcs(Canvas canvas, double flowA) {
    if (flowA <= 0) return;
    for (var i = 0; i < g.arcs.length; i++) {
      final arc = g.arcs[i];
      final start = 5.6 + i * 0.17;
      final p = ((t - start) / 1.4).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final len = arc.metric.length;
      final seg = arc.metric.extractPath(0, len * p);
      final shader = ui.Gradient.linear(arc.a, arc.b, [_a(_gold, 0.7 * flowA), _a(_cyan, 0.7 * flowA)]);
      canvas.drawPath(
        seg,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        seg,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
      if (p < 1) {
        final tan = arc.metric.getTangentForOffset(len * p);
        if (tan != null) _glowDot(canvas, tan.position, 3.5, Colors.white, flowA);
        continue;
      }
      // Colis (doré) vers l'acheteur, paiement (menthe) vers le producteur.
      final on = _e(t, start + 1.4, start + 2.2);
      for (var q = 0; q < 3; q++) {
        final back = q == 2;
        var ph = ((t - start - 1.4) / 3.4 + q / 3.0) % 1.0;
        if (ph < 0) ph += 1;
        final tan = arc.metric.getTangentForOffset(len * (back ? 1 - ph : ph));
        if (tan == null) continue;
        final al = on * flowA * math.sin(ph * math.pi);
        _glowDot(canvas, tan.position, back ? 3 : 4, back ? _mint : _gold, al);
      }
    }
  }

  void _drawProducers(Canvas canvas, double netA) {
    for (var i = 0; i < g.prodPts.length; i++) {
      final pop = _e(t, 2.8 + i * 0.18, 3.5 + i * 0.18) * netA;
      if (pop <= 0) continue;
      final c = g.prodPts[i];
      final ph = (t * 0.55 + i * 0.23) % 1.0;
      canvas.drawCircle(
        c,
        6 + ph * 18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _a(_gold, 0.55 * (1 - ph) * pop),
      );
      _glowDot(canvas, c, 4.5 * pop + 1, _gold, pop);
    }
  }

  void _drawBuyers(Canvas canvas, double netA) {
    for (var j = 0; j < g.buyPts.length; j++) {
      final pop = _e(t, 4.4 + j * 0.25, 5.1 + j * 0.25) * netA;
      if (pop <= 0) continue;
      final c = g.buyPts[j];
      final r = 9.0 * pop;
      final hex = Path();
      for (var k = 0; k < 6; k++) {
        final a = math.pi / 6 + k * math.pi / 3;
        final x = c.dx + r * math.cos(a), y = c.dy + r * math.sin(a);
        if (k == 0) {
          hex.moveTo(x, y);
        } else {
          hex.lineTo(x, y);
        }
      }
      hex.close();
      canvas.drawPath(hex, Paint()..color = _a(const Color(0xFF123A48), 0.9 * pop));
      canvas.drawPath(
        hex,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _a(_cyan, pop),
      );
      _glowDot(canvas, c, 3 * pop, _cyan, pop);

      final tp = TextPainter(
        text: TextSpan(
          text: _buyers[j].name.toUpperCase(),
          style: TextStyle(
            color: _a(_cyan, 0.9 * pop),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Le libellé se place du côté du centre pour rester dans l'écran.
      final toward = (g.center - c);
      final dx = toward.dx >= 0 ? 14.0 : -14.0 - tp.width;
      var x = c.dx + dx;
      x = x.clamp(6.0, g.size.width - tp.width - 6.0);
      tp.paint(canvas, Offset(x, c.dy - tp.height / 2));
    }
  }

  void _glowDot(Canvas canvas, Offset c, double r, Color color, double alpha) {
    if (alpha <= 0) return;
    canvas.drawCircle(
      c,
      r * 2.6,
      Paint()
        ..color = _a(color, 0.5 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.4),
    );
    canvas.drawCircle(c, r * 0.8, Paint()..color = _a(Colors.white, 0.9 * alpha));
    canvas.drawCircle(c, r, Paint()..color = _a(color, alpha));
    canvas.drawCircle(c, r * 0.45, Paint()..color = _a(Colors.white, 0.95 * alpha));
  }

  @override
  bool shouldRepaint(covariant _IntroPainter old) => old.t != t || old.g != g;
}
