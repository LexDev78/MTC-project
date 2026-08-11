import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';

/// What a [ChatMessage] carries beyond (or instead of) plain text.
enum ChatAttachmentType { none, image, voice }

@freezed
class ChatConversation with _$ChatConversation {
  const factory ChatConversation({
    required String id,
    required String clientId,
    required String supplierId,
    required String supplierName,
    required String lastMessagePreview,
    required DateTime lastMessageAt,
    required int unreadCount,
  }) = _ChatConversation;
}

@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String conversationId,
    required String senderId,
    required String text,
    required DateTime sentAt,
    required bool isRead,

    /// Snapshot of the product this message is asking about, if the client
    /// started the conversation from a product page — denormalized (rather
    /// than just a `productId` lookup) so the supplier still sees exactly
    /// what was asked about even if the product's price/photo/name changes
    /// or the listing is later removed.
    String? productId,
    String? productNameSnapshot,
    String? productImageSnapshot,
    int? productPriceFcfaSnapshot,

    /// Local file path for an image or voice-note attachment. There's no
    /// real upload backend (this whole app is an in-memory mock), so the
    /// path only stays valid for the current session — same lifetime as
    /// everything else the mock repositories hold.
    @Default(ChatAttachmentType.none) ChatAttachmentType attachmentType,
    String? attachmentPath,

    /// Set only for [ChatAttachmentType.voice] — lets the bubble show a
    /// duration immediately without having to probe the audio file.
    int? voiceDurationSeconds,
  }) = _ChatMessage;
}
