import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/app/theme/theme_mode_controller.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/features/notifications/domain/entities/notification_preferences.dart';
import 'package:mtc_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/profile/presentation/screens/client_profile_screen.dart';
import 'package:mtc_app/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:mtc_app/features/profile/presentation/screens/profile_info_screen.dart';
import 'package:mtc_app/features/profile/presentation/screens/settings_screen.dart';

import '../../support/shop_fixtures.dart';

/// Le profil du kit, sans base : le menu et où il mène, ses compteurs, la
/// déconnexion, les informations du compte et les paramètres.

/// Le compte, réduit à ce que le profil demande : il note les appels, ou
/// refuse la suppression avec [refus], le nom avec [refusNom] et le numéro
/// avec [refusTelephone].
class _Compte implements AuthRepository {
  final appels = <Symbol>[];
  final noms = <String>[];
  final emails = <String?>[];
  final telephones = <String>[];
  final naissances = <DateTime?>[];

  /// Chaque changement de photo : la nouvelle (`null` = retirée) et celle
  /// qu'elle remplace.
  final photos = <({bool retiree, String? precedente})>[];
  Object? refus;
  Object? refusNom;
  Object? refusTelephone;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final nom = invocation.memberName;
    if (nom == #logout || nom == #deleteAccount) {
      if (nom == #deleteAccount && refus != null) {
        return Future<void>.error(refus!);
      }
      appels.add(nom);
      return Future<void>.value();
    }
    if (nom == #setDisplayName) {
      if (refusNom != null) return Future<String>.error(refusNom!);
      final valeur = invocation.positionalArguments.single as String;
      noms.add(valeur);
      return Future<String>.value(valeur);
    }
    if (nom == #setContactEmail) {
      final valeur = invocation.positionalArguments.single as String?;
      emails.add(valeur);
      return Future<String?>.value(valeur);
    }
    if (nom == #setPhoneNumber) {
      if (refusTelephone != null) return Future<String>.error(refusTelephone!);
      final valeur = invocation.positionalArguments.single as String;
      telephones.add(valeur);
      return Future<String>.value(valeur);
    }
    if (nom == #setBirthDate) {
      naissances.add(invocation.positionalArguments.single as DateTime?);
      return Future<void>.value();
    }
    if (nom == #setAvatar) {
      photos.add((
        retiree: invocation.positionalArguments.single == null,
        precedente: invocation.namedArguments[#previousPath] as String?,
      ));
      return Future<void>.value();
    }
    if (nom == #reloadCurrentUser) return Future<void>.value();
    return super.noSuchMethod(invocation);
  }
}

/// Les réglages de notification, en mémoire.
class _Notifs implements NotificationRepository {
  _Notifs(this.reglages);

  NotificationPreferences reglages;

  @override
  Future<NotificationPreferences> fetchPreferences(String userId) async =>
      reglages;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Le thème sans préférences enregistrées sur l'appareil.
class _Theme extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.system;

