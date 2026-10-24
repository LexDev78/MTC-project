// Un flux qui ne rend pas la main pendrait le test : mieux vaut qu'il
// échoue vite et dise lequel.
@Timeout(Duration(seconds: 30))
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:mtc_app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';

/// Le flux de l'utilisateur courant face aux erreurs (incident du
/// 24/10/2026) : juste après une connexion, PostgREST a refusé le jeton
/// tout neuf (`PGRST303`, « JWT issued at future ») à la relecture du
/// compte. L'erreur a terminé le flux ; le routeur n'a plus rien appris, et
/// dix connexions réussies n'ont jamais quitté l'écran de connexion.

/// La session et le profil d'un client, en mémoire. [echecs] : ce que les
/// prochaines lectures du profil lèvent, dans l'ordre, avant de réussir.
class _Source implements SupabaseAuthDatasource {
  final evenements = StreamController<AuthState>.broadcast();
  Session? session;
  final echecs = <Object>[];
  var lectures = 0;

  @override
  Session? get currentSession => session;

  @override
  Stream<AuthState> onAuthStateChange() => evenements.stream;

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    session = _session('client-awa');
    evenements.add(AuthState(AuthChangeEvent.signedIn, session));
    return AuthResponse(session: session);
  }

  @override
  Future<void> signOut() async {
    session = null;
    evenements.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<Map<String, dynamic>> fetchProfileRow(String userId) async {
    lectures++;
    if (echecs.isNotEmpty) throw echecs.removeAt(0);
    return {
      'id': userId,
      'role': 'client',
      'display_name': 'Awa Traoré',
      'username_or_phone': 'client1',
      'phone_number': '+223 70 12 34 56',
      'created_at': '2026-01-01T00:00:00Z',
      'deleted_at': null,
    };
  }

  /// Ouvre une session comme l'app le voit : un événement `signedIn`.
  void connecter() {
    session = _session('client-awa');
    evenements.add(AuthState(AuthChangeEvent.signedIn, session));
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

const _jetonDuFutur = PostgrestException(
  message: 'JWT issued at future',
  code: 'PGRST303',
);

/// Ce que le flux livre : des comptes (ou `null`) et des erreurs.
class _Recu {
  _Recu.compte(this.compte) : erreur = null;
  _Recu.erreur(this.erreur) : compte = null;

  final AppUser? compte;
  final Object? erreur;

  @override
  String toString() =>
      erreur != null ? 'erreur($erreur)' : 'compte(${compte?.id})';
}

/// Attend que [condition] tienne, jusqu'à [limite].
Future<void> _attendre(
  bool Function() condition, {
  Duration limite = const Duration(seconds: 5),
}) async {
  final fin = DateTime.now().add(limite);
  while (!condition() && DateTime.now().isBefore(fin)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late _Source source;
  late SupabaseAuthRepository depot;
  late List<_Recu> recus;
  late StreamSubscription<AppUser?> abonnement;
  late bool ferme;

  Future<void> ouvrir() async {
    recus = [];
    ferme = false;
    abonnement = depot.watchCurrentUser().listen(
      (compte) => recus.add(_Recu.compte(compte)),
      onError: (Object e) => recus.add(_Recu.erreur(e)),
      onDone: () => ferme = true,
    );
    await _attendre(() => recus.isNotEmpty);
  }

  bool aRecuLeCompte() => recus.any((r) => r.compte?.id == 'client-awa');

  setUp(() {
    source = _Source();
    depot = SupabaseAuthRepository(source);
  });

  tearDown(() async {
    unawaited(abonnement.cancel());
    await source.evenements.close();
  });

  test('le jeton refusé juste après la connexion est repris : le compte '
      'arrive', () async {
    await ouvrir();
    expect(recus.single.compte, isNull);

    source.echecs.add(_jetonDuFutur);
    source.connecter();
    await _attendre(aRecuLeCompte);

    expect(aRecuLeCompte(), isTrue, reason: '$recus');
    expect(recus.where((r) => r.erreur != null), isEmpty);
    expect(source.lectures, 2);
  });

  test('une erreur qui dure passe dans le flux sans le fermer : la '
      'connexion suivante aboutit', () async {
    await ouvrir();

    // Plus d'échecs que de reprises : l'erreur finit par sortir.
    source.echecs.addAll([
      for (var i = 0; i < 4; i++)
        const PostgrestException(message: 'indisponible', code: '503'),
    ]);
    source.connecter();
    await _attendre(() => recus.any((r) => r.erreur != null));
    expect(recus.last.erreur, isA<PostgrestException>());
    expect(ferme, isFalse);

    source.connecter();
    await _attendre(aRecuLeCompte);
    expect(aRecuLeCompte(), isTrue, reason: '$recus');
    expect(ferme, isFalse);
  });

  test('un refus qui dit quelque chose n\'est pas repris, et ne ferme pas '
      'le flux', () async {
    await ouvrir();

    source.echecs.add(
      const PostgrestException(message: 'permission denied', code: '42501'),
    );
    source.connecter();
    await _attendre(() => recus.any((r) => r.erreur != null));
    expect(source.lectures, 1);

    source.connecter();
    await _attendre(aRecuLeCompte);
    expect(aRecuLeCompte(), isTrue, reason: '$recus');
  });

  test('une erreur de la source de session ne ferme pas le flux', () async {
    await ouvrir();

    source.evenements.addError(
      const AuthException('Invalid Refresh Token: Refresh Token Not Found'),
    );
    await _attendre(() => recus.any((r) => r.erreur != null));
    expect(ferme, isFalse);

    source.connecter();
    await _attendre(aRecuLeCompte);
    expect(aRecuLeCompte(), isTrue, reason: '$recus');
  });

  test('une erreur à l\'ouverture ne ferme pas le flux', () async {
    source.session = _session('client-awa');
    source.echecs.add(
      const PostgrestException(message: 'permission denied', code: '42501'),
    );
    await ouvrir();
    expect(recus.single.erreur, isA<PostgrestException>());

    source.connecter();
    await _attendre(aRecuLeCompte);
    expect(aRecuLeCompte(), isTrue, reason: '$recus');
  });

  test('login() reprend aussi le jeton refusé, au lieu d\'échouer', () async {
    await ouvrir();
    // Les deux premières lectures échouent : celle du flux et celle de
    // `login()`, dans l'ordre où elles arrivent.
    source.echecs.addAll([_jetonDuFutur, _jetonDuFutur]);

    final compte = await depot.login(
      usernameOrPhone: 'client1',
      password: 'password123',
    );

    expect(compte.id, 'client-awa');
    expect(source.session, isNotNull, reason: 'la session reste ouverte');
    await _attendre(aRecuLeCompte);
    expect(aRecuLeCompte(), isTrue, reason: '$recus');
  });
}
