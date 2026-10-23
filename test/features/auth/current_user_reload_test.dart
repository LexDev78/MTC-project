// Un flux qui ne rend pas la main pendrait le test : mieux vaut qu'il
// échoue vite et dise lequel.
@Timeout(Duration(seconds: 20))
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:mtc_app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';

/// La session et le profil d'un client, en mémoire : ce que le flux de
/// l'utilisateur courant lit, sans serveur.
class _Source implements SupabaseAuthDatasource {
  final evenements = StreamController<AuthState>.broadcast();
  Session? session = _session('client-awa');
  String nom = 'Awa Traoré';
  String? adresseParDefaut;

  /// Le refus que `set_my_display_name` renverrait, s'il y en a un.
  PostgrestException? refus;

  @override
  Session? get currentSession => session;

  @override
  Stream<AuthState> onAuthStateChange() => evenements.stream;

  @override
  Future<Map<String, dynamic>> fetchProfileRow(String userId) async => {
    'id': userId,
    'role': 'client',
    'display_name': nom,
    'username_or_phone': 'awa',
    'phone_number': '+223 70 12 34 56',
    'created_at': '2026-01-01T00:00:00Z',
    'deleted_at': null,
    'default_address_id': adresseParDefaut,
  };

  @override
  Future<String> setDisplayName(String displayName) async {
    if (refus != null) throw refus!;
    nom = displayName.trim();
    return nom;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Session _session(String userId) => Session(
  accessToken: 'jeton',
  tokenType: 'bearer',
  user: User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  ),
);

/// Attend que le flux ait rendu [n] comptes.
Future<void> _attendre(List<AppUser?> recus, int n) async {
  for (var i = 0; i < 50 && recus.length < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late _Source source;
  late SupabaseAuthRepository depot;
  late List<AppUser?> recus;
  late StreamSubscription<AppUser?> abonnement;

  setUp(() async {
    source = _Source();
    depot = SupabaseAuthRepository(source);
    recus = [];
    abonnement = depot.watchCurrentUser().listen(recus.add);
    await _attendre(recus, 1);
  });

  tearDown(() async {
    // Sans `await` : un flux `async*` arrêté dans un `await for` ne rend la
    // main qu'au prochain événement — ce que l'app n'attend jamais.
    unawaited(abonnement.cancel());
    await source.evenements.close();
  });

  test(
    'changer son nom pousse le compte relu, sans événement de session',
    () async {
      expect(recus.single?.displayName, 'Awa Traoré');

      final nom = await depot.setDisplayName('Awa Diallo');
      await _attendre(recus, 2);

      expect(nom, 'Awa Diallo');
      expect(recus, hasLength(2));
      expect(recus.last?.displayName, 'Awa Diallo');
    },
  );

  test('une relecture rend l\'adresse par défaut choisie', () async {
    source.adresseParDefaut = 'adr-maison';
    await depot.reloadCurrentUser();
    await _attendre(recus, 2);

    final client = recus.last as ClientUser;
    expect(client.defaultAddressId, 'adr-maison');
  });

  test('les événements de session passent toujours', () async {
    source.session = null;
    source.evenements.add(const AuthState(AuthChangeEvent.signedOut, null));
    await _attendre(recus, 2);
    expect(recus.last, isNull);

    source.session = _session('client-awa');
    source.evenements.add(AuthState(AuthChangeEvent.signedIn, source.session));
    await _attendre(recus, 3);
    expect(recus.last?.displayName, 'Awa Traoré');
  });

  test('un nom refusé lève un message lisible, et rien n\'est relu', () async {
    source.refus = const PostgrestException(
      message: 'Votre nom doit compter au moins 2 caractères.',
      code: 'P0001',
    );

    await expectLater(
      depot.setDisplayName('A'),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.message,
          'message',
          'Votre nom doit compter au moins 2 caractères.',
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(recus, hasLength(1));
  });

  test('après le désabonnement, une relecture n\'émet plus rien', () async {
    final fin = abonnement.cancel();
    // La relecture réveille le flux arrêté : il se termine au lieu d'émettre.
    await depot.reloadCurrentUser();
    await fin;
    expect(recus, hasLength(1));
  });
}
