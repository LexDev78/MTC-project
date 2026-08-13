import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_colors.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';

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
  static const _boxSize = 28.0;
  static const _startTop = -56.0;
  // Boxes land two at a time, side by side, instead of stacking one on top
  // of another — two short rows inside the basket instead of one tall
  // column. Index 0/1 are the bottom row (fall first), 2/3 the top row.
  static const _boxLandingTops = [110.0, 110.0, 86.0, 86.0];
  static const _boxLandingLefts = [80.0, 112.0, 80.0, 112.0];
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
    final user = ref.read(currentUserProvider).valueOrNull;
    ref.read(justLoggedInProvider.notifier).state = false;
    context.go(switch (user) {
      SupplierTiersUser(:final needsOnboarding) =>
        needsOnboarding
            ? AppRoutes.supplierOnboarding
            : AppRoutes.supplierTiersDashboard,
      SupplierPrincipalUser() => AppRoutes.supplierPrincipalDashboard,
      ClientUser() || null => AppRoutes.clientHome,
    });
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  /// The timeline fraction at which box [index] starts falling. Boxes 0&1
  /// land in the bottom row and 2&3 in the top row, but each box still
  /// falls on its own slightly offset timing within its row's window —
  /// falling in perfect lockstep read as too mechanical — so they don't
  /// land at the exact same instant even though they end up side by side.
  double _boxStart(int index) {
    final row = index ~/ 2;
    final withinRow = index % 2;
    return 0.04 + row * 0.34 + withinRow * 0.08;
  }

  /// 0..1 fall progress for box [index] at overall timeline position [t].
  double _boxProgress(int index, double t) {
    final start = _boxStart(index);
    final end = start + 0.30;
    return ((t - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// How hard the cart should squash right as a crate lands — the peak
  /// bounce for whichever box just finished falling at timeline position
  /// [t], so the cart visibly reacts to each impact.
  double _cartSquash(double t) {
    var squash = 0.0;
    for (var i = 0; i < _boxLandingTops.length; i++) {
      final landedAt = _boxStart(i) + 0.30;
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
