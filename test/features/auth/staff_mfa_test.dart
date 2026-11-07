import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/app/router/app_router.dart';
import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:mtc_app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/auth/presentation/screens/staff_mfa_screen.dart';

/// La double authentification du staff (`0135`), côté app : quand le compte
/// relu dit qu'un code est attendu, et ce que l'écran du code en fait. Que
/// la base refuse une session `aal1` se vérifie en base
/// (`supabase/snippets/verif_0135.sql`).

// ---- le compte relu ------------------------------------------------------------

class _Source implements SupabaseAuthDatasource {
  _Source({required this.niveau, required this.exige});

  AuthenticatorAssuranceLevels? niveau;
  bool exige;
  int questionsAuServeur = 0;

  @override
  Session? get currentSession => Session(
    accessToken: 'jeton',
    tokenType: 'bearer',
    user: const User(
      id: 'admin-1',
      appMetadata: {'staff_role': 'admin'},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );

  @override
  AuthenticatorAssuranceLevels? currentAssuranceLevel() => niveau;

  @override
  Future<bool> staffMfaRequired() async {
    questionsAuServeur++;
    return exige;
  }

  @override
  Stream<AuthState> onAuthStateChange() => const Stream.empty();

  @override
  Future<Map<String, dynamic>> fetchProfileRow(String userId) async => {
    'id': userId,
    'role': 'supplier_principal',
    'staff_role': 'admin',
    'display_name': 'Admin MTC',
    'username_or_phone': 'admin1',
    'phone_number': '+22378000002',
    'created_at': '2026-01-01T00:00:00Z',
    'deleted_at': null,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<SupplierPrincipalUser> _compteRelu(_Source source) async {
  final compte = await SupabaseAuthRepository(source).watchCurrentUser().first;
  return compte! as SupplierPrincipalUser;
}

// ---- l'écran du code ---------------------------------------------------------------

class _Compte implements AuthRepository {
  _Compte({this.facteurVerifie, this.refusEnrolement});

  final String? facteurVerifie;
  final Object? refusEnrolement;
  final verifications = <({String factorId, String code})>[];
  int enrolements = 0;
  int relectures = 0;

  @override
  Future<String?> fetchVerifiedTotpFactorId() async => facteurVerifie;

  @override
  Future<TotpEnrollment> enrollTotp() async {
    enrolements++;
    if (refusEnrolement != null) throw refusEnrolement!;
    return (
      factorId: 'facteur-neuf',
      uri:
          'otpauth://totp/MTC:admin1?secret=JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP&issuer=MTC',
      secret: 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP',
    );
  }

  @override
  Future<void> verifyTotp({
    required String factorId,
    required String code,
  }) async {
    verifications.add((factorId: factorId, code: code));
    if (code != '123456') {
      throw const ValidationException('Code incorrect.');
    }
  }

  @override
  Future<void> reloadCurrentUser() async => relectures++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _admin = AppUser.supplierPrincipal(
  id: 'admin-1',
  displayName: 'Admin MTC',
  usernameOrPhone: 'admin1',
  phoneNumber: '+22378000002',
  createdAt: DateTime(2026),
  staffRole: StaffRole.admin,
  mfaPending: true,
);

/// Le vrai routeur, avec un compte staff dont la session attend son code.
/// Rend le chemin où il a mené.
Future<String> _ouvrir(WidgetTester tester, _Compte compte) async {
  tester.view.physicalSize = const Size(390, 1400) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final conteneur = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(compte),
      currentUserProvider.overrideWith((ref) => Stream.value(_admin)),
      sharedPreferencesProvider.overrideWithValue(preferences),
    ],
  );
  addTearDown(conteneur.dispose);
  final routeur = conteneur.read(routerProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: routeur),
    ),
  );
  await _avancer(tester, pas: 10);
  return routeur.routerDelegate.currentConfiguration.uri.path;
}

