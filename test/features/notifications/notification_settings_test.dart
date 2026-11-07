import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/notifications/domain/entities/notification_preferences.dart';
import 'package:mtc_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/notifications/presentation/screens/notification_settings_screen.dart';

import '../../support/shop_fixtures.dart';

/// Les réglages de notification du kit, sans base : ce qui est affiché,
/// ce qui part au serveur, et le retour en arrière d'un échec.

class _Notifs implements NotificationRepository {
  _Notifs(this.reglages);

  NotificationPreferences reglages;
  final enregistres = <NotificationPreferences>[];

  /// Si posé, l'enregistrement échoue avec lui.
  Object? refus;

  @override
  Future<NotificationPreferences> fetchPreferences(String userId) async =>
      reglages;

  @override
  Future<void> savePreferences(
    String userId,
    NotificationPreferences preferences,
  ) async {
    if (refus != null) throw refus!;
    enregistres.add(preferences);
    reglages = preferences;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late _Notifs _depot;

Future<void> _ouvrir(
  WidgetTester tester, {
  NotificationPreferences reglages = NotificationPreferences.allOn,
}) async {
  _depot = _Notifs(reglages);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
        notificationRepositoryProvider.overrideWithValue(_depot),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const ShopScope(child: NotificationSettingsScreen()),
      ),
    ),
  );
  await _avancer(tester);
}

Future<void> _avancer(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// L'interrupteur de la ligne [titre].
Finder _interrupteur(String titre) => find.descendant(
  of: find.ancestor(
    of: find.text(titre),
    matching: find.byType(ShopSwitchTile),
  ),
  matching: find.byType(CupertinoSwitch),
);

CupertinoSwitch _etat(WidgetTester tester, String titre) =>
    tester.widget<CupertinoSwitch>(_interrupteur(titre));

Future<void> _basculer(WidgetTester tester, String titre) async {
  await tester.tap(_interrupteur(titre));
  await _avancer(tester);
}

void main() {
  testWidgets('les réglages enregistrés s\'affichent', (tester) async {
    await _ouvrir(
      tester,
      reglages: const NotificationPreferences(messages: false),
    );

    expect(_etat(tester, 'Autoriser les notifications').value, isTrue);
    expect(_etat(tester, 'Suivi de mes commandes').value, isTrue);
    expect(_etat(tester, 'Messages des boutiques').value, isFalse);
    expect(_etat(tester, 'Réponses à vos commentaires').value, isTrue);
  });

  testWidgets('couper une sorte l\'enregistre, et seulement elle', (
    tester,
  ) async {
    await _ouvrir(tester);

    await _basculer(tester, 'Messages des boutiques');

    expect(_depot.enregistres, [
      NotificationPreferences.allOn.copyWith(messages: false),
    ]);
    expect(_etat(tester, 'Messages des boutiques').value, isFalse);
  });

  testWidgets('tout couper fige les sortes, qui gardent leur réglage', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      reglages: const NotificationPreferences(comments: false),
    );

    await _basculer(tester, 'Autoriser les notifications');

    expect(_depot.enregistres.single.enabled, isFalse);
    // Le réglage par sorte est gardé pour le jour où l'on rouvre…
    expect(_depot.enregistres.single.comments, isFalse);
    expect(_depot.enregistres.single.orderUpdates, isTrue);
    // … mais ne se touche plus.
    expect(_etat(tester, 'Suivi de mes commandes').onChanged, isNull);
    expect(_etat(tester, 'Messages des boutiques').onChanged, isNull);
  });

  testWidgets('« Réinitialiser » rouvre tout, et se grise ensuite', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      reglages: const NotificationPreferences(enabled: false, messages: false),
    );

    await tester.tap(find.text('Réinitialiser'));
    await _avancer(tester);

    expect(_depot.enregistres, [NotificationPreferences.allOn]);
    final bouton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Réinitialiser'),
    );
    expect(bouton.onPressed, isNull);
  });

  testWidgets('un enregistrement qui échoue remet l\'interrupteur et le dit', (
    tester,
  ) async {
    await _ouvrir(tester);
    _depot.refus = Exception('Réseau indisponible.');

    await _basculer(tester, 'Suivi de mes commandes');

    expect(_etat(tester, 'Suivi de mes commandes').value, isTrue);
    expect(find.text('Réseau indisponible.'), findsOneWidget);
    expect(_depot.enregistres, isEmpty);
  });
}
