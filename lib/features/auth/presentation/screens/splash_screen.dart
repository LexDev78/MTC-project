import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/mtc_brand_mark.dart';

/// Session-restore gate shown briefly on app start. `route_guards.dart`
/// redirects away as soon as `currentUserProvider` resolves — the timer
/// below is just a fallback for the (normally unreachable) case where that
/// never settles. Styled after the real MTC brand mark so the launch
/// sequence (this screen → welcome → login) reads as one deliberate brand
/// moment instead of a generic loading flash.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.85, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) context.go(AppRoutes.welcome);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MtcBrandMark(size: 120),
                SizedBox(height: AppSpacing.lg),
                Text(
                  'MTC',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Mali Trade Connect',
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
                SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: 72,
                  child: Divider(color: MtcBrandMark.teal, thickness: 2),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'IMPORT · E-COMMERCE · RETAIL',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                    color: Colors.black45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