Future<void> _avancer(WidgetTester tester, {int pas = 6}) async {
  for (var i = 0; i < pas; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder get _champCode => find.descendant(
  of: find.byType(CodeInputField),
  matching: find.byType(TextField),
);

void main() {
  group('le compte staff relu dit quand un code est attendu', () {
    test('session au seul mot de passe, code exigé : en attente', () async {
      final compte = await _compteRelu(
        _Source(niveau: AuthenticatorAssuranceLevels.aal1, exige: true),
      );
      expect(compte.mfaPending, isTrue);
    });

    test('session confirmée par le code : plus rien à attendre', () async {
      final source = _Source(
        niveau: AuthenticatorAssuranceLevels.aal2,
        exige: true,
      );
      final compte = await _compteRelu(source);
      expect(compte.mfaPending, isFalse);
      expect(
        source.questionsAuServeur,
        0,
        reason: 'aal2 suffit, sans aller-retour',
      );
    });

    test("l'exploitant a éteint l'exigence : pas d'écran du code", () async {
      final compte = await _compteRelu(
        _Source(niveau: AuthenticatorAssuranceLevels.aal1, exige: false),
      );
      expect(compte.mfaPending, isFalse);
    });
  });

  group("l'écran du code", () {
    testWidgets(
      'un compte staff en attente y est mené, et le relie en scannant',
      (tester) async {
        final compte = _Compte();
        final arrivee = await _ouvrir(tester, compte);

        expect(arrivee, AppRoutes.staffMfa);
        expect(find.byType(StaffMfaScreen), findsOneWidget);
        expect(
          find.text('Reliez votre compte à une application'),
          findsOneWidget,
        );
        expect(find.byType(QrImageView), findsOneWidget);
        // La clé, par groupes de quatre, pour qui ne peut pas scanner.
        expect(
          find.text('JBSW Y3DP EHPK 3PXP JBSW Y3DP EHPK 3PXP'),
          findsOneWidget,
        );
        expect(compte.enrolements, 1);

        // Un code faux : refusé, dit, et les cases se vident.
        await tester.enterText(_champCode, '000000');
        await _avancer(tester);
        expect(find.text('Code incorrect.'), findsOneWidget);
        expect(tester.widget<TextField>(_champCode).controller!.text, isEmpty);
        expect(compte.relectures, 0);

        // Le bon : le compte est relu, ce qui le fait sortir d'ici.
        await tester.enterText(_champCode, '123456');
        await _avancer(tester);
        expect(compte.verifications.last, (
          factorId: 'facteur-neuf',
          code: '123456',
        ));
        expect(compte.relectures, 1);
      },
    );

    testWidgets('un compte déjà relié ne rescanne pas : il donne son code', (
      tester,
    ) async {
      final compte = _Compte(facteurVerifie: 'facteur-1');
      await _ouvrir(tester, compte);

      expect(find.text('Le code de votre application'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(compte.enrolements, 0);

      await tester.enterText(_champCode, '123456');
      await _avancer(tester);
      expect(compte.verifications.single, (
        factorId: 'facteur-1',
        code: '123456',
      ));
      expect(compte.relectures, 1);
    });

    testWidgets(
      "une TOTP éteinte sur le serveur se dit, et l'on peut réessayer",
      (tester) async {
        final compte = _Compte(
          refusEnrolement: const ValidationException(
            'La double authentification n\'est pas activée sur le serveur. '
            'Prévenez l\'administrateur MTC.',
          ),
        );
        await _ouvrir(tester, compte);

        expect(find.byType(MtcErrorBanner), findsOneWidget);
        expect(
          find.textContaining('pas activée sur le serveur'),
          findsOneWidget,
        );
        expect(find.byType(CodeInputField), findsNothing);

        await tester.tap(find.text('Réessayer'));
        await _avancer(tester);
        expect(compte.enrolements, 2);
      },
    );
  });
}
