import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/error/user_message.dart';

// `messagePourUtilisateur` : ce que l'utilisateur lit quand quelque chose
// échoue. La règle tient en une phrase — **jamais un code, jamais de
// l'anglais** — et chaque cas ci-dessous est une façon dont un code ou de
// l'anglais arrivait à l'écran avant.
void main() {
  /// Ce qui ne doit jamais apparaître dans un message montré.
  void sansJargon(String message) {
    for (final interdit in [
      'Exception',
      'PGRST',
      'code:',
      'JSON object',
      'null',
      'Instance of',
    ]) {
      expect(message, isNot(contains(interdit)), reason: 'contient « $interdit »');
    }
  }

  group('nos propres messages passent tels quels', () {
    test('une AppException', () {
      expect(
        messagePourUtilisateur(const ValidationException('Pièces manquantes.')),
        'Pièces manquantes.',
      );
    });

    test('un « raise exception » de nos fonctions SQL (P0001)', () {
      // Ils sont rédigés en français pour l'utilisateur, exprès.
      const e = PostgrestException(
        message: 'Ce collaborateur a déjà accès à votre boutique.',
        code: 'P0001',
      );
      expect(
        messagePourUtilisateur(e),
        'Ce collaborateur a déjà accès à votre boutique.',
      );
    });

    test('le message d\'erreur d\'une de nos fonctions edge', () {
      const e = FunctionException(
        status: 400,
        details: {'error': 'Ce nom d\'utilisateur est déjà pris.'},
      );
      expect(messagePourUtilisateur(e), 'Ce nom d\'utilisateur est déjà pris.');
    });
  });

  group('les erreurs de la base deviennent des phrases', () {
    test('PGRST116 — le code que lisait le collaborateur retiré', () {
      const e = PostgrestException(
        message: 'JSON object requested, multiple (or no) rows returned',
        code: 'PGRST116',
        details: 'The result contains 0 rows',
      );
      final message = messagePourUtilisateur(e);
      sansJargon(message);
      expect(message, contains('introuvable'));
    });

    test('un refus de droits (42501)', () {
      const e = PostgrestException(
        message: 'permission denied for table payout_requests',
        code: '42501',
      );
      final message = messagePourUtilisateur(e);
      sansJargon(message);
      expect(message, contains('autorisation'));
    });

    test('une violation de RLS sans code exploitable', () {
      const e = PostgrestException(
        message: 'new row violates row-level security policy for table "x"',
      );
      expect(messagePourUtilisateur(e), contains('autorisation'));
    });

    test('un doublon (23505)', () {
      const e = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );
      expect(messagePourUtilisateur(e), 'Cet élément existe déjà.');
    });

    test('une valeur refusée par une énumération (22P02)', () {
      const e = PostgrestException(
        message: 'invalid input value for enum notification_type: "x"',
        code: '22P02',
      );
      final message = messagePourUtilisateur(e);
      sansJargon(message);
      expect(message, contains('valeurs'));
    });
  });

  group('l\'authentification ne parle plus anglais', () {
    test('identifiants faux', () {
      expect(
        messagePourUtilisateur(const AuthException('Invalid login credentials')),
        'Identifiants incorrects.',
      );
    });

    test('mot de passe identique à l\'ancien', () {
      expect(
        messagePourUtilisateur(
          const AuthException(
            'New password should be different from the old password.',
          ),
        ),
        contains('différent'),
      );
    });

    test('session expirée', () {
      expect(
        messagePourUtilisateur(const AuthException('JWT expired')),
        contains('session a expiré'),
      );
    });
  });

  group('le stockage et le réseau', () {
    test('un envoi refusé', () {
      const e = StorageException(
        'new row violates row-level security policy',
        statusCode: '403',
      );
      expect(messagePourUtilisateur(e), contains('autorisation'));
    });

    test('une panne du stockage (le 42P10 vécu)', () {
      const e = StorageException(
        'database error, code: 42P10',
        statusCode: '500',
      );
      final message = messagePourUtilisateur(e);
      sansJargon(message);
      expect(message, contains('envoi du fichier'));
    });

    test('pas de réseau', () {
      expect(
        messagePourUtilisateur(http.ClientException('Connection refused')),
        contains('connexion internet'),
      );
    });

    test('un délai dépassé', () {
      expect(
        messagePourUtilisateur(TimeoutException('trop long')),
        contains('trop de temps'),
      );
    });

    test('le runtime des fonctions arrêté (503)', () {
      const e = FunctionException(status: 503, details: 'name resolution failed');
      expect(messagePourUtilisateur(e), contains('indisponible'));
    });
  });

  group('le repli', () {
    test('remplace le message générique par celui de l\'endroit', () {
      expect(
        messagePourUtilisateur(
          StateError('inattendu'),
          repli: 'La promotion n\'a pas pu être créée.',
        ),
        'La promotion n\'a pas pu être créée.',
      );
    });

    test('vaut aussi quand il n\'y a pas d\'erreur', () {
      expect(messagePourUtilisateur(null, repli: 'Code refusé.'), 'Code refusé.');
    });

    test('un « Exception: … » de notre code perd seulement son préfixe', () {
      expect(
        messagePourUtilisateur(Exception('Fichier trop volumineux (max 5 Mo).')),
        'Fichier trop volumineux (max 5 Mo).',
      );
    });

    test('une erreur de programmation ne fuit jamais', () {
      final message = messagePourUtilisateur(
        TypeError(),
        repli: 'Une erreur est survenue.',
      );
      sansJargon(message);
    });
  });
}
