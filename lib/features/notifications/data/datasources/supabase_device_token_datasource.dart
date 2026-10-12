import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw `device_tokens` I/O — see `0034_device_tokens.sql`. `id` is never
/// sent: it defaults server-side (`gen_random_uuid()::text`) precisely so
/// this upsert-by-`fcm_token` leaves an existing row's `id` alone instead of
/// rotating it on every token refresh.
class SupabaseDeviceTokenDatasource {
  SupabaseDeviceTokenDatasource(this._client);

  final SupabaseClient _client;

  Future<void> upsert({required String userId, required String fcmToken}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('device_tokens')
        .upsert({
          'user_id': userId,
          'fcm_token': fcmToken,
          'updated_at': now,
          'last_seen_at': now,
        }, onConflict: 'fcm_token');
  }

  Future<void> delete(String fcmToken) async {
    await _client.from('device_tokens').delete().eq('fcm_token', fcmToken);
  }
}
