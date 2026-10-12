library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';

import '../test/support/supabase_test_harness.dart';
import 'support/parcours_visuel.dart';

/// Le maillon que rien d'autre ne couvre : **l'acquisition GPS**.
///
/// Partout ailleurs, la position du livreur est écrite en appelant la RPC
/// directement — ce qui vérifie la base, les règles d'accès et la carte, mais
/// pas que le téléphone sache où il est ni que l'app sache le demander.
/// Ici, personne n'appelle la RPC : le test se contente d'actionner
/// l'interrupteur « En service » et regarde si une position **venue du
/// GPS** arrive en base.
///
/// Prérequis, posés par l'appelant avant `flutter drive` :
///
///   xcrun simctl privacy `<id>` grant location com.mtc.mtcApp
///   xcrun simctl location `<id>` set 12.6500,-8.0100
///
/// La permission est accordée d'avance parce qu'un test Flutter ne peut pas
/// toucher une alerte système iOS, qui vit hors de l'app.
const _latitudeSimulee = 12.6500;

/// Ce que `setOnline` écrit faute de mieux : le centre de Bamako. Distinct de
/// la position simulée, pour que « ça a marché » ne puisse pas être confondu
/// avec « la valeur de repli était déjà là ».
const _latitudeVille = 12.6392;

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'focus position — prendre son service transmet une position GPS',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      echecs.clear();
      await demarrer(tester);

      await etapeVisuelle(tester, 'position-01-hors-service', () async {
        await seConnecter(tester, 'livreur1');
        await attendre(tester, find.text('Hors service'));
      });

      await etapeVisuelle(tester, 'position-02-en-service', () async {
        await tester.tap(find.byType(Switch));
        await avancer(tester, pas: 14);
      });

      // Lecture avec la session du livreur : sa fiche n'est visible que de
      // lui-même et du staff.
      double? latitude;
      await tester.runAsync(() async {
        final client = createTestSupabaseClient();
        await client.auth.signInWithPassword(
          email: pseudoEmail('livreur1'),
          password: 'password123',
        );
        for (var i = 0; i < 30; i++) {
          final row = await client
              .from('couriers')
              .select('last_latitude')
              .eq('id', 'f1c4e8a2-0000-5000-9000-000000000001')
              .single();
          latitude = (row['last_latitude'] as num?)?.toDouble();
          // On attend une position *du GPS*, pas celle de repli écrite par
          // la prise de service.
          if (latitude != null && (latitude! - _latitudeVille).abs() > 0.001) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        await client.dispose();
      });

      expect(
        latitude,
        isNotNull,
        reason: 'Aucune position transmise après la prise de service.',
      );
      // Marge serrée à dessein : l'écart entre la position simulée et la
      // valeur de repli n'est que de 0,0108°. Une tolérance de 0,01° les
      // sépare à peine — le test passerait presque sans GPS. À 0,002°, seule
      // une vraie position acquise peut satisfaire l'assertion.
      expect(
        latitude!,
        closeTo(_latitudeSimulee, 0.002),
        reason:
            'Position reçue ($latitude) : ce n\'est pas celle du GPS simulé '
            '($_latitudeSimulee). La chaîne geolocator → RPC ne fonctionne pas.',
      );

      if (echecs.isNotEmpty) {
        debugPrint('ÉTAPES EN ÉCHEC (position) :\n${echecs.join('\n')}');
      }
      expect(echecs, isEmpty, reason: 'Étapes du focus position en échec');
    },
  );
}
