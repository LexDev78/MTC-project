import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/storage/image_upload.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';

import '../../domain/entities/chat.dart';
import '../providers/chat_providers.dart';

class ChatController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Notifies whichever side didn't just send the message — resolves the
  /// conversation fresh via `ChatRepository.getConversationById` rather
  /// than trusting a presentation-layer provider to already be warm.
  Future<void> _notifyRecipient({
    required String conversationId,
    required String senderId,
    required String preview,
  }) async {
    final conversation = await ref
        .read(chatRepositoryProvider)
        .getConversationById(conversationId);
    final recipientId = senderId == conversation.clientId
        ? conversation.supplierId
        : conversation.clientId;
    await ref
        .read(notificationRepositoryProvider)
        .add(
          userId: recipientId,
          type: NotificationType.newMessage,
          title: 'Nouveau message',
          body: preview,
          referenceId: conversationId,
        );
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? productId,
    String? productNameSnapshot,
    String? productImageSnapshot,
    int? productPriceFcfaSnapshot,
  }) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null || text.trim().isEmpty) return;
    await ref
        .read(chatRepositoryProvider)
        .sendMessage(
          conversationId: conversationId,
          senderId: userId,
          text: text.trim(),
          productId: productId,
          productNameSnapshot: productNameSnapshot,
          productImageSnapshot: productImageSnapshot,
          productPriceFcfaSnapshot: productPriceFcfaSnapshot,
        );
    await _notifyRecipient(
      conversationId: conversationId,
      senderId: userId,
      preview: text.trim(),
    );
  }

  Future<void> sendImage({
    required String conversationId,
    required XFile image,
    String? productId,
    String? productNameSnapshot,
    String? productImageSnapshot,
    int? productPriceFcfaSnapshot,
  }) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;
    final path = await uploadPickedImage(
      client: ref.read(supabaseClientProvider),
      bucket: 'chat-attachments',
      folder: conversationId,
      file: image,
    );
    await ref
        .read(chatRepositoryProvider)
        .sendMessage(
          conversationId: conversationId,
          senderId: userId,
          text: '',
          attachmentType: ChatAttachmentType.image,
          attachmentPath: path,
          productId: productId,
          productNameSnapshot: productNameSnapshot,
          productImageSnapshot: productImageSnapshot,
          productPriceFcfaSnapshot: productPriceFcfaSnapshot,
        );
    await _notifyRecipient(
      conversationId: conversationId,
      senderId: userId,
      preview: '📷 Photo',
    );
  }

  /// Sends a voice note — carries the same pending-product snapshot as a
  /// written message when the client asked about a product (see
  /// `ChatThreadScreen._pendingProduct`), so the supplier sees exactly what
  /// the voice note is about regardless of which input method was used.
  Future<void> sendVoiceNote({
    required String conversationId,
    required String voicePath,
    required int durationSeconds,
    String? productId,
    String? productNameSnapshot,
    String? productImageSnapshot,
    int? productPriceFcfaSnapshot,
  }) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;
    final path = await uploadPickedImage(
      client: ref.read(supabaseClientProvider),
      bucket: 'chat-attachments',
      folder: conversationId,
      file: XFile(voicePath),
      contentType: 'audio/mp4',
    );
    await ref
        .read(chatRepositoryProvider)
        .sendMessage(
          conversationId: conversationId,
          senderId: userId,
          text: '',
          attachmentType: ChatAttachmentType.voice,
          attachmentPath: path,
          voiceDurationSeconds: durationSeconds,
          productId: productId,
          productNameSnapshot: productNameSnapshot,
          productImageSnapshot: productImageSnapshot,
          productPriceFcfaSnapshot: productPriceFcfaSnapshot,
        );
    await _notifyRecipient(
      conversationId: conversationId,
      senderId: userId,
      preview: '🎤 Message vocal',
    );
  }

  /// Starts (or resumes) a conversation with a supplier. Returns the
  /// conversation ID to navigate to, or `null` if not signed in as a client.
  Future<String?> startConversationWithSupplier({
    required String supplierId,
    required String supplierName,
  }) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user is! ClientUser) return null;
    return ref
        .read(chatRepositoryProvider)
        .startOrGetConversation(
          clientId: user.id,
          clientDisplayNameSnapshot: user.displayName,
          supplierId: supplierId,
          supplierName: supplierName,
        );
  }

  /// Marks the conversation read on behalf of the current user's own side
  /// — a client reading clears `unreadCountClient`, a supplier reading
  /// clears `unreadCountSupplier`; the caller never has to know which.
  Future<void> markRead(String conversationId) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final readBy = user is ClientUser
        ? ChatParticipant.client
        : ChatParticipant.supplier;
    await ref
        .read(chatRepositoryProvider)
        .markConversationRead(conversationId: conversationId, readBy: readBy);
  }
}

final chatControllerProvider = AsyncNotifierProvider<ChatController, void>(
  ChatController.new,
);
