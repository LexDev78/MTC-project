@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../support/supabase_test_harness.dart';

// Le compte lui-même : changer son mot de passe, ajouter une adresse e-mail.
//
// Deux choses se vérifient ici. Que le mot de passe ne change **qu'avec
// l'ancien** — sans quoi un téléphone déverrouillé suffirait à confisquer le
// compte. Et que l'adresse e-mail reste une adresse de contact, à soi seul,
// unique, jamais un pseudo-e-mail `@mtc.local`, et prouvée par le code
// qu'elle a reçu (`0124`) — lu ici dans la boîte de test, Mailpit.
void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetAndSeed();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> connecter(String identifiant) async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: identifiant, password: 'password123');
    await container.read(currentUserProvider.future);
  }

  /// Une connexion indépendante, pour vérifier qu'un mot de passe ouvre —
  /// ou n'ouvre plus — le compte.
  Future<bool> ouvre(String identifiant, String motDePasse) async {
    final client = createTestSupabaseClient();
    addTearDown(client.dispose);
    try {
      await client.auth.signInWithPassword(
        email: pseudoEmail(identifiant),
        password: motDePasse,
      );
      return true;
    } on AuthException {
      return false;
    }
  }

  group('changer son mot de passe', () {
    test('le bon ancien mot de passe ouvre le changement', () async {
      await connecter('client1');

      await container
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: 'password123',
            newPassword: 'Bamako2026',
          );

      expect(await ouvre('client1', 'Bamako2026'), isTrue);
      expect(
        await ouvre('client1', 'password123'),
        isFalse,
        reason: 'l\'ancien mot de passe ne doit plus rien ouvrir',
      );
    });

    test('les autres sessions du compte sont fermées, pas celle-ci', () async {
      // Changer son mot de passe doit aussi couper un téléphone perdu, ou
      // un appareil prêté où la session est restée ouverte — sans
      // déconnecter l'appareil d'où l'on vient de le changer.
      final autreAppareil = createTestSupabaseClient();
      addTearDown(autreAppareil.dispose);
      await autreAppareil.auth.signInWithPassword(
        email: pseudoEmail('client1'),
        password: 'password123',
      );

      await connecter('client1');
      await container
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: 'password123',
            newPassword: 'Bamako2026',
          );

      // L'autre appareil ne peut plus renouveler sa session. (Le jeton
      // d'accès qu'il détient déjà reste valable jusqu'à son expiration,
      // une heure au plus : c'est le principe des jetons signés.)
      await expectLater(
        autreAppareil.auth.refreshSession(),
        throwsA(isA<AuthException>()),
      );
      // Celui-ci reste connecté.
      final ici = await container
          .read(supabaseClientProvider)
          .auth
          .refreshSession();
      expect(ici.session, isNotNull);
    });

    test('un ancien mot de passe faux est refusé, en français', () async {
      // Le cas qui justifie l'écran : quelqu'un a le téléphone en main,
      // session ouverte, mais pas le mot de passe.
      await connecter('client1');

      await expectLater(
        container
            .read(authRepositoryProvider)
            .changePassword(
              currentPassword: 'devine123',
              newPassword: 'Bamako2026',
            ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Mot de passe actuel incorrect.',
          ),
        ),
      );
      expect(await ouvre('client1', 'password123'), isTrue);
    });

    test('un nouveau mot de passe trop court est refusé', () async {
      await connecter('client1');

      await expectLater(
        container
            .read(authRepositoryProvider)
            .changePassword(currentPassword: 'password123', newPassword: '123'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('6 caractères'),
          ),
        ),
      );
    });

    test('un collaborateur change aussi le sien', () async {
      // C'est son compte, pas celui de la boutique : la route vit hors des
      // aires de rôle, et rien ne la lui ferme.
      await createCollaboratorAsAdmin(
        supplierId: 'b7eb8585-4091-5b6f-83f7-5d70724e97a3',
        username: 'vendeur_mdp',
        permissions: const {'products'},
      );
      await connecter('vendeur_mdp');

      await container
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: 'password123',
            newPassword: 'Segou2026',
          );
      expect(await ouvre('vendeur_mdp', 'Segou2026'), isTrue);
    });
  });

  /// Une adresse ajoutée comme dans l'app : un code part, il est lu dans la
  /// boîte (Mailpit), et c'est en le donnant qu'elle s'enregistre (`0124`).
  Future<String> ajouter(ProviderContainer conteneur, String adresse) async {
    final depot = conteneur.read(authRepositoryProvider);
    final demande = await depot.requestContactEmailCode(adresse);
    return depot.confirmContactEmail(await codeRecuPar(demande.email));
  }

  group('l\'adresse e-mail de contact', () {

    test('elle s\'ajoute par le code reçu, normalisée, et se relit', () async {
      await connecter('client1');
      final depot = container.read(authRepositoryProvider);

      final enregistree = await ajouter(container, '  Awa.Traore@Example.com ');

      expect(enregistree, 'awa.traore@example.com');
      expect(await depot.fetchContactEmail(), 'awa.traore@example.com');
      final etat = await depot.fetchContactEmailStatus();
      expect(etat.verified, isTrue);
    });

    test('sans le code, rien ne s\'enregistre', () async {
      await connecter('client1');
      final depot = container.read(authRepositoryProvider);

      await expectLater(
        depot.setContactEmail('awa@example.com'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('code'),
          ),
        ),
      );
      // Le code part, mais tant qu'il n'est pas donné l'adresse n'est pas
      // celle du compte. L'e-mail est lu pour ne pas l'oublier dans la boîte.
      await depot.requestContactEmailCode('awa@example.com');
      expect(await codeRecuPar('awa@example.com'), matches(RegExp(r'^[0-9]{6}$')));
      expect(await depot.fetchContactEmail(), isNull);
    });

    test('un code faux est refusé, et compté', () async {
      await connecter('client1');
      final depot = container.read(authRepositoryProvider);
      final demande = await depot.requestContactEmailCode('awa@example.com');
      final code = await codeRecuPar(demande.email);
      final faux = code == '000000' ? '111111' : '000000';

      await expectLater(
        depot.confirmContactEmail(faux),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Code incorrect. Il vous reste 4 essais.',
          ),
        ),
      );
      expect(await depot.confirmContactEmail(code), 'awa@example.com');
    });

    test('elle se retire', () async {
      await connecter('client1');
      final depot = container.read(authRepositoryProvider);
      await ajouter(container, 'awa@example.com');

      expect(await depot.setContactEmail(''), isNull);
      expect(await depot.fetchContactEmail(), isNull);
    });

    test('une adresse mal formée est refusée avant tout envoi', () async {
      await connecter('client1');
      await expectLater(
        container
            .read(authRepositoryProvider)
            .requestContactEmailCode('pas-une-adresse'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Adresse e-mail invalide.',
          ),
        ),
      );
    });

    test('le domaine des pseudo-e-mails est réservé', () async {
      // `@mtc.local` n'arrive nulle part : l'accepter laisserait croire à
      // une adresse valide.
      await connecter('client1');
      await expectLater(
        container
            .read(authRepositoryProvider)
            .requestContactEmailCode('awa@mtc.local'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('une adresse ne sert qu\'à un seul compte', () async {
      // Elle servira à récupérer un mot de passe oublié : partagée par deux
      // comptes, elle ne saurait pas lequel débloquer.
      await connecter('client1');
      await ajouter(container, 'famille@example.com');

      final autre = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
        ],
      );
      addTearDown(autre.dispose);
      await autre
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'client2', password: 'password123');

      await expectLater(
        // La casse ne trompe pas le contrôle.
        autre
            .read(authRepositoryProvider)
            .requestContactEmailCode('FAMILLE@example.com'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('déjà utilisée'),
          ),
        ),
      );
    });

    test('personne d\'autre ne la lit', () async {
      await connecter('client1');
      await ajouter(container, 'awa@example.com');

      final indiscret = createTestSupabaseClient();
      addTearDown(indiscret.dispose);
      await indiscret.auth.signInWithPassword(
        email: pseudoEmail('client2'),
        password: 'password123',
      );
      final lignes = await indiscret
          .from('profiles')
          .select('contact_email')
          .eq('contact_email', 'awa@example.com');
      expect(lignes, isEmpty);
    });
  });

  group('mot de passe oublié', () {
    test('le code reçu à l\'adresse vérifiée rend l\'accès au compte', () async {
      await connecter('client1');
      await ajouter(container, 'awa.traore@example.com');
      final depot = container.read(authRepositoryProvider);
      // On a oublié son mot de passe : on n'est plus connecté.
      await depot.logout();

      final demande = await depot.requestPasswordReset('client1');
      expect(demande.maskedEmail, 'aw•••@example.com');
      final code = await codeRecuPar('awa.traore@example.com');

      // Par l'adresse e-mail : le serveur rend l'identifiant de connexion.
      final identifiant = await depot.resetPasswordWithCode(
        identifier: 'awa.traore@example.com',
        code: code,
        newPassword: 'Bamako2026',
      );
      expect(identifiant, 'client1');
      expect(await ouvre('client1', 'Bamako2026'), isTrue);
      expect(await ouvre('client1', 'password123'), isFalse);
      // L'alerte « mot de passe changé » est partie ; la boîte reste propre.
      await viderBoitePour('awa.traore@example.com');
    });

    test('un code faux ne change rien, et il est compté', () async {
      await connecter('client1');
      await ajouter(container, 'awa.traore@example.com');
      final depot = container.read(authRepositoryProvider);
      await depot.logout();

      await depot.requestPasswordReset('client1');
      final code = await codeRecuPar('awa.traore@example.com');
      await expectLater(
        depot.resetPasswordWithCode(
          identifier: 'client1',
          code: code == '000000' ? '111111' : '000000',
          newPassword: 'Bamako2026',
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Code incorrect. Il vous reste 4 essais.',
          ),
        ),
      );
      expect(await ouvre('client1', 'password123'), isTrue);
    });

    test('sans adresse vérifiée, pas de récupération par e-mail', () async {
      await expectLater(
        container.read(authRepositoryProvider).requestPasswordReset('client2'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('pas d\'adresse e-mail vérifiée'),
          ),
        ),
      );
    });
  });
}
