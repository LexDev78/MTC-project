@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../support/supabase_test_harness.dart';

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

  Future<void> login(String usernameOrPhone) async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: usernameOrPhone, password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test(
    'a signed-in user registers and deletes their own device token; direct '
    'writes to the table are refused',
    () async {
      await login('client1');
      final selfId = container.read(currentUserProvider).value!.id;
      final client = container.read(supabaseClientProvider);

      // L'enregistrement passe par `register_device_token` (`0149`), comme
      // dans l'app : le compte est celui de la session, jamais un paramètre.
      await client.rpc('register_device_token', params: {'p_token': 'fcm-token-self-1'});
      final own = await fetchDeviceTokensForUserAsAdmin(selfId);
      expect(own.single['fcm_token'], 'fcm-token-self-1');

      // Le réenregistrer (rotation, relance de l'app) met à jour la même
      // ligne au lieu d'en créer une seconde.
      await client.rpc('register_device_token', params: {'p_token': 'fcm-token-self-1'});
      final afterAgain = await fetchDeviceTokensForUserAsAdmin(selfId);
      expect(afterAgain.length, 1);

      // Écrire la table directement ne passe plus, pour soi comme pour un
      // autre.
      for (final userId in [selfId, DemoIds.clientMoussa]) {
        await expectLater(
          client.from('device_tokens').insert({
            'user_id': userId,
            'fcm_token': 'fcm-token-direct',
          }),
          throwsA(isA<PostgrestException>()),
        );
      }

      // Effacer le sien, à la déconnexion, reste permis.
      await client.from('device_tokens').delete().eq('fcm_token', 'fcm-token-self-1');
      final afterDelete = await fetchDeviceTokensForUserAsAdmin(selfId);
      expect(afterDelete, isEmpty);
    },
  );

  test(
    'get_device_tokens_for_notification_user resolves a plain client id to '
    'just their own tokens, and the shared MTC storefront id to every '
    'staff device',
    () async {
      // Each token is registered from its own owner's session —
      // `register_device_token` (`0149`) gives it to whoever is signed in,
      // so Awa's token can only land while Awa herself is signed in, same
      // for each staff account.
      await login('client1');
      final clientClient = container.read(supabaseClientProvider);
      await clientClient.rpc('register_device_token', params: {'p_token': 'fcm-token-awa'});

      await container.read(authRepositoryProvider).logout();
      await login('agent1');
      final agentClient = container.read(supabaseClientProvider);
      await agentClient.rpc('register_device_token', params: {'p_token': 'fcm-token-agent'});

      await container.read(authRepositoryProvider).logout();
      await login('admin1');
      final adminClient = container.read(supabaseClientProvider);
      await adminClient.rpc('register_device_token', params: {'p_token': 'fcm-token-admin'});

      final clientTokens = await tokensForNotificationUserAsAdmin(DemoIds.clientAwa);
      expect(clientTokens, ['fcm-token-awa']);

      final staffTokens = await tokensForNotificationUserAsAdmin(
        DemoIds.supplierMtcOfficiel,
      );
      expect(
        staffTokens.toSet(),
        {'fcm-token-agent', 'fcm-token-admin'},
      );
    },
  );
}
