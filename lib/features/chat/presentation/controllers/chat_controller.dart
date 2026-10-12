import 'package:flutter/foundation.dart';
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
  ///
  /// The message itself is already sent by the time `sendMessage` calls
  /// this — swallowing failures here (recipient lookup or the notification
  /// write) keeps a delivery hiccup from surfacing as a failed send.
  Future<void> _notifyRecipient({
    required String conversationId,
    required String senderId,
    required String preview,
  }) async {
    try {
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
    } catch (e) {
      debugPrint('ChatController._notifyRecipient failed (ignored): $e');
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? productId,
    String? productNameSnapshot,
    String? productImageSnapshot,
    int? productPriceFcfaSnapshot,
    String? productVariantId,
    String? productVariantNameSnapshot,
  }) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    // Empty text is only a no-op when there's nothing else on the message —
    // a tagged product with no comment (`ChatComposer.hasPendingAttachment`
    // lets that reach here with `text` empty) is a real send, same as
    // `sendImage`/`sendVoiceNote` already allow with their own content.
    if (userId == null || (text.trim().isEmpty && productId == null)) return;
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
          productVariantId: productVariantId,
          productVariantNameSnapshot: productVariantNameSnapshot,
        );
    final trimmed = text.trim();
    await _notifyRecipient(
      conversationId: conversationId,
      senderId: userId,
      preview: trimmed.isNotEmpty ? trimmed : '📦 $productNameSnapshot',
    );
  }

  Future<void> sendImage({
    required String conversationId,
    required XFile image,
    String? productId,
    String? productNameSnapshot,
    String? productImageSnapshot,
    int? productPriceFcfaSnapshot,
    String? productVariantId,
    String? productVariantNameSnapshot,
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
          productVariantId: productVariantId,
          productVariantNameSnapshot: productVariantNameSnapshot,
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
    String? productVariantId,
    String? productVariantNameSnapshot,
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
          productVariantId: productVariantId,
          productVariantNameSnapshot: productVariantNameSnapshot,
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
  /// clears `unreadCountSupplier`; the caller never has to know which. Also
  /// clears any `newMessage` notification already sent for this
  /// conversation, so a message that arrives while its thread is open never
  /// surfaces as an unread badge anywhere — `ChatThreadScreen` calls this
  /// both on mount and again every time a new message streams in while it
  /// stays open, not just once.
  Future<void> markRead(String conversationId) async {
    // `await ...future` et non `.valueOrNull` : pendant qu'un changement de
    // compte est en cours, Riverpod conserve la **valeur précédente** le
    // temps que la nouvelle arrive. Lue telle quelle, elle faisait marquer
    // comme lu le mauvais côté de la conversation — le client au lieu du
    // fournisseur — sans la moindre erreur, le serveur n'ayant rien à
    // redire à une mise à jour parfaitement valide sur l'autre compteur.
    //
    // Se produit chaque fois qu'une action suit de près une connexion :
    // notification ouverte au lancement de l'app, bascule entre deux comptes
    // sur le même téléphone. Rare, silencieux, et le compteur de non-lus
    // restait allumé sans qu'on sache pourquoi.
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    final readBy = user is ClientUser
        ? ChatParticipant.client
        : ChatParticipant.supplier;
    await ref
        .read(chatRepositoryProvider)
        .markConversationRead(conversationId: conversationId, readBy: readBy);
    await ref
        .read(notificationRepositoryProvider)
        .markReadByReference(userId: user.id, referenceId: conversationId);
  }
}

final chatControllerProvider = AsyncNotifierProvider<ChatController, void>(
  ChatController.new,
);
