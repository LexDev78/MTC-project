import '../../domain/entities/chat.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/in_memory_chat_datasource.dart';

class InMemoryChatRepository implements ChatRepository {
  InMemoryChatRepository(this._datasource);

  final InMemoryChatDatasource _datasource;

  @override
  Stream<List<ChatConversation>> watchConversationsForUser(String clientId) {
    return _datasource.watchConversations().map(
      (conversations) =>
          conversations.where((c) => c.clientId == clientId).toList()
            ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt)),
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _datasource.watchMessages().map(
      (messages) =>
          messages.where((m) => m.conversationId == conversationId).toList()
            ..sort((a, b) => a.sentAt.compareTo(b.sentAt)),
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
    ChatAttachmentType attachmentType = ChatAttachmentType.none,
    String? attachmentPath,
    int? voiceDurationSeconds,
  }) async {
    _datasource.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      text: text,
      productId: productId,
      productNameSnapshot: productNameSnapshot,
      productImageSnapshot: productImageSnapshot,
      productPriceFcfaSnapshot: productPriceFcfaSnapshot,
      attachmentType: attachmentType,
      attachmentPath: attachmentPath,
      voiceDurationSeconds: voiceDurationSeconds,
    );
  }

  @override
  Future<String> startOrGetConversation({
    required String clientId,
    required String supplierId,
    required String supplierName,
  }) async {
    return _datasource.startOrGetConversation(
      clientId: clientId,
      supplierId: supplierId,
      supplierName: supplierName,
    );
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    _datasource.markConversationRead(conversationId);
  }
}
