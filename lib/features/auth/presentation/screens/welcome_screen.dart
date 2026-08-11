import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/mtc_primary_button.dart';

/// First screen shown to a signed-out visitor, before [LoginScreen]. Purely
/// a brand/mood moment — bouncing balls that swap colour and reflect off
/// each other and the screen edges — with a single "Commencer" action that
/// hands off to the login flow.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  static const _palette = [
    Color(0xFFB8B0F5),
    Color(0xFFFFD9A0),
    Color(0xFFA8E6D6),
    Color(0xFFF5B8C4),
    Color(0xFFA9D4F5),
    Color(0xFFF7E7A6),
  ];
  static const _ballCount = 5;

  final _random = math.Random();
  final List<_Ball> _balls = [];
  Size? _boundsSize;
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _entrance,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _initBalls(Size size) {
    if (_balls.isNotEmpty) return;
    for (var i = 0; i < _ballCount; i++) {
      final radius = 48.0 + _random.nextDouble() * 34;
      final position = Offset(
        radius + _random.nextDouble() * (size.width - radius * 2),
        radius + _random.nextDouble() * (size.height - radius * 2),
      );
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 50.0 + _random.nextDouble() * 70;
      _balls.add(
        _Ball(
          position: position,
          velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
          radius: radius,
          color: _palette[_random.nextInt(_palette.length)],
        ),
      );
    }
  }

  void _onTick(Duration elapsed) {
    final size = _boundsSize;
    if (size == null || size.isEmpty) return;

    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0 || dt > 0.1) return;

    for (final ball in _balls) {
      ball.position += ball.velocity * dt;

      if (ball.position.dx - ball.radius <= 0) {
        ball.position = Offset(ball.radius, ball.position.dy);
        ball.velocity = Offset(ball.velocity.dx.abs(), ball.velocity.dy);
        ball.color = _nextColor(ball.color);
      } else if (ball.position.dx + ball.radius >= size.width) {
        ball.position = Offset(size.width - ball.radius, ball.position.dy);
        ball.velocity = Offset(-ball.velocity.dx.abs(), ball.velocity.dy);
        ball.color = _nextColor(ball.color);
      }

      if (ball.position.dy - ball.radius <= 0) {
        ball.position = Offset(ball.position.dx, ball.radius);
        ball.velocity = Offset(ball.velocity.dx, ball.velocity.dy.abs());
        ball.color = _nextColor(ball.color);
      } else if (ball.position.dy + ball.radius >= size.height) {
        ball.position = Offset(ball.position.dx, size.height - ball.radius);
        ball.velocity = Offset(ball.velocity.dx, -ball.velocity.dy.abs());
        ball.color = _nextColor(ball.color);
      }
    }

    for (var i = 0; i < _balls.length; i++) {
      for (var j = i + 1; j < _balls.length; j++) {
        _resolveCollision(_balls[i], _balls[j]);
      }
    }

    setState(() {});
  }

  /// Equal-mass elastic collision: swap the velocity components along the
  /// line joining the two centres, and separate any overlap so balls don't
  /// stick together mid-collision.
  void _resolveCollision(_Ball a, _Ball b) {
    final delta = b.position - a.position;
    final distance = delta.distance;
    final minDistance = a.radius + b.radius;
    if (distance == 0 || distance >= minDistance) return;

    final normal = delta / distance;
    final overlap = minDistance - distance;
    a.position -= normal * (overlap / 2);
    b.position += normal * (overlap / 2);

    final relativeVelocity = a.velocity - b.velocity;
    final speedAlongNormal =
        relativeVelocity.dx * normal.dx + relativeVelocity.dy * normal.dy;
    if (speedAlongNormal < 0) return;

    a.velocity -= normal * speedAlongNormal;
    b.velocity += normal * speedAlongNormal;

    a.color = _nextColor(a.color);
    b.color = _nextColor(b.color);
  }

  Color _nextColor(Color current) {
    if (_palette.length <= 1) return current;
    Color next;
    do {
      next = _palette[_random.nextInt(_palette.length)];
    } while (next == current);
    return next;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF3F1FB);
    return Scaffold(
      backgroundColor: backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _boundsSize = size;
          _initBalls(size);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _BallsPainter(_balls)),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: backgroundColor.withValues(alpha: 0.6),
                ),
              ),
              SafeArea(
                child: FadeTransition(
                  opacity: _fade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Trouver les articles du monde ici',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF221F3B),
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'MTC réunit fournisseurs et clients au même endroit.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(
                                  0xFF221F3B,
                                ).withValues(alpha: 0.65),
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        _AnimatedStartButton(
                          onPressed: () => context.go(AppRoutes.login),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Wraps [MtcPrimaryButton] with a press-scale animation. Uses [Listener]
/// rather than [GestureDetector] so it only observes pointer events instead
/// of competing with the button's own tap handling in the gesture arena.
class _AnimatedStartButton extends StatefulWidget {
  const _AnimatedStartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_AnimatedStartButton> createState() => _AnimatedStartButtonState();
}

class _AnimatedStartButtonState extends State<_AnimatedStartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1, end: 0.93)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _controller.forward(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: double.infinity,
          child: MtcPrimaryButton(
            label: 'Commencer',
            onPressed: widget.onPressed,
          ),
        ),
      ),
    );
  }
}

class _Ball {
  _Ball({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.color,
  });

  Offset position;
  Offset velocity;
  final double radius;
  Color color;
}

class _BallsPainter extends CustomPainter {
  _BallsPainter(this.balls);

  final List<_Ball> balls;

  @override
  void paint(Canvas canvas, Size size) {
    for (final ball in balls) {
      final glowPaint = Paint()
        ..color = ball.color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(ball.position, ball.radius * 1.4, glowPaint);

      final paint = Paint()..color = ball.color.withValues(alpha: 0.92);
      canvas.drawCircle(ball.position, ball.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BallsPainter oldDelegate) => true;
}
