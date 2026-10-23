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

  /// L'insertion seule : l'aperçu, la date et le compteur du destinataire
  /// sont tenus par la base (`chat_message_touch_conversation`, `0122`).
  /// L'application les écrivait elle-même, ce qui laissait chaque côté
  /// réécrire l'aperçu que l'autre lit. Dans une conversation que le client
  /// a fermée, la base refuse le message de la boutique.
  Future<void> sendMessage(Map<String, dynamic> row) async {
    await _client.from('chat_messages').insert({
      'id': IdGenerator.next(),
      ...row,
    });
  }

  Future<String> startOrGetConversation({
    required String clientId,
    required String clientDisplayNameSnapshot,
    required String supplierId,
    required String supplierName,
  }) async {
    Future<String?> existante() async {
      final row = await _client
          .from('chat_conversations')
          .select('id')
          .eq('client_id', clientId)
          .eq('supplier_id', supplierId)
          .maybeSingle();
      return row?['id'] as String?;
    }

    final deja = await existante();
    if (deja != null) return deja;

    // Les noms envoyés ici sont remplacés par ceux des comptes à la création
    // (`chat_conversation_defaults`, `0122`).
    final id = IdGenerator.next();
    try {
      await _client.from('chat_conversations').insert({
        'id': id,
        'client_id': clientId,
        'client_display_name_snapshot': clientDisplayNameSnapshot,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
      });
    } on PostgrestException catch (e) {
      // Une seule conversation par client et par boutique : si l'autre côté
      // l'a créée entre la lecture et l'écriture, c'est la sienne.
      if (e.code != '23505') rethrow;
      final creee = await existante();
      if (creee == null) rethrow;
      return creee;
    }
    return id;
  }

  /// Ferme ([closed] vrai) ou rouvre la conversation — le client seul, la
  /// base refuse tout autre appelant. Rend la date de fermeture.
  Future<DateTime?> setConversationClosed({
    required String conversationId,
    required bool closed,
  }) async {
    final ferme = await _client.rpc(
      'set_my_conversation_closed',
      params: {'p_conversation_id': conversationId, 'p_closed': closed},
    );
    return ferme == null ? null : DateTime.parse(ferme as String);
  }

  /// Remet à zéro le compteur du côté de l'appelant et marque lus les
  /// messages de l'autre côté — la base sait de quel côté il est
  /// (`mark_my_conversation_read`, `0122`).
  Future<void> markConversationRead({required String conversationId}) {
    return _client.rpc(
      'mark_my_conversation_read',
      params: {'p_conversation_id': conversationId},
    );
  }
}
