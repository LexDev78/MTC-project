import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/id_generator.dart';
import 'package:mtc_app/core/utils/realtime_retry.dart';

/// Raw `chat_conversations`/`chat_messages` I/O — no `ChatConversation`/
/// `ChatMessage` entity knowledge here. Unlike every other Lot 4-7
/// datasource, this one uses real Postgres Realtime (`.stream()`) rather
/// than "notify after my own write" — a thread must show the other
/// participant's messages live, without navigating away and back (see
/// BACKEND_MIGRATION_PROGRESS.md, Lot 7). `chat_messages`/
/// `chat_conversations` were added to the `supabase_realtime` publication
/// in `0006_lot7_realtime_and_notifications.sql`. `.stream()` is used only
/// as a "something changed" trigger (`.eq()`, no `.order()`) — a freshly
/// realtime-delivered row isn't reliably merged into the client-side
/// cache in the requested order, so each emission triggers a plain
/// `.asyncMap()` refetch instead, same pattern as orders (Lot 5) and for
/// the same reason.
class SupabaseChatDatasource {
  SupabaseChatDatasource(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchConversationsForUser(String clientId) {
    return withRealtimeRetry(
      () => _client
          .from('chat_conversations')
          .stream(primaryKey: ['id'])
          .eq('client_id', clientId)
          .asyncMap(
            (_) => _client
                .from('chat_conversations')
                .select()
                .eq('client_id', clientId)
                .order('last_message_at', ascending: false),
          ),
    );
  }

  Stream<List<Map<String, dynamic>>> watchConversationsForSupplier(String supplierId) {
    return withRealtimeRetry(
      () => _client
          .from('chat_conversations')
          .stream(primaryKey: ['id'])
          .eq('supplier_id', supplierId)
          .asyncMap(
            (_) => _client
                .from('chat_conversations')
                .select()
                .eq('supplier_id', supplierId)
                .order('last_message_at', ascending: false),
          ),
    );
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    return withRealtimeRetry(
      () => _client
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .asyncMap(
            (_) => _client
                .from('chat_messages')
                .select()
                .eq('conversation_id', conversationId)
                .order('sent_at', ascending: true),
          ),
    );
  }

  Future<Map<String, dynamic>> getConversationById(String conversationId) {
    return _client.from('chat_conversations').select().eq('id', conversationId).single();
  }

  Future<void> sendMessage(Map<String, dynamic> row) async {
    final conversationId = row['conversation_id'] as String;
    final senderId = row['sender_id'] as String;

    await _client.from('chat_messages').insert({'id': IdGenerator.next(), ...row});

    final conversation = await getConversationById(conversationId);
    final isFromClient = senderId == conversation['client_id'];
    final String preview;
    if (row['attachment_type'] == 'image') {
      preview = '📷 Photo';
    } else if (row['attachment_type'] == 'voice') {
      preview = '🎤 Message vocal';
    } else if (row['product_name_snapshot'] != null) {
      preview = '📦 ${row['product_name_snapshot']}';
    } else {
      preview = row['text'] as String;
    }

    await _client
        .from('chat_conversations')
        .update({
          'last_message_preview': preview,
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
          if (isFromClient)
            'unread_count_supplier': (conversation['unread_count_supplier'] as int) + 1
          else
            'unread_count_client': (conversation['unread_count_client'] as int) + 1,
        })
        .eq('id', conversationId);
  }

  Future<String> startOrGetConversation({
    required String clientId,
    required String clientDisplayNameSnapshot,
    required String supplierId,
    required String supplierName,
  }) async {
    final existing = await _client
        .from('chat_conversations')
        .select('id')
        .eq('client_id', clientId)
        .eq('supplier_id', supplierId)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final id = IdGenerator.next();
    await _client.from('chat_conversations').insert({
      'id': id,
      'client_id': clientId,
      'client_display_name_snapshot': clientDisplayNameSnapshot,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
    });
    return id;
  }

  Future<void> markConversationRead({
    required String conversationId,
    required bool readByClient,
  }) async {
    await _client
        .from('chat_conversations')
        .update({readByClient ? 'unread_count_client' : 'unread_count_supplier': 0})
        .eq('id', conversationId);
    await _client
        .from('chat_messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .eq('is_read', false);
  }
}
