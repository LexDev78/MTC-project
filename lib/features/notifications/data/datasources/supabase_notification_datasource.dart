import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';


/// Raw `notifications` I/O. No Realtime (out of scope — see
/// `0006_lot7_realtime_and_notifications.sql`; a recipient sees a new
/// notification on their next screen visit, same "notify after my own
/// write" shape as Lot 4's datasources, not live mid-session like chat).
class SupabaseNotificationDatasource {
  SupabaseNotificationDatasource(this._client);

  final SupabaseClient _client;

  final _changes = StreamController<void>.broadcast();

  Stream<T> _watch<T>(Future<T> Function() fetch) {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changes.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).asyncMap((_) => fetch());
  }

  void _notify() => _changes.add(null);

  Stream<List<Map<String, dynamic>>> watchForUser(String userId) {
    return _watch(
      () => _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false),
    );
  }

  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
    _notify();
  }

  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
    _notify();
  }

  Future<void> markReadByReference({
    required String userId,
    required String referenceId,
  }) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('reference_id', referenceId)
        .eq('is_read', false);
    _notify();
  }

  /// La ligne de réglages de [userId] (`0118`), ou `null` s'il n'a jamais
  /// rien réglé. La RLS ne laisse lire que la sienne.
  Future<Map<String, dynamic>?> fetchPreferences(String userId) {
    return _client
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
  }

  /// Crée ou remplace la ligne de réglages (clé : `user_id`).
  Future<void> savePreferences(Map<String, dynamic> row) async {
    await _client.from('notification_preferences').upsert(row);
  }
}
