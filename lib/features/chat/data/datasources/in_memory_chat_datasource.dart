import 'dart:async';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/chat.dart';

class InMemoryChatDatasource {
  InMemoryChatDatasource() {
    final seed = _seed();
    _conversations.addAll(seed.$1);
    _messages.addAll(seed.$2);
  }

  final List<ChatConversation> _conversations = [];
  final List<ChatMessage> _messages = [];
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<List<ChatConversation>> watchConversations() {
    return Stream<void>.multi(
      (controller) {
        controller.add(null);
        final subscription = _changesController.stream.listen(controller.add);
        controller.onCancel = subscription.cancel;
      },
      isBroadcast: true,
    ).map((_) => List<ChatConversation>.unmodifiable(_conversations));
  }

  ChatConversation getConversationById(String conversationId) {
    return _conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () =>
          throw NotFoundException('Conversation introuvable : $conversationId'),
    );
  }

  Stream<List<ChatMessage>> watchMessages() {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changesController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map((_) => List<ChatMessage>.unmodifiable(_messages));
  }

  void sendMessage({
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
  }) {
    final message = ChatMessage(
      id: IdGenerator.next(),
      conversationId: conversationId,
      senderId: senderId,
      text: text,
      sentAt: DateTime.now(),
      isRead: false,
      productId: productId,
      productNameSnapshot: productNameSnapshot,
      productImageSnapshot: productImageSnapshot,
      productPriceFcfaSnapshot: productPriceFcfaSnapshot,
      attachmentType: attachmentType,
      attachmentPath: attachmentPath,
      voiceDurationSeconds: voiceDurationSeconds,
    );
    _messages.add(message);

    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final conversation = _conversations[index];
      final isFromClient = senderId == conversation.clientId;
      final preview = switch (attachmentType) {
        ChatAttachmentType.image => '📷 Photo',
        ChatAttachmentType.voice => '🎤 Message vocal',
        ChatAttachmentType.none =>
          productNameSnapshot != null ? '📦 $productNameSnapshot' : text,
      };
      _conversations[index] = conversation.copyWith(
        lastMessagePreview: preview,
        lastMessageAt: message.sentAt,
        unreadCountClient: isFromClient
            ? conversation.unreadCountClient
            : conversation.unreadCountClient + 1,
        unreadCountSupplier: isFromClient
            ? conversation.unreadCountSupplier + 1
            : conversation.unreadCountSupplier,
      );
    }
    _changesController.add(null);
  }

  String startOrGetConversation({
    required String clientId,
    required String clientDisplayNameSnapshot,
    required String supplierId,
    required String supplierName,
  }) {
    final existing = _conversations.where(
      (c) => c.clientId == clientId && c.supplierId == supplierId,
    );
    if (existing.isNotEmpty) return existing.first.id;

    final conversation = ChatConversation(
      id: IdGenerator.next(),
      clientId: clientId,
      clientDisplayNameSnapshot: clientDisplayNameSnapshot,
      supplierId: supplierId,
      supplierName: supplierName,
      lastMessagePreview: '',
      lastMessageAt: DateTime.now(),
      unreadCountClient: 0,
      unreadCountSupplier: 0,
    );
    _conversations.add(conversation);
    _changesController.add(null);
    return conversation.id;
  }

  void markConversationRead({
    required String conversationId,
    required ChatParticipant readBy,
  }) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    _conversations[index] = switch (readBy) {
      ChatParticipant.client => _conversations[index].copyWith(
        unreadCountClient: 0,
      ),
      ChatParticipant.supplier => _conversations[index].copyWith(
        unreadCountSupplier: 0,
      ),
    };

    for (var i = 0; i < _messages.length; i++) {
      if (_messages[i].conversationId == conversationId &&
          !_messages[i].isRead) {
        _messages[i] = _messages[i].copyWith(isRead: true);
      }
    }
    _changesController.add(null);
  }

  (List<ChatConversation>, List<ChatMessage>) _seed() {
    final now = DateTime.now();

    final conv1 = ChatConversation(
      id: 'conv-awa-bogolan',
      clientId: DemoIds.clientAwa,
      clientDisplayNameSnapshot: 'Awa Traoré',
      supplierId: DemoIds.supplierBogolanBamako,
      supplierName: 'Bogolan Bamako',
      lastMessagePreview: 'Oui, disponible en plusieurs coloris !',
      lastMessageAt: now.subtract(const Duration(hours: 2)),
      unreadCountClient: 1,
      unreadCountSupplier: 0,
    );
    final conv2 = ChatConversation(
      id: 'conv-moussa-mtc',
      clientId: DemoIds.clientMoussa,
      clientDisplayNameSnapshot: 'Moussa Diarra',
      supplierId: DemoIds.supplierMtcOfficiel,
      supplierName: 'MTC Officiel',
      lastMessagePreview: 'Bienvenue sur Mali Trade Connect !',
      lastMessageAt: now.subtract(const Duration(days: 1)),
      unreadCountClient: 0,
      unreadCountSupplier: 0,
    );

    final messages = [
      ChatMessage(
        id: 'msg-1',
        conversationId: conv1.id,
        senderId: DemoIds.clientAwa,
        text:
            'Bonjour, le tissu bogolan est-il disponible en plusieurs couleurs ?',
        sentAt: now.subtract(const Duration(hours: 3)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg-2',
        conversationId: conv1.id,
        senderId: DemoIds.supplierBogolanBamako,
        text: 'Oui, disponible en plusieurs coloris !',
        sentAt: now.subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      ChatMessage(
        id: 'msg-3',
        conversationId: conv2.id,
        senderId: DemoIds.supplierMtcOfficiel,
        text:
            'Bienvenue sur Mali Trade Connect ! Nous sommes là pour vous aider.',
        sentAt: now.subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];

    return ([conv1, conv2], messages);
  }
}
