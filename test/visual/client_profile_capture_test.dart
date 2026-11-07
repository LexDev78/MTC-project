import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/app/theme/theme_mode_controller.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mtc_app/features/auth/presentation/screens/contact_email_code_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/contact_email_screen.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:mtc_app/features/notifications/domain/entities/notification_preferences.dart';
import 'package:mtc_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:mtc_app/features/profile/domain/entities/address.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mtc_app/features/profile/presentation/screens/client_profile_screen.dart';
import 'package:mtc_app/features/profile/presentation/screens/manage_addresses_screen.dart';
import 'package:mtc_app/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:mtc_app/features/profile/presentation/widgets/default_address.dart';
import 'package:mtc_app/features/profile/presentation/screens/profile_info_screen.dart';
import 'package:mtc_app/features/profile/presentation/screens/settings_screen.dart';

import '../support/shop_capture.dart';
import '../support/shop_fixtures.dart';

/// Des réglages de notification fixes, sans base.
class _Notifs implements NotificationRepository {
  _Notifs(this.reglages);

  final NotificationPreferences reglages;

  @override
  Future<NotificationPreferences> fetchPreferences(String userId) async =>
      reglages;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Theme extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.system;
}

List<Override> _compte({String? email, AppUser? compte}) => [
  currentUserProvider.overrideWith((ref) => Stream.value(compte ?? clientAwa())),
  contactEmailProvider.overrideWith((ref) async => email),
  contactEmailStatusProvider.overrideWith(
    (ref) async => (email: email, verified: email != null),
  ),
  // Pas de stockage en capture : une photo reste « en chargement », et ce
  // sont ses initiales qu'on voit.
  avatarUrlProvider.overrideWith((ref, path) => Completer<String>().future),
  totalUnreadCountProvider.overrideWithValue(3),
  notificationRepositoryProvider.overrideWithValue(
    _Notifs(NotificationPreferences.allOn),
  ),
  themeModeControllerProvider.overrideWith(_Theme.new),
];

final _adresses = [
  Address(
    id: 'adr-maison',
    userId: 'client-awa',
    label: 'Maison',
    city: 'Bamako',
    details: 'Rue 312, porte 18, Badalabougou',
    positionConfirmedAt: DateTime(2026, 10, 1),
    latitude: 12.6229,
    longitude: -7.9887,
  ),
  const Address(
    id: 'adr-bureau',
    userId: 'client-awa',
    label: 'Bureau',
    city: 'Ségou',
    details: 'Quartier Médine, face à la poste',
    latitude: 13.43,
    longitude: -6.26,
  ),
];

List<Override> _avecAdresses(List<Address> adresses) => [
  currentUserProvider.overrideWith(
    (ref) => Stream.value(
      AppUser.client(
        id: 'client-awa',
        displayName: 'Awa Traoré',
        usernameOrPhone: 'awa',
        phoneNumber: '+223 70 12 34 56',
        createdAt: DateTime(2026),
        defaultAddressId: 'adr-maison',
      ),
    ),
  ),
  addressesProvider.overrideWith((ref) => Stream.value(adresses)),
];

Future<void> _toucher(WidgetTester tester, String texte) async {
  await tester.tap(find.text(texte).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Le compte, pour l'écran du code : tout code est refusé, comme un code
/// faux le serait.
class _CodeRefuse implements AuthRepository {
  @override
  Future<String> confirmContactEmail(String code) async =>
      throw const ValidationException('Code incorrect. Il vous reste 4 essais.');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final ContactEmailCodeRequest _demande = (
  email: 'awa.traore@exemple.ml',
  expiresAt: DateTime(2026, 10, 22, 10, 10),
  resendAfterSeconds: 60,
);

/// Awa avec une date de naissance et une photo (dont on voit les initiales :
/// pas de stockage en capture).
final _awaComplete = (clientAwa() as ClientUser).copyWith(
  birthDate: DateTime(1995, 3, 12),
  avatarPath: 'client-awa/photo.jpg',
);

void main() {
  capturerEcran(
    'email_code',
    () => ContactEmailCodeScreen(request: _demande),
    overrides: _compte,
  );
  capturerEcran(
    'email_code_refuse',
    () => ContactEmailCodeScreen(request: _demande),
    overrides: () => [
      ..._compte(),
      authRepositoryProvider.overrideWithValue(_CodeRefuse()),
    ],
    geste: (tester) async {
      await tester.enterText(find.byType(TextField), '000000');
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
  capturerEcran(
    'email_ancienne_adresse',
    () => const ContactEmailScreen(),
    overrides: () => [
      ..._compte(),
      contactEmailStatusProvider.overrideWith(
        (ref) async => (email: 'ancienne@exemple.ml', verified: false),
      ),
    ],
  );
  capturerEcran(
    'profil_modifier_complet',
    () => const ProfileEditScreen(),
    overrides: () =>
        _compte(email: 'awa.traore@exemple.ml', compte: _awaComplete),
  );
  capturerEcran(
    'profil_photo',
    () => const ProfileEditScreen(),
    overrides: () => _compte(compte: _awaComplete),
    geste: (tester) async {
      await tester.tap(find.bySemanticsLabel('Changer la photo de profil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
  capturerEcran(
    'profil_infos_naissance',
    () => const ProfileInfoScreen(),
    overrides: () => _compte(compte: _awaComplete),
  );
  capturerEcran(
    'profil',
    () => const ClientProfileScreen(),
    overrides: _compte,
    hauteur: 900,
  );
  capturerEcran(
    'profil_avec_email',
    () => const ClientProfileScreen(),
    overrides: () => _compte(email: 'awa.traore@exemple.ml'),
    hauteur: 900,
  );
  capturerEcran(
    'profil_informations',
    () => const ProfileInfoScreen(),
    overrides: _compte,
  );
  capturerEcran('parametres', () => const SettingsScreen(), overrides: _compte);
  capturerEcran(
    'adresses',
    () => const ManageAddressesScreen(),
    overrides: () => _avecAdresses(_adresses),
  );
  capturerEcran(
    'adresses_actions',
    () => const ManageAddressesScreen(),
    overrides: () => _avecAdresses(_adresses),
    geste: (tester) => _toucher(tester, 'Bureau'),
  );
  capturerEcran(
    'adresses_nouvelle',
    () => const ManageAddressesScreen(),
    overrides: () => _avecAdresses(_adresses),
    geste: (tester) => _toucher(tester, 'Ajouter une adresse'),
  );
  capturerEcran(
    'adresses_vide',
    () => const ManageAddressesScreen(),
    overrides: () => _avecAdresses(const []),
  );
  capturerEcran(
    'profil_modifier',
    () => const ProfileEditScreen(),
    overrides: () => _compte(email: 'awa.traore@exemple.ml'),
  );
  capturerEcran(
    'notifications_reglages',
    () => const NotificationSettingsScreen(),
    overrides: () => [
      ..._compte(),
      notificationRepositoryProvider.overrideWithValue(
        _Notifs(const NotificationPreferences(comments: false)),
      ),
    ],
  );
  capturerEcran(
    'notifications_coupees',
    () => const NotificationSettingsScreen(),
    overrides: () => [
      ..._compte(),
      notificationRepositoryProvider.overrideWithValue(
        _Notifs(const NotificationPreferences(enabled: false)),
      ),
    ],
  );
  capturerEcran(
    'paiement_choix_adresse',
    () => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showAddressPickerSheet(context),
            child: const Text('CHANGER'),
          ),
        ),
      ),
    ),
    overrides: () => _avecAdresses(_adresses),
    geste: (tester) => _toucher(tester, 'CHANGER'),
  );
}
