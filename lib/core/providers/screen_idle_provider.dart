import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the client has gone [idleThreshold] without any real pointer
/// activity (tap, drag, scroll — anywhere on the screen, not just on one
/// widget). `ScreenIdleDetector` (core/widgets) feeds this by reporting
/// every pointer event it sees.
///
/// ATTENTION — plus aucun lecteur aujourd'hui. Son unique consommateur
/// était `_AutoScrollingProductRow`, dans les rangées par catégorie de
/// l'accueil : elles n'auto-avançaient que pendant l'inactivité, pour que
/// le défilement ne se batte jamais avec la navigation du client. La
/// restructuration de l'accueil a remplacé ces rangées par une grille
/// plate (`CatalogTabScreen` → `ProductGrid`) et ce widget a disparu.
///
/// Il reste donc un `Timer` périodique qui bascule un état que personne ne
/// regarde. Conservé tel quel plutôt que supprimé — à réutiliser si un
/// comportement « au repos » revient (carrousel, rafraîchissement
/// discret…), à supprimer avec `ScreenIdleDetector` et son usage dans
/// `ClientHomeScreen` sinon.
class ScreenIdleNotifier extends Notifier<bool> {
  static const idleThreshold = Duration(seconds: 10);

  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    _armTimer();
    return false;
  }

  /// Called on every real pointer event anywhere on the screen — resets the
  /// idle clock and immediately flips back to "active". Riverpod only
  /// notifies watchers when the value actually changes, so re-arming the
  /// timer while already active is cheap.
  void registerActivity() {
    state = false;
    _armTimer();
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = Timer(idleThreshold, () => state = true);
  }
}

final screenIdleProvider = NotifierProvider<ScreenIdleNotifier, bool>(
  ScreenIdleNotifier.new,
);
