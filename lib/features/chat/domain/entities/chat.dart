import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

/// What a [ChatMessage] carries beyond (or instead of) plain text.
enum ChatAttachmentType { none, image, voice }

/// Which side of a [ChatConversation] is reading/unread-tracked — a
/// conversation has two independent unread counters (see
/// `unreadCountClient`/`unreadCountSupplier`) since either party can have
/// unread messages from the other at the same time.
enum ChatParticipant { client, supplier }

@freezed
class ChatConversation with _$ChatConversation {
  const ChatConversation._();

  const factory ChatConversation({
    required String id,
    required String clientId,

    /// Denormalized like `Order.clientDisplayNameSnapshot` — lets the
    /// supplier's conversation list/thread show who they're talking to
    /// without a live join back to the client's account.
    required String clientDisplayNameSnapshot,
    required String supplierId,
    required String supplierName,
    required String lastMessagePreview,
    required DateTime lastMessageAt,
    required int unreadCountClient,
    required int unreadCountSupplier,

    /// Posée quand le client ferme la conversation (`0122`) : la boutique ne
    /// peut plus lui écrire. Il la rouvre en écrivant, ou d'un geste.
    DateTime? closedAt,
  }) = _ChatConversation;

  bool get isClosed => closedAt != null;

  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      _$ChatConversationFromJson(json);
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

    /// Which variant the message is about, if any — same "denormalized so
    /// it survives the product/variant changing later" reasoning as the 4
    /// fields above.
    String? productVariantId,
    String? productVariantNameSnapshot,

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

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}
