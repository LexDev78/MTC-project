import '../entities/chat.dart';

abstract interface class ChatRepository {
  Stream<List<ChatConversation>> watchConversationsForUser(String clientId);

  Stream<List<ChatConversation>> watchConversationsForSupplier(
    String supplierId,
  );

  Stream<List<ChatMessage>> watchMessages(String conversationId);

  /// Used by `ChatController.send*` to resolve the message's recipient
  /// (the other side of `senderId`) for a notification, without needing a
  /// presentation-layer projection already warm from some screen.
  Future<ChatConversation> getConversationById(String conversationId);

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
    required String clientDisplayNameSnapshot,
    required String supplierId,
    required String supplierName,
  });

  Future<void> markConversationRead({
    required String conversationId,
    required ChatParticipant readBy,
  });
}
