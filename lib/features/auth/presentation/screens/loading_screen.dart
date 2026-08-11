import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_colors.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';

import '../providers/auth_providers.dart';

/// Shown right after a successful login, before the role's dashboard
/// appears (`route_guards.dart` detours here instead of going straight to
/// the dashboard whenever `justLoggedInProvider` is set). Small crates fall
/// into a cart one by one, then the loaded cart wheels off — giving the
/// login → dashboard hand-off its own "getting everything ready" moment
/// instead of an instant cut.
class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen>
    with SingleTickerProviderStateMixin {
  static const _sceneWidth = 220.0;
  static const _cartSize = 96.0;
  static const _boxSize = 32.0;
  static const _startTop = -56.0;
  static const _boxLandingTops = [122.0, 104.0, 86.0, 68.0];
  static const _boxLandingLefts = [70.0, 94.0, 118.0, 142.0];
  static const _exitStart = 0.8;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatusChanged);
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final role = ref.read(currentUserProvider).valueOrNull?.role;
    ref.read(justLoggedInProvider.notifier).state = false;
    context.go(switch (role) {
      UserRole.supplierTiers => AppRoutes.supplierTiersDashboard,
      UserRole.supplierPrincipal => AppRoutes.supplierPrincipalDashboard,
      UserRole.client || null => AppRoutes.clientHome,
    });
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  /// 0..1 fall progress for box [index] at overall timeline position [t] —
  /// staggered so the crates drop into the cart one after another.
  double _boxProgress(int index, double t) {
    final start = 0.04 + index * 0.15;
    final end = start + 0.30;
    return ((t - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// How hard the cart should squash right as a crate lands — the peak
  /// bounce for whichever box just finished falling at timeline position
  /// [t], so the cart visibly reacts to each impact.
  double _cartSquash(double t) {
    var squash = 0.0;
    for (var i = 0; i < _boxLandingTops.length; i++) {
      final landedAt = 0.04 + i * 0.15 + 0.30;
      const window = 0.06;
      final distance = (t - landedAt).abs();
      if (distance < window) {
        squash = math.max(squash, 1 - distance / window);
      }
    }
    return squash;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.heroGradient,
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final exitT = ((t - _exitStart) / (1 - _exitStart)).clamp(
                0.0,
                1.0,
              );
              final exitFraction = Curves.easeIn.transform(exitT);

              return Opacity(
                opacity: 1 - exitFraction,
                child: Transform.translate(
                  offset: Offset(exitFraction * 280, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: _sceneWidth,
                        height: _boxLandingTops.first + _cartSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (var i = 0; i < _boxLandingTops.length; i++)
                              _fallingBox(index: i, t: t),
                            Positioned(
                              left: (_sceneWidth - _cartSize) / 2,
                              bottom: 0,
                              child: Transform(
                                alignment: Alignment.bottomCenter,
                                transform: Matrix4.diagonal3Values(
                                  1,
                                  1 - _cartSquash(t) * 0.08,
                                  1,
                                ),
                                child: const Icon(
                                  Icons.shopping_cart_rounded,
                                  size: _cartSize,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const Text(
                        'On prépare votre espace…',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _fallingBox({required int index, required double t}) {
    final progress = _boxProgress(index, t);
    final bounced = Curves.bounceOut.transform(progress);
    final landingTop = _boxLandingTops[index];
    final top = _startTop + bounced * (landingTop - _startTop);
    final wobble = (1 - progress) * (index.isEven ? -0.18 : 0.18);
    return Positioned(
      left: _boxLandingLefts[index],
      top: top,
      child: Opacity(
        opacity: progress <= 0 ? 0 : 1,
        child: Transform.rotate(
          angle: wobble,
          child: const Icon(
            Icons.inventory_2_rounded,
            size: _boxSize,
            color: AppColors.brandAccent,
          ),
        ),
      ),
    );
  }
}
