import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/chat.dart';
import '../providers/chat_providers.dart';

class ChatController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

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
  }

  Future<void> sendImage({
    required String conversationId,
    required String imagePath,
    String? productId,
    String? productNameSnapshot,
    String? productImageSnapshot,
    int? productPriceFcfaSnapshot,
  }) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;
    await ref
        .read(chatRepositoryProvider)
        .sendMessage(
          conversationId: conversationId,
          senderId: userId,
          text: '',
          attachmentType: ChatAttachmentType.image,
          attachmentPath: imagePath,
          productId: productId,
          productNameSnapshot: productNameSnapshot,
          productImageSnapshot: productImageSnapshot,
          productPriceFcfaSnapshot: productPriceFcfaSnapshot,
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
    await ref
        .read(chatRepositoryProvider)
        .sendMessage(
          conversationId: conversationId,
          senderId: userId,
          text: '',
          attachmentType: ChatAttachmentType.voice,
          attachmentPath: voicePath,
          voiceDurationSeconds: durationSeconds,
          productId: productId,
          productNameSnapshot: productNameSnapshot,
          productImageSnapshot: productImageSnapshot,
          productPriceFcfaSnapshot: productPriceFcfaSnapshot,
        );
  }

  /// Starts (or resumes) a conversation with a supplier. Returns the
  /// conversation ID to navigate to, or `null` if not signed in as a client.
  Future<String?> startConversationWithSupplier({
    required String supplierId,
    required String supplierName,
  }) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return null;
    return ref
        .read(chatRepositoryProvider)
        .startOrGetConversation(
          clientId: userId,
          supplierId: supplierId,
          supplierName: supplierName,
        );
  }

  Future<void> markRead(String conversationId) async {
    await ref.read(chatRepositoryProvider).markConversationRead(conversationId);
  }
}

final chatControllerProvider = AsyncNotifierProvider<ChatController, void>(
  ChatController.new,
);
