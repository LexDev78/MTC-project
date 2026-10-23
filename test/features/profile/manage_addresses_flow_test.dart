import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/profile/domain/entities/address.dart';
import 'package:mtc_app/features/profile/domain/repositories/address_repository.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mtc_app/features/profile/presentation/screens/manage_addresses_screen.dart';
import 'package:mtc_app/features/profile/presentation/widgets/default_address.dart';

/// Les adresses du kit, sans base : la liste et son avertissement, la
/// recherche, le formulaire qui exige le point, la suppression confirmée.

final _maison = Address(
  id: 'adr-maison',
  userId: 'client-awa',
  label: 'Maison',
  city: 'Bamako',
  details: 'Rue 312, porte 18, Badalabougou',
  positionConfirmedAt: DateTime(2026, 10, 1),
  latitude: 12.6229,
  longitude: -7.9887,
);

const _bureau = Address(
  id: 'adr-bureau',
  userId: 'client-awa',
  label: 'Bureau',
  city: 'Ségou',
  details: 'Quartier Médine, face à la poste',
  latitude: 13.43,
  longitude: -6.26,
);

/// Le dépôt des adresses : la liste vit en mémoire, et chaque changement
/// est rediffusé comme le ferait le flux temps réel.
class _Adresses implements AddressRepository {
  _Adresses(List<Address> depart) : _liste = [...depart];

  final List<Address> _liste;
  final _flux = StreamController<List<Address>>.broadcast();
  final supprimees = <String>[];
  Object? refus;

  @override
  Stream<List<Address>> watchAddresses(String userId) async* {
    yield List.of(_liste);
    yield* _flux.stream;
  }

  @override
  Future<void> removeAddress({
    required String userId,
    required String addressId,
  }) async {
    if (refus != null) throw refus!;
    supprimees.add(addressId);
    _liste.removeWhere((a) => a.id == addressId);
    _flux.add(List.of(_liste));
  }

  /// Les adresses désignées par défaut, dans l'ordre des appels.
  final parDefaut = <String?>[];

