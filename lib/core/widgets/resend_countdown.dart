import 'dart:async';

import 'package:flutter/widgets.dart';

/// Le délai avant de pouvoir redemander un code, seconde par seconde — pour
/// les écrans qui attendent un code envoyé (adresse e-mail, mot de passe
/// oublié). Le serveur tient le même délai : l'écran ne fait que le montrer.
mixin ResendCountdown<T extends StatefulWidget> on State<T> {
  Timer? _minuteurRenvoi;

  /// Secondes avant de pouvoir redemander un code ; 0 quand c'est permis.
  int secondesAvantRenvoi = 0;

  /// « 1:00 », « 0:09 ».
  String get delaiAvantRenvoi =>
      '${secondesAvantRenvoi ~/ 60}:'
      '${(secondesAvantRenvoi % 60).toString().padLeft(2, '0')}';

  /// (Re)part de [secondes]. Appelable depuis `initState`.
  void lancerCompteARebours(int secondes) {
    _minuteurRenvoi?.cancel();
    secondesAvantRenvoi = secondes > 0 ? secondes : 0;
    if (secondesAvantRenvoi == 0) return;
    _minuteurRenvoi = Timer.periodic(const Duration(seconds: 1), (minuteur) {
      if (!mounted) {
        minuteur.cancel();
        return;
      }
      setState(() => secondesAvantRenvoi--);
      if (secondesAvantRenvoi <= 0) minuteur.cancel();
    });
  }

  @override
  void dispose() {
    _minuteurRenvoi?.cancel();
    super.dispose();
  }
}
