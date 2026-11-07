import 'package:mtc_app/features/visual_search/domain/visual_search_result.dart';
import 'package:mtc_app/features/visual_search/presentation/providers/visual_search_providers.dart';
import 'package:mtc_app/features/visual_search/presentation/screens/visual_search_screen.dart';

import '../support/shop_capture.dart';
import '../support/shop_fixtures.dart';

/// La recherche par photo dans un état donné, sans appareil ni serveur.
class _Etat extends VisualSearchController {
  _Etat(this._construire);

  final Future<VisualSearchState?> Function() _construire;

  @override
  Future<VisualSearchState?> build() => _construire();
}

void main() {
  capturerEcran(
    'photo_invitation',
    () => const VisualSearchScreen(),
    overrides: () => [
      visualSearchProvider.overrideWith(() => _Etat(() async => null)),
    ],
  );
  capturerEcran(
    'photo_resultats',
    () => const VisualSearchScreen(),
    overrides: () => [
      visualSearchProvider.overrideWith(
        () => _Etat(
          () async => VisualSearchState(
            products: catalogueDemo().take(4).toList(),
            remaining: 7,
          ),
        ),
      ),
    ],
  );
  capturerEcran(
    'photo_rien',
    () => const VisualSearchScreen(),
    overrides: () => [
      visualSearchProvider.overrideWith(
        () => _Etat(
          () async => const VisualSearchState(products: [], remaining: 1),
        ),
      ),
    ],
  );
  capturerEcran(
    'photo_quota',
    () => const VisualSearchScreen(),
    overrides: () => [
      visualSearchProvider.overrideWith(
        () => _Etat(
          () async => throw const VisualSearchException(
            'Vous avez fait vos 10 recherches par photo du jour. Revenez '
            'demain, ou cherchez par mot-clé.',
            quotaExhausted: true,
          ),
        ),
      ),
    ],
  );
}
