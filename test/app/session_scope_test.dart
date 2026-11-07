import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/app/session_scope.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/promo_codes/presentation/providers/applied_promo_code_provider.dart';

// Constaté le 18/10/2026 : l'état de l'app survivait au changement de compte
// sur un même appareil — les promotions d'une boutique s'affichaient chez
// la suivante, le formulaire de commande gardait le téléphone du client
// précédent. `SessionScope` repart d'un conteneur neuf quand un compte se
// termine. Le code promo saisi sert ici de témoin : un état local, qui ne
// passe par aucune requête, donc que rien d'autre ne viendrait vider.
void main() {
  AppUser client(String id) => AppUser.client(
    id: id,
    displayName: 'Awa Traoré',
    usernameOrPhone: id,
    phoneNumber: '70000000',
    createdAt: DateTime(2026),
  );

  late StreamController<AppUser?> comptes;
  late List<ProviderContainer> conteneurs;

  setUp(() {
    comptes = StreamController<AppUser?>.broadcast();
    conteneurs = [];
  });
  tearDown(() => comptes.close());

  Future<void> monter(WidgetTester tester) async {
    await tester.pumpWidget(
      SessionScope(
        createContainer: () => ProviderContainer(
          overrides: [
            currentUserProvider.overrideWith((ref) => comptes.stream),
          ],
        ),
        onContainerChanged: conteneurs.add,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Consumer(
            builder: (context, ref, _) =>
                Text('saisi : ${ref.watch(typedPromoCodeProvider)}'),
          ),
        ),
      ),
    );
  }

  Future<void> compte(WidgetTester tester, AppUser? user) async {
    comptes.add(user);
    // Une image pour livrer l'événement, une pour redessiner ce qu'il a
    // changé.
    await tester.pump();
    await tester.pump();
  }

  Future<void> saisir(WidgetTester tester, String texte) async {
    conteneurs.last.read(typedPromoCodeProvider.notifier).state = texte;
    await tester.pump();
  }

  testWidgets('la déconnexion repart d\'un état neuf', (tester) async {
    await monter(tester);
    await compte(tester, client('client1'));
    await saisir(tester, 'SOLDES');
    expect(find.text('saisi : SOLDES'), findsOneWidget);

    await compte(tester, null);

    expect(conteneurs, hasLength(2));
    expect(find.text('saisi : '), findsOneWidget);

    // L'ancien est libéré après le délai, pas avant : la déconnexion qui a
    // déclenché le changement finit de s'exécuter dessus.
    expect(conteneurs.first.read(typedPromoCodeProvider), 'SOLDES');
    await tester.pump(const Duration(seconds: 2));
    expect(
      () => conteneurs.first.read(typedPromoCodeProvider),
      throwsStateError,
    );
  });

  testWidgets('un compte qui en remplace un autre repart de zéro', (
    tester,
  ) async {
    await monter(tester);
    await compte(tester, client('fournisseur1'));
    await saisir(tester, 'SOLDES');

    await compte(tester, client('fournisseur2'));

    expect(conteneurs, hasLength(2));
    expect(find.text('saisi : '), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('le même compte rechargé ne vide rien', (tester) async {
    // Un jeton renouvelé, un profil relu : c'est toujours la même personne.
    await monter(tester);
    await compte(tester, client('client1'));
    await saisir(tester, 'SOLDES');

    await compte(tester, client('client1'));

    expect(conteneurs, hasLength(1));
    expect(find.text('saisi : SOLDES'), findsOneWidget);
  });

  testWidgets('une connexion refusée garde l\'écran tel quel', (tester) async {
    // Un collaborateur retiré : sa session s'ouvre puis se ferme avant
    // qu'un compte soit chargé. L'écran de connexion doit garder ce qui y
    // est — dont le message qui explique le refus.
    await monter(tester);
    await saisir(tester, 'vendeur_retire');

    await compte(tester, null);

    expect(conteneurs, hasLength(1));
    expect(find.text('saisi : vendeur_retire'), findsOneWidget);
  });
}