  @override
  Future<void> setDefaultAddress(String? addressId) async {
    if (refus != null) throw refus!;
    parDefaut.add(addressId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Le compte, réduit à sa relecture.
class _Compte implements AuthRepository {
  int relectures = 0;

  @override
  Future<void> reloadCurrentUser() async => relectures++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late _Adresses _depot;
late _Compte _compte;

AppUser _awa({String? defaut}) => AppUser.client(
  id: 'client-awa',
  displayName: 'Awa Traoré',
  usernameOrPhone: 'awa',
  phoneNumber: '+223 70 12 34 56',
  createdAt: DateTime(2026),
  defaultAddressId: defaut,
);

Future<void> _ouvrir(
  WidgetTester tester, {
  List<Address>? adresses,
  String? defaut,
  Widget ecran = const ManageAddressesScreen(),
}) async {
  tester.view.physicalSize = const Size(375, 1000) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  _depot = _Adresses(adresses ?? [_maison, _bureau]);
  _compte = _Compte();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(
          (ref) => Stream.value(_awa(defaut: defaut)),
        ),
        addressRepositoryProvider.overrideWithValue(_depot),
        authRepositoryProvider.overrideWithValue(_compte),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: ShopScope(child: ecran),
      ),
    ),
  );
  await _avancer(tester);
}

Future<void> _avancer(WidgetTester tester, {int pas = 6}) async {
  for (var i = 0; i < pas; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pump();
  await tester.tap(cible);
  await _avancer(tester);
}

void main() {
  testWidgets('chaque adresse en carte, et l\'avertissement d\'un point '
      'jamais placé', (tester) async {
    await _ouvrir(tester);

    expect(find.byType(AddressCard), findsNWidgets(2));
    expect(find.text('Rue 312, porte 18, Badalabougou'), findsOneWidget);
    // Seul le bureau n'a jamais eu son point posé.
    expect(
      find.text(
        'Point jamais placé : les livreurs iront au centre de Ségou. '
        'Touchez pour le placer.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('la recherche filtre par nom, ville ou quartier', (tester) async {
    await _ouvrir(tester);
    final champ = find.byType(TextField);

    await tester.enterText(champ, 'badala');
    await _avancer(tester);
    expect(find.byType(AddressCard), findsOneWidget);
    expect(find.text('Maison'), findsOneWidget);

    // Sans accent : la ville est « Ségou ».
    await tester.enterText(champ, 'segou');
    await _avancer(tester);
    expect(find.text('Bureau'), findsOneWidget);
    expect(find.text('Maison'), findsNothing);

    await tester.enterText(champ, 'tombouctou');
    await _avancer(tester);
    expect(find.text('Aucune adresse trouvée'), findsOneWidget);
  });

  testWidgets('sans adresse, l\'écran dit quoi faire', (tester) async {
    await _ouvrir(tester, adresses: const []);
    expect(find.text('Aucune adresse enregistrée'), findsOneWidget);
    expect(find.text('Ajouter une adresse'), findsOneWidget);
  });

  testWidgets('le formulaire exige les champs, puis le point sur la carte', (
    tester,
  ) async {
    await _ouvrir(tester);
    await _toucher(tester, find.text('Ajouter une adresse'));
    expect(find.text('Nouvelle adresse'), findsOneWidget);

    await _toucher(tester, find.text('Enregistrer'));
    // La ville est préremplie : restent le libellé et les détails.
    expect(find.text('Ce champ est obligatoire'), findsNWidgets(2));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom (ex. Maison, Bureau)'),
      'Boutique de maman',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Détails (quartier, rue, porte)'),
      'Marché de Médine',
    );
    await _toucher(tester, find.text('Enregistrer'));

    expect(find.text('Placez d\'abord le repère sur la carte.'), findsWidgets);
    // Toujours ouvert : rien n'est perdu.
    expect(find.text('Nouvelle adresse'), findsOneWidget);
    expect(find.text('Placer sur la carte'), findsOneWidget);
  });

  testWidgets('supprimer une adresse demande confirmation', (tester) async {
    await _ouvrir(tester);

    await _toucher(tester, find.text('Bureau'));
    expect(find.text('Placer sur la carte'), findsOneWidget);
    await _toucher(tester, find.text('Supprimer l\'adresse'));
    await _toucher(tester, find.text('Retour'));
    expect(_depot.supprimees, isEmpty);
    expect(find.text('Bureau'), findsOneWidget);

    await _toucher(tester, find.text('Bureau'));
    await _toucher(tester, find.text('Supprimer l\'adresse'));
    await _toucher(tester, find.text('Supprimer'));

    expect(_depot.supprimees, ['adr-bureau']);
    expect(find.text('Bureau'), findsNothing);
    expect(find.text('Adresse « Bureau » supprimée.'), findsOneWidget);
  });

  testWidgets('une suppression refusée est dite, l\'adresse reste', (
    tester,
  ) async {
    await _ouvrir(tester);
    _depot.refus = const PostgrestException(
      message: 'Cette adresse sert à une commande en cours.',
      code: 'P0001',
    );

    await _toucher(tester, find.text('Maison'));
    // Un point déjà placé se « replace ».
    expect(find.text('Replacer sur la carte'), findsOneWidget);
    await _toucher(tester, find.text('Supprimer l\'adresse'));
    await _toucher(tester, find.text('Supprimer'));

    expect(
      find.text('Cette adresse sert à une commande en cours.'),
      findsOneWidget,
    );
    expect(find.text('Maison'), findsOneWidget);
  });

  group('adresse par défaut', () {
    testWidgets('l\'adresse choisie porte le ruban, et seule l\'autre se '
        'propose', (tester) async {
      await _ouvrir(tester, defaut: 'adr-maison');

      expect(find.text('Par défaut'), findsOneWidget);
      await _toucher(tester, find.text('Maison'));
      expect(find.text('Utiliser par défaut'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await _avancer(tester);

      await _toucher(tester, find.text('Bureau'));
      expect(find.text('Utiliser par défaut'), findsOneWidget);
    });

    testWidgets('« Utiliser par défaut » l\'enregistre et relit le compte', (
      tester,
    ) async {
      await _ouvrir(tester, defaut: 'adr-maison');

      await _toucher(tester, find.text('Bureau'));
      await _toucher(tester, find.text('Utiliser par défaut'));

      expect(_depot.parDefaut, ['adr-bureau']);
      expect(_compte.relectures, 1);
      expect(
        find.text('« Bureau » est votre adresse par défaut.'),
        findsOneWidget,
      );
    });

    testWidgets('un refus le dit, et le compte n\'est pas relu', (
      tester,
    ) async {
      await _ouvrir(tester);
      _depot.refus = const ValidationException('Adresse introuvable.');

      await _toucher(tester, find.text('Bureau'));
      await _toucher(tester, find.text('Utiliser par défaut'));

      expect(find.text('Adresse introuvable.'), findsOneWidget);
      expect(_compte.relectures, 0);
    });

    testWidgets('au paiement, toucher une adresse en fait l\'adresse par '
        'défaut et ferme le choix', (tester) async {
      await _ouvrir(
        tester,
        defaut: 'adr-maison',
        ecran: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAddressPickerSheet(context),
                child: const Text('CHANGER'),
              ),
            ),
          ),
        ),
      );

      await _toucher(tester, find.text('CHANGER'));
      expect(find.text('Adresse de livraison'), findsOneWidget);

      // Celle qui l'est déjà : rien ne part, le choix se ferme.
      await _toucher(tester, find.text('Maison'));
      expect(_depot.parDefaut, isEmpty);
      expect(find.text('Adresse de livraison'), findsNothing);

      await _toucher(tester, find.text('CHANGER'));
      await _toucher(tester, find.text('Bureau'));
      expect(_depot.parDefaut, ['adr-bureau']);
      expect(_compte.relectures, 1);
      expect(find.text('Adresse de livraison'), findsNothing);
    });
  });

  group('l\'adresse que le paiement propose', () {
    Address? proposee({String? defaut, List<Address>? adresses}) {
      final conteneur = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => Stream.value(_awa(defaut: defaut)),
          ),
          addressesProvider.overrideWith(
            (ref) => Stream.value(adresses ?? [_maison, _bureau]),
          ),
        ],
      );
      addTearDown(conteneur.dispose);
      return conteneur.read(defaultAddressProvider);
    }

