library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/realtime_retry.dart';

// `withRealtimeRetry` enveloppe tous les flux temps réel de l'app : ce qu'il
// décide de réessayer ou non détermine si un écran affiche une erreur ou
// tourne indéfiniment.
void main() {
  test('une erreur transitoire est réessayée, et le flux reprend', () async {
    var attempts = 0;
    final stream = withRealtimeRetry<int>(
      () {
        attempts++;
        // Le premier abonnement échoue (websocket coupé), le second marche.
        return attempts == 1
            ? Stream<int>.error(const SocketException('coupure'))
            : Stream<int>.value(42);
      },
      initialDelay: const Duration(milliseconds: 10),
    );

    expect(await stream.first, 42);
    expect(attempts, 2);
  });

  test(
    'une erreur permanente est propagée immédiatement, sans réessai',
    () async {
      var attempts = 0;
      final stream = withRealtimeRetry<int>(
        () {
          attempts++;
          // 42703 : colonne inconnue. Exactement le bug qui, sans ce tri,
          // laissait l'écran livreur tourner sans fin.
          return Stream<int>.error(
            const PostgrestException(
              message: 'column does not exist',
              code: '42703',
            ),
          );
        },
        initialDelay: const Duration(milliseconds: 10),
      );

      await expectLater(stream, emitsError(isA<PostgrestException>()));
      // Le bug d'origine : la requête invalide était réessayée sans fin et
      // l'écran restait en chargement.
      expect(attempts, 1);
    },
  );

  test(
    'une erreur Postgrest *passagère* est réessayée, pas propagée',
    () async {
      var attempts = 0;
      final stream = withRealtimeRetry<int>(
        () {
          attempts++;
          // PGRST301 : jeton expiré. Le rafraîchissement en cours va le
          // régler — couper ici viderait l'écran d'un utilisateur dont la
          // session se renouvelle normalement.
          return attempts == 1
              ? Stream<int>.error(
                  const PostgrestException(
                    message: 'JWT expired',
                    code: 'PGRST301',
                  ),
                )
              : Stream<int>.value(7);
        },
        initialDelay: const Duration(milliseconds: 10),
      );

      expect(await stream.first, 7);
      expect(attempts, 2);
    },
  );

  test(
    'des échecs répétés sans aucune donnée finissent par être propagés',
    () async {
      var attempts = 0;
      final stream = withRealtimeRetry<int>(
        () {
          attempts++;
          return Stream<int>.error(const SocketException('toujours coupé'));
        },
        initialDelay: const Duration(milliseconds: 1),
        maxAttemptsWithoutData: 3,
      );

      await expectLater(stream, emitsError(isA<SocketException>()));
      expect(attempts, 3);
    },
  );
}

/// Erreur transitoire quelconque, sans dépendre de `dart:io` (indisponible
/// sur toutes les cibles de test).
class SocketException implements Exception {
  const SocketException(this.message);
  final String message;
  @override
  String toString() => 'SocketException: $message';
}
