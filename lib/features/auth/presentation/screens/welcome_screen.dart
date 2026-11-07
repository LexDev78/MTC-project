import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/shop/shop.dart';

/// Le premier écran d'un visiteur déconnecté, d'après la maquette
/// « Accueil » de la charte MTC : le bandeau au logo, « Bienvenue ! », puis
/// créer un compte ou se connecter.
///
/// La connexion s'ouvre par-dessus (`push`) : son bouton de retour ramène
/// ici. Les autres moyens de connexion de la maquette (téléphone, e-mail,
/// empreinte) n'existent pas encore : ils n'y sont pas.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // La barre d'état sur la toile, une fois le bandeau défilé.
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: sombre ? Brightness.light : Brightness.dark,
        statusBarBrightness: sombre ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MtcBrandBand(bandeau: MtcBandeau.accueil),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 25),
                    Text(
                      'Bienvenue !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 33,
                        fontWeight: FontWeight.w800,
                        height: 1.26,
                        letterSpacing: -1.1,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connectez-vous ou créez\nun compte pour continuer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 38),
                    GradientButton(
                      label: 'Créer un compte',
                      onPressed: () => context.push(AppRoutes.signUpRole),
                    ),
                    const SizedBox(height: 14),
                    GradientOutlinedButton(
                      label: 'Se connecter',
                      onPressed: () => context.push(AppRoutes.login),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