    Future<void> charger() => Future<void>.delayed(Duration.zero);

    test('celle que le client a choisie', () async {
      final conteneur = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => Stream.value(_awa(defaut: 'adr-bureau')),
          ),
          addressesProvider.overrideWith(
            (ref) => Stream.value([_maison, _bureau]),
          ),
        ],
      );
      addTearDown(conteneur.dispose);
      conteneur.listen(defaultAddressProvider, (_, _) {});
      await charger();
      expect(conteneur.read(defaultAddressProvider)?.id, 'adr-bureau');
    });

    test(
      'sans choix, ou si l\'adresse choisie n\'existe plus : la première',
      () async {
        for (final defaut in [null, 'adr-supprimee']) {
          final conteneur = ProviderContainer(
            overrides: [
              currentUserProvider.overrideWith(
                (ref) => Stream.value(_awa(defaut: defaut)),
              ),
              addressesProvider.overrideWith(
                (ref) => Stream.value([_maison, _bureau]),
              ),
            ],
          );
          addTearDown(conteneur.dispose);
          conteneur.listen(defaultAddressProvider, (_, _) {});
          await charger();
          expect(conteneur.read(defaultAddressProvider)?.id, 'adr-maison');
        }
        // Sans adresse du tout : rien à proposer.
        expect(proposee(adresses: const []), isNull);
      },
    );
  });
}
