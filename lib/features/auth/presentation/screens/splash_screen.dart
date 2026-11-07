import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';

/// Session-restore gate shown (invisibly) on app start. `route_guards.dart`
/// redirects away as soon as `currentUserProvider` resolves — the timer
/// below is just a fallback for the (normally unreachable) case where that
/// never settles.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) context.go(AppRoutes.welcome);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pas `Colors.white` : c'est le tout premier pixel de l'app, et en mode
    // sombre un écran blanc d'une demi-seconde avant un écran presque noir
    // est un flash en pleine figure.
    return const Scaffold();
  }
}
