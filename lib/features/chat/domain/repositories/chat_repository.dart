import '../entities/chat.dart';

abstract interface class ChatRepository {
  Stream<List<ChatConversation>> watchConversationsForUser(String clientId);

  Stream<List<ChatMessage>> watchMessages(String conversationId);

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? productId,
    String? productNameSnapshot,
    String? productImageSnapshot,
    int? productPriceFcfaSnapshot,
    ChatAttachmentType attachmentType,
    String? attachmentPath,
    int? voiceDurationSeconds,
  });

  /// Returns the existing conversation ID between this client and supplier,
  /// or creates a new one.
  Future<String> startOrGetConversation({
    required String clientId,
    required String supplierId,
    required String supplierName,
  });

  Future<void> markConversationRead(String conversationId);
}