  @override
  Future<void> setThemeMode(ThemeMode mode) async => state = mode;
}

late _Compte _compte;
late ProviderContainer _conteneur;

/// Les destinations du menu qui ne sont pas testées ici : une page qui dit
/// où l'on est arrivé.
const _ailleurs = [
  AppRoutes.clientOrders,
  AppRoutes.clientFavorites,
  AppRoutes.clientProfileEdit,
  AppRoutes.clientChat,
  AppRoutes.clientNotificationSettings,
  AppRoutes.accountEmail,
  AppRoutes.accountPassword,
];

Future<void> _ouvrir(
  WidgetTester tester, {
  String adresse = AppRoutes.clientProfile,
  String? email,
  int messages = 3,
  NotificationPreferences reglages = NotificationPreferences.allOn,
  AppUser? compte,
  bool emailVerifie = true,
}) async {
  tester.view.physicalSize = const Size(375, 1100) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  _compte = _Compte();
  _conteneur = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_compte),
      currentUserProvider.overrideWith(
        (ref) => Stream.value(compte ?? clientAwa()),
      ),
      contactEmailProvider.overrideWith((ref) async => email),
      contactEmailStatusProvider.overrideWith(
        (ref) async => (email: email, verified: email != null && emailVerifie),
      ),
      // Pas de stockage en test : la photo reste « en chargement », les
      // initiales tiennent sa place.
      avatarUrlProvider.overrideWith((ref, path) => Completer<String>().future),
      totalUnreadCountProvider.overrideWithValue(messages),
      notificationRepositoryProvider.overrideWithValue(_Notifs(reglages)),
      themeModeControllerProvider.overrideWith(_Theme.new),
    ],
  );
  addTearDown(_conteneur.dispose);
  _conteneur.listen(currentUserProvider, (_, _) {});

  Page<void> page(Widget ecran) => MaterialPage(child: ShopScope(child: ecran));
  final router = GoRouter(
    initialLocation: adresse,
    routes: [
      GoRoute(
        path: AppRoutes.clientProfile,
        pageBuilder: (_, _) => page(const ClientProfileScreen()),
      ),
      GoRoute(
        path: AppRoutes.clientProfileInfo,
        pageBuilder: (_, _) => page(const ProfileInfoScreen()),
      ),
      GoRoute(
        path: AppRoutes.clientProfileInfoEdit,
        pageBuilder: (_, _) => page(const ProfileEditScreen()),
      ),
      GoRoute(
        path: AppRoutes.clientSettings,
        pageBuilder: (_, _) => page(const SettingsScreen()),
      ),
      for (final chemin in _ailleurs)
        GoRoute(
          path: chemin,
          pageBuilder: (_, _) =>
              page(Scaffold(appBar: AppBar(), body: Text('PAGE $chemin'))),
        ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _conteneur,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
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

/// La ligne du menu qui porte [titre].
Finder _ligne(String titre) =>
    find.ancestor(of: find.text(titre), matching: find.byType(ListTile));

void main() {
  testWidgets('chaque entrée du menu mène à son écran', (tester) async {
    await _ouvrir(tester);
    const entrees = {
      'Mes commandes': AppRoutes.clientOrders,
      'Mes adresses': AppRoutes.clientProfileEdit,
      'Messages': AppRoutes.clientChat,
      'Notifications': AppRoutes.clientNotificationSettings,
      'Adresse e-mail': AppRoutes.accountEmail,
      'Mot de passe': AppRoutes.accountPassword,
    };
    for (final MapEntry(key: titre, value: chemin) in entrees.entries) {
      await _toucher(tester, find.text(titre));
      expect(find.text('PAGE $chemin'), findsOneWidget, reason: titre);
      await tester.pageBack();
      await _avancer(tester);
    }

    await _toucher(tester, find.text('Paramètres'));
    expect(find.text('Apparence'), findsOneWidget);
    await tester.pageBack();
    await _avancer(tester);

    // La carte du compte ouvre ses informations.
    await _toucher(tester, find.text('Bonjour, Awa Traoré'));
    expect(find.text('Mes informations'), findsOneWidget);
    await tester.pageBack();
    await _avancer(tester);

    // Les favoris sont un onglet : on y va, on ne l'empile pas.
    await _toucher(tester, find.text('Mes favoris'));
    expect(find.text('PAGE ${AppRoutes.clientFavorites}'), findsOneWidget);
  });

  testWidgets('les compteurs ne paraissent que s\'il y a du nouveau', (
    tester,
  ) async {
    await _ouvrir(tester, messages: 3);

    expect(
      find.descendant(of: _ligne('Messages'), matching: find.text('3')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _ligne('Notifications'),
        matching: find.byType(CountPill),
      ),
      findsNothing,
    );
  });

  testWidgets('sans adresse e-mail, le menu propose d\'en ajouter', (
    tester,
  ) async {
    await _ouvrir(tester);
    expect(
      find.descendant(
        of: _ligne('Adresse e-mail'),
        matching: find.text('Ajouter'),
      ),
      findsOneWidget,
    );
    // Sous le nom, le téléphone à défaut d'e-mail.
    expect(find.text('+223 70 12 34 56'), findsOneWidget);
  });

  testWidgets('avec une adresse e-mail, la carte la montre', (tester) async {
    await _ouvrir(tester, email: 'awa@exemple.ml');
    expect(find.text('Ajouter'), findsNothing);
    expect(find.text('awa@exemple.ml'), findsOneWidget);
  });

  testWidgets('la déconnexion part du bas du menu', (tester) async {
    await _ouvrir(tester);

    await _toucher(tester, find.text('Déconnexion'));

    expect(_compte.appels, [#logout]);
  });

  testWidgets('les informations du compte, et le mot de passe à changer', (
    tester,
  ) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfo);

    expect(
      find.descendant(
        of: find.widgetWithText(InfoRow, 'Nom'),
        matching: find.text('Awa Traoré'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(InfoRow, 'Téléphone'),
        matching: find.text('+223 70 12 34 56'),
      ),
      findsOneWidget,
    );
    // L'identifiant diffère du téléphone : il est montré.
    expect(find.text('awa'), findsOneWidget);
    expect(find.text('1er janvier 2026'), findsOneWidget);

    await _toucher(tester, find.text('Changer le mot de passe'));
    expect(find.text('PAGE ${AppRoutes.accountPassword}'), findsOneWidget);
  });

  testWidgets('le thème se choisit dans les paramètres', (tester) async {
    await _ouvrir(tester, adresse: AppRoutes.clientSettings);

    await _toucher(tester, find.text('Sombre'));
    expect(_conteneur.read(themeModeControllerProvider), ThemeMode.dark);

    await _toucher(tester, find.text('Thème du téléphone'));
    expect(_conteneur.read(themeModeControllerProvider), ThemeMode.system);
  });

  testWidgets('supprimer le compte demande confirmation', (tester) async {
    await _ouvrir(tester, adresse: AppRoutes.clientSettings);
    final confirmer = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Supprimer mon compte'),
    );

    await _toucher(tester, find.text('Supprimer mon compte'));
    await _toucher(tester, find.text('Retour'));
    expect(_compte.appels, isEmpty);

    await _toucher(tester, find.text('Supprimer mon compte'));
    await _toucher(tester, confirmer);
    expect(_compte.appels, [#deleteAccount]);
  });

  testWidgets('un refus de suppression est dit', (tester) async {
    await _ouvrir(tester, adresse: AppRoutes.clientSettings);
    _compte.refus = const PostgrestException(
      message: 'Vous avez des commandes en cours.',
      code: 'P0001',
    );

    await _toucher(tester, find.text('Supprimer mon compte'));
    await _toucher(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Supprimer mon compte'),
      ),
    );

    expect(find.text('Vous avez des commandes en cours.'), findsOneWidget);
  });

  testWidgets('la ligne « Notifications » dit l\'état des réglages', (
    tester,
  ) async {
    await _ouvrir(tester);
    expect(
      find.descendant(
        of: _ligne('Notifications'),
        matching: find.text('Activées'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('notifications coupées en bloc : la ligne le dit', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      reglages: const NotificationPreferences(enabled: false),
    );
    expect(
      find.descendant(
        of: _ligne('Notifications'),
        matching: find.text('Coupées'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('« Modifier » enregistre le nom et revient aux informations', (
    tester,
  ) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfo);
    await _toucher(tester, find.text('Modifier'));
    expect(find.text('Modifier le profil'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Awa Traoré'),
      '  Awa Diallo ',
    );
    await _toucher(tester, find.text('Enregistrer'));

    expect(_compte.noms, ['Awa Diallo']);
    // L'e-mail, inchangé, ne repart pas.
    expect(_compte.emails, isEmpty);
    expect(find.text('Votre profil est enregistré.'), findsOneWidget);
    expect(find.text('Mes informations'), findsOneWidget);
  });

  testWidgets('un nom trop court est arrêté avant l\'envoi', (tester) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfoEdit);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Awa Traoré'),
      'A',
    );
    await _toucher(tester, find.text('Enregistrer'));

    expect(
      find.text('Votre nom doit compter au moins 2 caractères.'),
      findsOneWidget,
    );
    expect(_compte.noms, isEmpty);
  });

  testWidgets('le refus du serveur s\'affiche sous le nom, et l\'écran reste', (
    tester,
  ) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfoEdit);
    _compte.refusNom = const ValidationException(
      'Votre nom ne doit pas dépasser 60 caractères.',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Awa Traoré'),
      'Awa Diallo',
    );
    await _toucher(tester, find.text('Enregistrer'));

    expect(
      find.text('Votre nom ne doit pas dépasser 60 caractères.'),
      findsOneWidget,
    );
    expect(find.text('Modifier le profil'), findsOneWidget);
  });

  testWidgets('l\'e-mail s\'ouvre sur son écran, où il se vérifie par code', (
    tester,
  ) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfoEdit);
    expect(
      find.text('Un code vous sera envoyé pour la vérifier.'),
      findsOneWidget,
    );

    await _toucher(tester, find.bySemanticsLabel('Ajouter une adresse e-mail'));

    expect(find.text('PAGE ${AppRoutes.accountEmail}'), findsOneWidget);
    // Rien n'est parti du formulaire : l'adresse ne s'y enregistre plus.
    expect(_compte.emails, isEmpty);
  });

  testWidgets('une adresse jamais vérifiée le dit', (tester) async {
    await _ouvrir(
      tester,
      adresse: AppRoutes.clientProfileInfoEdit,
      email: 'ancienne@exemple.ml',
      emailVerifie: false,
    );

    expect(find.text('ancienne@exemple.ml'), findsOneWidget);
    expect(
      find.text('Jamais vérifiée : touchez pour la vérifier.'),
      findsOneWidget,
    );
  });

  testWidgets('enregistrer le profil ne touche pas à l\'e-mail', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      adresse: AppRoutes.clientProfileInfoEdit,
      email: 'awa@exemple.ml',
    );
    expect(find.text('Vérifiée.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Awa Traoré'),
      'Awa Diallo',
    );
    await _toucher(tester, find.text('Enregistrer'));

    expect(_compte.noms, ['Awa Diallo']);
    expect(_compte.emails, isEmpty);
  });

  testWidgets('changer de numéro l\'enregistre', (tester) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfoEdit);

    await tester.enterText(
      find.widgetWithText(TextFormField, '+223 70 12 34 56'),
      '76 54 32 10',
    );
    await _toucher(tester, find.text('Enregistrer'));

    expect(_compte.telephones, ['76 54 32 10']);
    expect(_compte.noms, isEmpty);
    expect(find.text('Votre profil est enregistré.'), findsOneWidget);
  });

  testWidgets('le même numéro écrit autrement ne repart pas', (tester) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfoEdit);

    await tester.enterText(
      find.widgetWithText(TextFormField, '+223 70 12 34 56'),
      '+22370123456',
    );
    await _toucher(tester, find.text('Enregistrer'));

    expect(_compte.telephones, isEmpty);
    expect(find.text('Votre profil est enregistré.'), findsOneWidget);
  });

  testWidgets('un numéro invalide est arrêté avant l\'envoi', (tester) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfoEdit);

    await tester.enterText(
      find.widgetWithText(TextFormField, '+223 70 12 34 56'),
      '12 34',
    );
    await _toucher(tester, find.text('Enregistrer'));

    expect(
      find.text('Numéro malien invalide (ex : 70 12 34 56)'),
      findsOneWidget,
    );
    expect(_compte.telephones, isEmpty);
  });

  testWidgets('le refus du serveur s\'affiche sous le numéro', (tester) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfoEdit);
    _compte.refusTelephone = const ValidationException(
      'Numéro malien invalide (ex : 70 12 34 56).',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, '+223 70 12 34 56'),
      '76 54 32 10',
    );
    await _toucher(tester, find.text('Enregistrer'));

    expect(
      find.text('Numéro malien invalide (ex : 70 12 34 56).'),
      findsOneWidget,
    );
    expect(find.text('Modifier le profil'), findsOneWidget);
  });

  testWidgets('le champ du numéro dit qui le voit', (tester) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfoEdit);
    expect(
      find.text(
        'Montré seulement à qui vous livre, le temps de la livraison.',
      ),
      findsOneWidget,
    );

    await _toucher(tester, find.byTooltip('Qui voit vos informations ?'));
    expect(
      find.textContaining('Votre photo et votre date de naissance ne sont '
          'visibles que de vous.'),
      findsOneWidget,
    );
    // L'identifiant de connexion n'est pas le numéro.
    expect(
      find.textContaining('Vous vous connectez avec « awa »'),
      findsOneWidget,
    );
  });

  testWidgets('la date de naissance se tape chiffre par chiffre', (
    tester,
  ) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfoEdit);

    final champ = find.widgetWithText(
      TextFormField,
      'Date de naissance (facultative)',
    );
    await tester.enterText(champ, '12031995');
    await tester.pump();
    expect(find.text('12/03/1995'), findsOneWidget);

    await _toucher(tester, find.text('Enregistrer'));
    expect(_compte.naissances, [DateTime(1995, 3, 12)]);
  });

  testWidgets('une date impossible ou future est arrêtée', (tester) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfoEdit);
    final champ = find.widgetWithText(
      TextFormField,
      'Date de naissance (facultative)',
    );

    await tester.enterText(champ, '31021995');
    await _toucher(tester, find.text('Enregistrer'));
    expect(
      find.text('Date invalide : jj/mm/aaaa, par exemple 12/03/1995.'),
      findsOneWidget,
    );

    final demain = DateTime.now().add(const Duration(days: 1));
    await tester.enterText(
      champ,
      '${demain.day.toString().padLeft(2, '0')}'
      '${demain.month.toString().padLeft(2, '0')}${demain.year}',
    );
    await _toucher(tester, find.text('Enregistrer'));
    expect(
      find.text('La date de naissance ne peut pas être dans le futur.'),
      findsOneWidget,
    );
    expect(_compte.naissances, isEmpty);
  });

  testWidgets('effacer la date de naissance la retire', (tester) async {
    await _ouvrir(
      tester,
      adresse: AppRoutes.clientProfileInfoEdit,
      compte: (clientAwa() as ClientUser).copyWith(
        birthDate: DateTime(1995, 3, 12),
      ),
    );
    expect(find.text('12/03/1995'), findsOneWidget);

    await _toucher(tester, find.byTooltip('Effacer la date'));
    await _toucher(tester, find.text('Enregistrer'));

    expect(_compte.naissances, [null]);
  });

  testWidgets('retirer sa photo part à l\'enregistrement, pas avant', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      adresse: AppRoutes.clientProfileInfoEdit,
      compte: (clientAwa() as ClientUser).copyWith(
        avatarPath: 'client-awa/photo.jpg',
      ),
    );

    await _toucher(tester, find.bySemanticsLabel('Changer la photo de profil'));
    expect(find.text('Photo de profil'), findsOneWidget);
    await _toucher(tester, find.text('Retirer la photo'));
    expect(_compte.photos, isEmpty);

    await _toucher(tester, find.text('Enregistrer'));
    expect(_compte.photos, [
      (retiree: true, precedente: 'client-awa/photo.jpg'),
    ]);
  });

  testWidgets('sans photo, la feuille ne propose pas de la retirer', (
    tester,
  ) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfoEdit);

    await _toucher(tester, find.bySemanticsLabel('Changer la photo de profil'));
    expect(find.text('Choisir une photo'), findsOneWidget);
    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Retirer la photo'), findsNothing);
  });

  testWidgets('la date de naissance figure dans les informations', (
    tester,
  ) async {
    await _ouvrir(tester, adresse: AppRoutes.clientProfileInfo);
    expect(
      find.descendant(
        of: find.widgetWithText(InfoRow, 'Date de naissance'),
        matching: find.text('Ajouter'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('une date de naissance renseignée se lit en toutes lettres', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      adresse: AppRoutes.clientProfileInfo,
      compte: (clientAwa() as ClientUser).copyWith(
        birthDate: DateTime(1995, 3, 12),
      ),
    );
    expect(
      find.descendant(
        of: find.widgetWithText(InfoRow, 'Date de naissance'),
        matching: find.text('12 mars 1995'),
      ),
      findsOneWidget,
    );
  });
}
