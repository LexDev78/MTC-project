import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A "spy cat" avatar for the login screen, drawn sitting with its tail
/// curled and front paws resting on the ground. It follows the
/// username/phone field with its gaze, visibly raises its paws up to cover
/// its eyes once the password field takes focus (and lowers them back down
/// when focus leaves), and — whenever neither field has focus — tracks a
/// little ball that bounces around the avatar.
class WatchingCatAvatar extends StatefulWidget {
  const WatchingCatAvatar({
    super.key,
    required this.isPasswordFocused,
    required this.gazeOffset,
    this.isTyping = false,
    this.hasError = false,
    this.size = 160,
  });

  final bool isPasswordFocused;

  /// -1.0 (left) to 1.0 (right).
  final double gazeOffset;

  /// True while the field below the avatar (username/phone) has focus, so
  /// the cat looks down towards it instead of straight ahead.
  final bool isTyping;

  /// True after a failed login attempt: the cat stops watching the ball,
  /// stares straight ahead, and its eyes turn red until the user edits or
  /// refocuses a field.
  final bool hasError;
  final double size;

  @override
  State<WatchingCatAvatar> createState() => _WatchingCatAvatarState();
}

class _WatchingCatAvatarState extends State<WatchingCatAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _closeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 320),
    value: widget.isPasswordFocused ? 1 : 0,
  );
  late final Animation<double> _closeCurve = CurvedAnimation(
    parent: _closeController,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// Plays a short decaying side-to-side swish when the cat is tapped.
  late final AnimationController _wagController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// A little ball that bounces around the avatar's bounds forever; the cat
  /// tracks it with its gaze whenever neither field has focus.
  final _random = math.Random();
  late Offset _ballPosition;
  late Offset _ballVelocity;
  Ticker? _ballTicker;
  Duration _lastBallElapsed = Duration.zero;

  double get _ballRadius => widget.size * 0.05;

  bool get _isIdle =>
      !widget.isPasswordFocused && !widget.isTyping && !widget.hasError;

  @override
  void initState() {
    super.initState();
    _ballPosition = Offset(widget.size * 0.5, widget.size * 0.14);
    final angle = _random.nextDouble() * 2 * math.pi;
    final speed = widget.size * 0.55;
    _ballVelocity = Offset(math.cos(angle), math.sin(angle)) * speed;
    _ballTicker = createTicker(_onBallTick);
    // Only bounces (and needs repainting every frame) while the cat is
    // actually watching it — paused the moment a field takes focus, both to
    // avoid distracting from typing and so this doesn't tick forever.
    if (_isIdle) _ballTicker!.start();
  }

  void _onBallTick(Duration elapsed) {
    // Capped rather than dropped: a big single jump (e.g. a widget test
    // advancing the clock by a fixed duration in one step, or the app
    // resuming from background) still moves the ball a bounded amount
    // instead of freezing it or having it tunnel through a wall.
    final dt = ((elapsed - _lastBallElapsed).inMicroseconds / 1e6).clamp(
      0.0,
      0.1,
    );
    _lastBallElapsed = elapsed;
    if (dt <= 0) return;

    final size = widget.size;
    final radius = _ballRadius;
    var pos = _ballPosition + _ballVelocity * dt;
    var vel = _ballVelocity;

    if (pos.dx - radius <= 0) {
      pos = Offset(radius, pos.dy);
      vel = Offset(vel.dx.abs(), vel.dy);
    } else if (pos.dx + radius >= size) {
      pos = Offset(size - radius, pos.dy);
      vel = Offset(-vel.dx.abs(), vel.dy);
    }
    if (pos.dy - radius <= 0) {
      pos = Offset(pos.dx, radius);
      vel = Offset(vel.dx, vel.dy.abs());
    } else if (pos.dy + radius >= size) {
      pos = Offset(pos.dx, size - radius);
      vel = Offset(vel.dx, -vel.dy.abs());
    }

    setState(() {
      _ballPosition = pos;
      _ballVelocity = vel;
    });
  }

  void _handleTap() {
    _wagController.forward(from: 0);
  }

  /// -1..1, decaying oscillation driving the tail's lateral swish.
  double get _tailWag {
    final v = _wagController.value;
    if (v <= 0) return 0;
    return math.sin(v * math.pi * 3.5) * (1 - v);
  }

  @override
  void didUpdateWidget(covariant WatchingCatAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPasswordFocused != oldWidget.isPasswordFocused) {
      if (widget.isPasswordFocused) {
        _closeController.forward();
      } else {
        _closeController.reverse();
      }
    }
    final wasIdle =
        !oldWidget.isPasswordFocused &&
        !oldWidget.isTyping &&
        !oldWidget.hasError;
    if (_isIdle != wasIdle) {
      if (_isIdle) {
        // A fresh start() begins its elapsed clock at zero again, so reset
        // the reference point too or the first post-resume tick would see
        // a huge negative dt against the stale pre-pause value.
        _lastBallElapsed = Duration.zero;
        _ballTicker!.start();
      } else {
        _ballTicker!.stop();
      }
    }
  }

  @override
  void dispose() {
    _closeController.dispose();
    _wagController.dispose();
    _ballTicker?.dispose();
    super.dispose();
  }

  /// -1.0..1.0 on both axes; dy > 0 looks down. When idle, points towards
  /// the bouncing ball.
  Offset get _gaze {
    if (widget.isPasswordFocused) return Offset.zero;
    if (widget.isTyping) return Offset(widget.gazeOffset, 1);
    if (widget.hasError) return Offset.zero;
    final headCenter = Offset(widget.size / 2, widget.size * 0.32);
    final toBall = _ballPosition - headCenter;
    final distance = toBall.distance;
    if (distance < 1) return Offset.zero;
    final direction = toBall / distance;
    return Offset(direction.dx.clamp(-1.0, 1.0), direction.dy.clamp(-1.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_closeCurve, _wagController]),
          builder: (context, _) {
            final gaze = _gaze;
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _CatPainter(
                closeProgress: _closeCurve.value,
                gazeDx: gaze.dx,
                gazeDy: gaze.dy,
                isTyping: widget.isTyping,
                hasError: widget.hasError,
                tailWag: _tailWag,
                ballPosition: _ballPosition,
                ballRadius: _ballRadius,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CatPainter extends CustomPainter {
  _CatPainter({
    required this.closeProgress,
    required this.gazeDx,
    required this.gazeDy,
    required this.isTyping,
    required this.hasError,
    required this.tailWag,
    required this.ballPosition,
    required this.ballRadius,
  });

  /// 0 = paws resting on the ground, eyes open. 1 = paws raised fully
  /// covering the eyes.
  final double closeProgress;

  /// Roughly -1.0..1.0 on both axes; dy > 0 looks down.
  final double gazeDx;
  final double gazeDy;
  final bool isTyping;

  /// True after a failed login attempt: irises render red instead of black.
  final bool hasError;

  /// -1..1, lateral swish of the tail (triggered by tapping the cat).
  final double tailWag;

  final Offset ballPosition;
  final double ballRadius;

  static const Color furColor = Color(0xFFE8A33D);
  static const Color furShade = Color(0xFFD8862A);
  static const Color innerEarColor = Color(0xFFF6C98A);
  static const Color pawColor = Color(0xFFFBDDA8);
  static const Color pawOutline = Color(0xFFB5651D);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = closeProgress.clamp(0.0, 1.0);

    final furPaint = Paint()..color = furColor;
    final earPaint = Paint()..color = innerEarColor;

    final headCenter = Offset(w / 2, h * 0.32);
    final headRadius = w * 0.235;
    final bodyCenter = Offset(w / 2, h * 0.68);

    _drawTail(canvas, bodyCenter, w, h, tailWag);
    _drawBody(canvas, w, h, headCenter, headRadius, furPaint, bodyCenter);

    // Oreilles
    final earSize = headRadius * 0.72;
    final earY = headCenter.dy - headRadius * 0.68;
    canvas.drawPath(
      _earPath(Offset(headCenter.dx - headRadius * 0.62, earY), earSize),
      furPaint,
    );
    canvas.drawPath(
      _earPath(
        Offset(headCenter.dx + headRadius * 0.62, earY),
        earSize,
        flip: true,
      ),
      furPaint,
    );
    canvas.drawPath(
      _earPath(
        Offset(headCenter.dx - headRadius * 0.62, earY),
        earSize * 0.55,
      ),
      earPaint,
    );
    canvas.drawPath(
      _earPath(
        Offset(headCenter.dx + headRadius * 0.62, earY),
        earSize * 0.55,
        flip: true,
      ),
      earPaint,
    );

    // Tête
    canvas.drawCircle(headCenter, headRadius, furPaint);

    // Ombrage léger sous la tête pour du relief
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headRadius),
      0.2,
      math.pi - 0.4,
      false,
      Paint()
        ..color = furShade.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02,
    );

    final eyeY = headCenter.dy - headRadius * 0.04;
    final eyeDx = headRadius * 0.42;
    final leftEyeCenter = Offset(headCenter.dx - eyeDx, eyeY);
    final rightEyeCenter = Offset(headCenter.dx + eyeDx, eyeY);
    final eyeRadius = headRadius * 0.24;

    // Yeux ouverts (blanc + pupille qui suit le regard), en train de
    // s'estomper à mesure que les pattes montent.
    if (t < 0.999) {
      final openAlpha = 1 - t;
      final scleraColor = hasError ? const Color(0xFFE03131) : Colors.white;
      for (final eyeCenter in [leftEyeCenter, rightEyeCenter]) {
        canvas.drawCircle(
          eyeCenter,
          eyeRadius,
          Paint()..color = scleraColor.withValues(alpha: openAlpha),
        );
        final pupilOffset = Offset(
          eyeCenter.dx + gazeDx * eyeRadius * 0.45,
          eyeCenter.dy + gazeDy * eyeRadius * 0.42,
        );
        canvas.drawCircle(
          pupilOffset,
          eyeRadius * 0.55,
          Paint()..color = const Color(0xFF2C2C2A).withValues(alpha: openAlpha),
        );
        canvas.drawCircle(
          Offset(
            pupilOffset.dx - eyeRadius * 0.15,
            pupilOffset.dy - eyeRadius * 0.15,
          ),
          eyeRadius * 0.15,
          Paint()..color = Colors.white.withValues(alpha: openAlpha),
        );
      }
    }

    // Yeux fermés : arcs "^", apparaissant à mesure que les pattes montent.
    if (t > 0.001) {
      final closedPaint = Paint()
        ..color = const Color(0xFF2C2C2A).withValues(alpha: t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02
        ..strokeCap = StrokeCap.round;
      for (final eyeCenter in [leftEyeCenter, rightEyeCenter]) {
        final path = Path()
          ..moveTo(eyeCenter.dx - eyeRadius * 0.8, eyeCenter.dy)
          ..quadraticBezierTo(
            eyeCenter.dx,
            eyeCenter.dy - eyeRadius * 0.9,
            eyeCenter.dx + eyeRadius * 0.8,
            eyeCenter.dy,
          );
        canvas.drawPath(path, closedPaint);
      }
    }

    // Pattes avant : interpolées entre leur position au repos (posées au
    // sol) et leur position levée devant les yeux, avec les bras qui les
    // relient aux épaules pendant la montée.
    final restLeftPaw = Offset(bodyCenter.dx - w * 0.15, h * 0.885);
    final restRightPaw = Offset(bodyCenter.dx + w * 0.15, h * 0.885);
    final raisedLeftPaw = Offset(
      leftEyeCenter.dx,
      leftEyeCenter.dy + eyeRadius * 0.1,
    );
    final raisedRightPaw = Offset(
      rightEyeCenter.dx,
      rightEyeCenter.dy + eyeRadius * 0.1,
    );
    final leftPawPos = Offset.lerp(restLeftPaw, raisedLeftPaw, t)!;
    final rightPawPos = Offset.lerp(restRightPaw, raisedRightPaw, t)!;
    final pawSize = _lerpD(w * 0.20, w * 0.24, t);
    final leftRotation = _lerpD(-0.08, -0.18, t);
    final rightRotation = _lerpD(0.08, 0.18, t);

    if (t > 0.01) {
      final armPaint = Paint()
        ..color = furColor.withValues(alpha: t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085
        ..strokeCap = StrokeCap.round;
      final leftShoulder = Offset(
        headCenter.dx - headRadius * 0.85,
        headCenter.dy + headRadius * 0.95,
      );
      final rightShoulder = Offset(
        headCenter.dx + headRadius * 0.85,
        headCenter.dy + headRadius * 0.95,
      );
      canvas.drawLine(leftShoulder, leftPawPos, armPaint);
      canvas.drawLine(rightShoulder, rightPawPos, armPaint);
    }

    _drawPaw(canvas, leftPawPos, pawSize, rotation: leftRotation);
    _drawPaw(canvas, rightPawPos, pawSize, rotation: rightRotation);

    // Museau + moustaches (visibles même les yeux fermés, c'est mignon)
    final noseCenter = Offset(
      headCenter.dx,
      headCenter.dy + headRadius * 0.38,
    );
    canvas.drawPath(
      Path()
        ..moveTo(noseCenter.dx - 5, noseCenter.dy)
        ..lineTo(noseCenter.dx + 5, noseCenter.dy)
        ..lineTo(noseCenter.dx, noseCenter.dy + 5)
        ..close(),
      Paint()..color = const Color(0xFFB5651D),
    );

    final whiskerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final side in [-1, 1]) {
      for (final dy in [-4.0, 4.0, 12.0]) {
        canvas.drawLine(
          Offset(noseCenter.dx + side * 8, noseCenter.dy + dy * 0.4),
          Offset(noseCenter.dx + side * (w * 0.22), noseCenter.dy + dy),
          whiskerPaint,
        );
      }
    }

    // Sourire, seulement pendant la saisie (yeux ouverts) : deux courbes en
    // "w" partant du museau, la bouche de chat classique.
    if (isTyping && !hasError && t < 0.05) {
      final smilePaint = Paint()
        ..color = const Color(0xFF2C2C2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.014
        ..strokeCap = StrokeCap.round;
      final mouthTop = Offset(noseCenter.dx, noseCenter.dy + 4);
      for (final side in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(mouthTop.dx, mouthTop.dy)
            ..quadraticBezierTo(
              mouthTop.dx + side * w * 0.06,
              mouthTop.dy + w * 0.05,
              mouthTop.dx + side * w * 0.11,
              mouthTop.dy - w * 0.005,
            ),
          smilePaint,
        );
      }
    }

    _drawBall(canvas);
  }

  /// A little bouncing ball of yarn, drawn on top of everything else so it
  /// stays visible wherever it bounces to.
  void _drawBall(Canvas canvas) {
    canvas.drawCircle(ballPosition, ballRadius, Paint()..color = const Color(0xFFE24C6B));
    canvas.drawCircle(
      Offset(ballPosition.dx - ballRadius * 0.3, ballPosition.dy - ballRadius * 0.3),
      ballRadius * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
    final yarnPaint = Paint()
      ..color = const Color(0xFFB23A54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ballRadius * 0.12;
    canvas.drawArc(
      Rect.fromCircle(center: ballPosition, radius: ballRadius * 0.7),
      0.3,
      2.2,
      false,
      yarnPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: ballPosition, radius: ballRadius * 0.7),
      3.4,
      2.0,
      false,
      yarnPaint,
    );
  }

  double _lerpD(double a, double b, double t) => a + (b - a) * t;

  /// The seated body silhouette: haunches on the ground, tapering up to the
  /// shoulders beneath the head.
  void _drawBody(
    Canvas canvas,
    double w,
    double h,
    Offset headCenter,
    double headRadius,
    Paint furPaint,
    Offset bodyCenter,
  ) {
    final shoulderY = headCenter.dy + headRadius * 0.85;
    final body = Path()
      ..moveTo(bodyCenter.dx - w * 0.30, h * 0.90)
      ..quadraticBezierTo(
        bodyCenter.dx - w * 0.34,
        h * 0.58,
        bodyCenter.dx - w * 0.19,
        shoulderY,
      )
      ..quadraticBezierTo(bodyCenter.dx, h * 0.56, bodyCenter.dx + w * 0.19, shoulderY)
      ..quadraticBezierTo(
        bodyCenter.dx + w * 0.34,
        h * 0.58,
        bodyCenter.dx + w * 0.30,
        h * 0.90,
      )
      ..quadraticBezierTo(bodyCenter.dx, h * 1.0, bodyCenter.dx - w * 0.30, h * 0.90)
      ..close();
    canvas.drawPath(body, furPaint);

    // Pelage plus clair sur le poitrail, pour du relief.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyCenter.dx, h * 0.80),
        width: w * 0.24,
        height: h * 0.26,
      ),
      Paint()..color = innerEarColor.withValues(alpha: 0.5),
    );
  }

  /// Tail curling from behind the body up towards the shoulder. [tailWag]
  /// (-1..1) shifts the free end sideways for a tap-triggered swish — the
  /// base stays anchored to the body, the tip swings the most.
  void _drawTail(
    Canvas canvas,
    Offset bodyCenter,
    double w,
    double h,
    double tailWag,
  ) {
    final tailPaint = Paint()
      ..color = furColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;
    final midShift = tailWag * w * 0.05;
    final tipShift = tailWag * w * 0.10;
    final path = Path()
      ..moveTo(bodyCenter.dx + w * 0.27, h * 0.86)
      ..quadraticBezierTo(
        bodyCenter.dx + w * 0.50 + midShift,
        h * 0.82,
        bodyCenter.dx + w * 0.46 + midShift,
        h * 0.62,
      )
      ..quadraticBezierTo(
        bodyCenter.dx + w * 0.40 + tipShift,
        h * 0.50,
        bodyCenter.dx + w * 0.24 + tipShift,
        h * 0.50,
      );
    canvas.drawPath(path, tailPaint);
    canvas.drawCircle(
      Offset(bodyCenter.dx + w * 0.24 + tipShift, h * 0.50),
      w * 0.045,
      Paint()..color = furColor,
    );
  }

  void _drawPaw(
    Canvas canvas,
    Offset base,
    double pawSize, {
    required double rotation,
  }) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(rotation);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: pawSize,
      height: pawSize * 1.2,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(pawSize / 2));
    // Filled in a lighter tone than the head fur, with a dark outline, so
    // the paw reads clearly against the body/face instead of blending in.
    canvas.drawRRect(rrect, Paint()..color = pawColor);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = pawOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = pawSize * 0.045,
    );
    // Petits coussinets
    final padPaint = Paint()..color = pawOutline;
    for (final dx in [-pawSize * 0.18, 0.0, pawSize * 0.18]) {
      canvas.drawCircle(Offset(dx, pawSize * 0.35), pawSize * 0.09, padPaint);
    }
    canvas.restore();
  }

  Path _earPath(Offset tip, double size, {bool flip = false}) {
    final dir = flip ? -1.0 : 1.0;
    return Path()
      ..moveTo(tip.dx, tip.dy - size)
      ..lineTo(tip.dx - size * 0.65 * dir, tip.dy + size * 0.5)
      ..lineTo(tip.dx + size * 0.65 * dir, tip.dy + size * 0.5)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _CatPainter oldDelegate) =>
      oldDelegate.closeProgress != closeProgress ||
      oldDelegate.gazeDx != gazeDx ||
      oldDelegate.gazeDy != gazeDy ||
      oldDelegate.isTyping != isTyping ||
      oldDelegate.hasError != hasError ||
      oldDelegate.tailWag != tailWag ||
      oldDelegate.ballPosition != ballPosition;
}
