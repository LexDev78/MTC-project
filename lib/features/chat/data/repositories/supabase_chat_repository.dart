import '../../domain/entities/chat.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/supabase_chat_datasource.dart';

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._datasource);

  final SupabaseChatDatasource _datasource;

  @override
  Stream<List<ChatConversation>> watchConversationsForUser(String clientId) {
    return _datasource
        .watchConversationsForUser(clientId)
        .map((rows) => rows.map(ChatConversation.fromJson).toList());
  }

  @override
  Stream<List<ChatConversation>> watchConversationsForSupplier(String supplierId) {
    return _datasource
        .watchConversationsForSupplier(supplierId)
        .map((rows) => rows.map(ChatConversation.fromJson).toList());
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _datasource
        .watchMessages(conversationId)
        .map((rows) => rows.map(ChatMessage.fromJson).toList());
  }

  @override
  Future<ChatConversation> getConversationById(String conversationId) async {
    return ChatConversation.fromJson(
      await _datasource.getConversationById(conversationId),
    );
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? productId,
    String? productNameSnapshot,
    String? productImageSnapshot,
    int? productPriceFcfaSnapshot,
    String? productVariantId,
    String? productVariantNameSnapshot,
    ChatAttachmentType attachmentType = ChatAttachmentType.none,
    String? attachmentPath,
    int? voiceDurationSeconds,
  }) {
    return _datasource.sendMessage({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'text': text,
      'product_id': productId,
      'product_name_snapshot': productNameSnapshot,
      'product_image_snapshot': productImageSnapshot,
      'product_price_fcfa_snapshot': productPriceFcfaSnapshot,
      'product_variant_id': productVariantId,
      'product_variant_name_snapshot': productVariantNameSnapshot,
      'attachment_type': attachmentType.name,
      'attachment_path': attachmentPath,
      'voice_duration_seconds': voiceDurationSeconds,
    });
  }

  @override
  Future<String> startOrGetConversation({
    required String clientId,
    required String clientDisplayNameSnapshot,
    required String supplierId,
    required String supplierName,
  }) {
    return _datasource.startOrGetConversation(
      clientId: clientId,
      clientDisplayNameSnapshot: clientDisplayNameSnapshot,
      supplierId: supplierId,
      supplierName: supplierName,
    );
  }

  @override
  Future<void> markConversationRead({
    required String conversationId,
    required ChatParticipant readBy,
  }) {
    return _datasource.markConversationRead(
      conversationId: conversationId,
      readByClient: readBy == ChatParticipant.client,
    );
  }
}
