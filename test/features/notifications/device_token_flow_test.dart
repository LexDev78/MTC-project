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
    'a signed-in user can upsert and delete their own device token; RLS '
    'rejects a token for another user_id',
    () async {
      await login('client1');
      final selfId = container.read(currentUserProvider).value!.id;
      final client = container.read(supabaseClientProvider);

      await client.from('device_tokens').insert({
        'user_id': selfId,
        'fcm_token': 'fcm-token-self-1',
      });

      final own = await fetchDeviceTokensForUserAsAdmin(selfId);
      expect(own.single['fcm_token'], 'fcm-token-self-1');

      // Upsert on conflict (fcm_token) — token rotation/re-registration
      // updates the same row rather than duplicating it.
      await client
          .from('device_tokens')
          .upsert({
            'user_id': selfId,
            'fcm_token': 'fcm-token-self-1',
            'platform': 'android',
          }, onConflict: 'fcm_token');
      final afterUpsert = await fetchDeviceTokensForUserAsAdmin(selfId);
      expect(afterUpsert.length, 1);

      // A token row claiming to belong to someone else is rejected by
      // `device_tokens_insert_own` (`with check (user_id = auth.uid())`).
      await expectLater(
        client.from('device_tokens').insert({
          'user_id': DemoIds.clientMoussa,
          'fcm_token': 'fcm-token-spoofed',
        }),
        throwsA(isA<PostgrestException>()),
      );

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
      // Each row is inserted from its own owner's session — RLS
      // (`device_tokens_insert_own`) requires `user_id = auth.uid()`, so
      // Awa's token can only land while Awa herself is signed in, same for
      // each staff account.
      await login('client1');
      final clientClient = container.read(supabaseClientProvider);
      await clientClient.from('device_tokens').insert({
        'user_id': DemoIds.clientAwa,
        'fcm_token': 'fcm-token-awa',
      });

      await container.read(authRepositoryProvider).logout();
      await login('agent1');
      final agentClient = container.read(supabaseClientProvider);
      await agentClient.from('device_tokens').insert({
        'user_id': DemoIds.staffAgent,
        'fcm_token': 'fcm-token-agent',
      });

      await container.read(authRepositoryProvider).logout();
      await login('admin1');
      final adminClient = container.read(supabaseClientProvider);
      await adminClient.from('device_tokens').insert({
        'user_id': DemoIds.staffAdmin,
        'fcm_token': 'fcm-token-admin',
      });

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
