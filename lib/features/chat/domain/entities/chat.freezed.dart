// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ChatConversation {
  String get id => throw _privateConstructorUsedError;
  String get clientId => throw _privateConstructorUsedError;
  String get supplierId => throw _privateConstructorUsedError;
  String get supplierName => throw _privateConstructorUsedError;
  String get lastMessagePreview => throw _privateConstructorUsedError;
  DateTime get lastMessageAt => throw _privateConstructorUsedError;
  int get unreadCount => throw _privateConstructorUsedError;

  /// Create a copy of ChatConversation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatConversationCopyWith<ChatConversation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatConversationCopyWith<$Res> {
  factory $ChatConversationCopyWith(
    ChatConversation value,
    $Res Function(ChatConversation) then,
  ) = _$ChatConversationCopyWithImpl<$Res, ChatConversation>;
  @useResult
  $Res call({
    String id,
    String clientId,
    String supplierId,
    String supplierName,
    String lastMessagePreview,
    DateTime lastMessageAt,
    int unreadCount,
  });
}

/// @nodoc
class _$ChatConversationCopyWithImpl<$Res, $Val extends ChatConversation>
    implements $ChatConversationCopyWith<$Res> {
  _$ChatConversationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatConversation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientId = null,
    Object? supplierId = null,
    Object? supplierName = null,
    Object? lastMessagePreview = null,
    Object? lastMessageAt = null,
    Object? unreadCount = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            clientId: null == clientId
                ? _value.clientId
                : clientId // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierId: null == supplierId
                ? _value.supplierId
                : supplierId // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierName: null == supplierName
                ? _value.supplierName
                : supplierName // ignore: cast_nullable_to_non_nullable
                      as String,
            lastMessagePreview: null == lastMessagePreview
                ? _value.lastMessagePreview
                : lastMessagePreview // ignore: cast_nullable_to_non_nullable
                      as String,
            lastMessageAt: null == lastMessageAt
                ? _value.lastMessageAt
                : lastMessageAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            unreadCount: null == unreadCount
                ? _value.unreadCount
                : unreadCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChatConversationImplCopyWith<$Res>
    implements $ChatConversationCopyWith<$Res> {
  factory _$$ChatConversationImplCopyWith(
    _$ChatConversationImpl value,
    $Res Function(_$ChatConversationImpl) then,
  ) = __$$ChatConversationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String clientId,
    String supplierId,
    String supplierName,
    String lastMessagePreview,
    DateTime lastMessageAt,
    int unreadCount,
  });
}

/// @nodoc
class __$$ChatConversationImplCopyWithImpl<$Res>
    extends _$ChatConversationCopyWithImpl<$Res, _$ChatConversationImpl>
    implements _$$ChatConversationImplCopyWith<$Res> {
  __$$ChatConversationImplCopyWithImpl(
    _$ChatConversationImpl _value,
    $Res Function(_$ChatConversationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChatConversation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientId = null,
    Object? supplierId = null,
    Object? supplierName = null,
    Object? lastMessagePreview = null,
    Object? lastMessageAt = null,
    Object? unreadCount = null,
  }) {
    return _then(
      _$ChatConversationImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        clientId: null == clientId
            ? _value.clientId
            : clientId // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierId: null == supplierId
            ? _value.supplierId
            : supplierId // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierName: null == supplierName
            ? _value.supplierName
            : supplierName // ignore: cast_nullable_to_non_nullable
                  as String,
        lastMessagePreview: null == lastMessagePreview
            ? _value.lastMessagePreview
            : lastMessagePreview // ignore: cast_nullable_to_non_nullable
                  as String,
        lastMessageAt: null == lastMessageAt
            ? _value.lastMessageAt
            : lastMessageAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        unreadCount: null == unreadCount
            ? _value.unreadCount
            : unreadCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$ChatConversationImpl implements _ChatConversation {
  const _$ChatConversationImpl({
    required this.id,
    required this.clientId,
    required this.supplierId,
    required this.supplierName,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  @override
  final String id;
  @override
  final String clientId;
  @override
  final String supplierId;
  @override
  final String supplierName;
  @override
  final String lastMessagePreview;
  @override
  final DateTime lastMessageAt;
  @override
  final int unreadCount;

  @override
  String toString() {
    return 'ChatConversation(id: $id, clientId: $clientId, supplierId: $supplierId, supplierName: $supplierName, lastMessagePreview: $lastMessagePreview, lastMessageAt: $lastMessageAt, unreadCount: $unreadCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatConversationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientId, clientId) ||
                other.clientId == clientId) &&
            (identical(other.supplierId, supplierId) ||
                other.supplierId == supplierId) &&
            (identical(other.supplierName, supplierName) ||
                other.supplierName == supplierName) &&
            (identical(other.lastMessagePreview, lastMessagePreview) ||
                other.lastMessagePreview == lastMessagePreview) &&
            (identical(other.lastMessageAt, lastMessageAt) ||
                other.lastMessageAt == lastMessageAt) &&
            (identical(other.unreadCount, unreadCount) ||
                other.unreadCount == unreadCount));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    clientId,
    supplierId,
    supplierName,
    lastMessagePreview,
    lastMessageAt,
    unreadCount,
  );

  /// Create a copy of ChatConversation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatConversationImplCopyWith<_$ChatConversationImpl> get copyWith =>
      __$$ChatConversationImplCopyWithImpl<_$ChatConversationImpl>(
        this,
        _$identity,
      );
}

abstract class _ChatConversation implements ChatConversation {
  const factory _ChatConversation({
    required final String id,
    required final String clientId,
    required final String supplierId,
    required final String supplierName,
    required final String lastMessagePreview,
    required final DateTime lastMessageAt,
    required final int unreadCount,
  }) = _$ChatConversationImpl;

  @override
  String get id;
  @override
  String get clientId;
  @override
  String get supplierId;
  @override
  String get supplierName;
  @override
  String get lastMessagePreview;
  @override
  DateTime get lastMessageAt;
  @override
  int get unreadCount;

  /// Create a copy of ChatConversation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatConversationImplCopyWith<_$ChatConversationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ChatMessage {
  String get id => throw _privateConstructorUsedError;
  String get conversationId => throw _privateConstructorUsedError;
  String get senderId => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  DateTime get sentAt => throw _privateConstructorUsedError;
  bool get isRead => throw _privateConstructorUsedError;

  /// Snapshot of the product this message is asking about, if the client
  /// started the conversation from a product page — denormalized (rather
  /// than just a `productId` lookup) so the supplier still sees exactly
  /// what was asked about even if the product's price/photo/name changes
  /// or the listing is later removed.
  String? get productId => throw _privateConstructorUsedError;
  String? get productNameSnapshot => throw _privateConstructorUsedError;
  String? get productImageSnapshot => throw _privateConstructorUsedError;
  int? get productPriceFcfaSnapshot => throw _privateConstructorUsedError;

  /// Local file path for an image or voice-note attachment. There's no
  /// real upload backend (this whole app is an in-memory mock), so the
  /// path only stays valid for the current session — same lifetime as
  /// everything else the mock repositories hold.
  ChatAttachmentType get attachmentType => throw _privateConstructorUsedError;
  String? get attachmentPath => throw _privateConstructorUsedError;

  /// Set only for [ChatAttachmentType.voice] — lets the bubble show a
  /// duration immediately without having to probe the audio file.
  int? get voiceDurationSeconds => throw _privateConstructorUsedError;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatMessageCopyWith<ChatMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatMessageCopyWith<$Res> {
  factory $ChatMessageCopyWith(
    ChatMessage value,
    $Res Function(ChatMessage) then,
  ) = _$ChatMessageCopyWithImpl<$Res, ChatMessage>;
  @useResult
  $Res call({
    String id,
    String conversationId,
    String senderId,
    String text,
    DateTime sentAt,
    bool isRead,
    String? productId,
    String? productNameSnapshot,
    String? productImageSnapshot,
    int? productPriceFcfaSnapshot,
    ChatAttachmentType attachmentType,
    String? attachmentPath,
    int? voiceDurationSeconds,
  });
}

/// @nodoc
class _$ChatMessageCopyWithImpl<$Res, $Val extends ChatMessage>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? conversationId = null,
    Object? senderId = null,
    Object? text = null,
    Object? sentAt = null,
    Object? isRead = null,
    Object? productId = freezed,
    Object? productNameSnapshot = freezed,
    Object? productImageSnapshot = freezed,
    Object? productPriceFcfaSnapshot = freezed,
    Object? attachmentType = null,
    Object? attachmentPath = freezed,
    Object? voiceDurationSeconds = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            conversationId: null == conversationId
                ? _value.conversationId
                : conversationId // ignore: cast_nullable_to_non_nullable
                      as String,
            senderId: null == senderId
                ? _value.senderId
                : senderId // ignore: cast_nullable_to_non_nullable
                      as String,
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            sentAt: null == sentAt
                ? _value.sentAt
                : sentAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            isRead: null == isRead
                ? _value.isRead
                : isRead // ignore: cast_nullable_to_non_nullable
                      as bool,
            productId: freezed == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String?,
            productNameSnapshot: freezed == productNameSnapshot
                ? _value.productNameSnapshot
                : productNameSnapshot // ignore: cast_nullable_to_non_nullable
                      as String?,
            productImageSnapshot: freezed == productImageSnapshot
                ? _value.productImageSnapshot
                : productImageSnapshot // ignore: cast_nullable_to_non_nullable
                      as String?,
            productPriceFcfaSnapshot: freezed == productPriceFcfaSnapshot
                ? _value.productPriceFcfaSnapshot
                : productPriceFcfaSnapshot // ignore: cast_nullable_to_non_nullable
                      as int?,
            attachmentType: null == attachmentType
                ? _value.attachmentType
                : attachmentType // ignore: cast_nullable_to_non_nullable
                      as ChatAttachmentType,
            attachmentPath: freezed == attachmentPath
                ? _value.attachmentPath
                : attachmentPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            voiceDurationSeconds: freezed == voiceDurationSeconds
                ? _value.voiceDurationSeconds
                : voiceDurationSeconds // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChatMessageImplCopyWith<$Res>
    implements $ChatMessageCopyWith<$Res> {
  factory _$$ChatMessageImplCopyWith(
    _$ChatMessageImpl value,
    $Res Function(_$ChatMessageImpl) then,
  ) = __$$ChatMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String conversationId,
    String senderId,
    String text,
    DateTime sentAt,
    bool isRead,
    String? productId,
    String? productNameSnapshot,
    String? productImageSnapshot,
    int? productPriceFcfaSnapshot,
    ChatAttachmentType attachmentType,
    String? attachmentPath,
    int? voiceDurationSeconds,
  });
}

/// @nodoc
class __$$ChatMessageImplCopyWithImpl<$Res>
    extends _$ChatMessageCopyWithImpl<$Res, _$ChatMessageImpl>
    implements _$$ChatMessageImplCopyWith<$Res> {
  __$$ChatMessageImplCopyWithImpl(
    _$ChatMessageImpl _value,
    $Res Function(_$ChatMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? conversationId = null,
    Object? senderId = null,
    Object? text = null,
    Object? sentAt = null,
    Object? isRead = null,
    Object? productId = freezed,
    Object? productNameSnapshot = freezed,
    Object? productImageSnapshot = freezed,
    Object? productPriceFcfaSnapshot = freezed,
    Object? attachmentType = null,
    Object? attachmentPath = freezed,
    Object? voiceDurationSeconds = freezed,
  }) {
    return _then(
      _$ChatMessageImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        conversationId: null == conversationId
            ? _value.conversationId
            : conversationId // ignore: cast_nullable_to_non_nullable
                  as String,
        senderId: null == senderId
            ? _value.senderId
            : senderId // ignore: cast_nullable_to_non_nullable
                  as String,
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        sentAt: null == sentAt
            ? _value.sentAt
            : sentAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        isRead: null == isRead
            ? _value.isRead
            : isRead // ignore: cast_nullable_to_non_nullable
                  as bool,
        productId: freezed == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String?,
        productNameSnapshot: freezed == productNameSnapshot
            ? _value.productNameSnapshot
            : productNameSnapshot // ignore: cast_nullable_to_non_nullable
                  as String?,
        productImageSnapshot: freezed == productImageSnapshot
            ? _value.productImageSnapshot
            : productImageSnapshot // ignore: cast_nullable_to_non_nullable
                  as String?,
        productPriceFcfaSnapshot: freezed == productPriceFcfaSnapshot
            ? _value.productPriceFcfaSnapshot
            : productPriceFcfaSnapshot // ignore: cast_nullable_to_non_nullable
                  as int?,
        attachmentType: null == attachmentType
            ? _value.attachmentType
            : attachmentType // ignore: cast_nullable_to_non_nullable
                  as ChatAttachmentType,
        attachmentPath: freezed == attachmentPath
            ? _value.attachmentPath
            : attachmentPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        voiceDurationSeconds: freezed == voiceDurationSeconds
            ? _value.voiceDurationSeconds
            : voiceDurationSeconds // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc

class _$ChatMessageImpl implements _ChatMessage {
  const _$ChatMessageImpl({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    required this.isRead,
    this.productId,
    this.productNameSnapshot,
    this.productImageSnapshot,
    this.productPriceFcfaSnapshot,
    this.attachmentType = ChatAttachmentType.none,
    this.attachmentPath,
    this.voiceDurationSeconds,
  });

  @override
  final String id;
  @override
  final String conversationId;
  @override
  final String senderId;
  @override
  final String text;
  @override
  final DateTime sentAt;
  @override
  final bool isRead;

  /// Snapshot of the product this message is asking about, if the client
  /// started the conversation from a product page — denormalized (rather
  /// than just a `productId` lookup) so the supplier still sees exactly
  /// what was asked about even if the product's price/photo/name changes
  /// or the listing is later removed.
  @override
  final String? productId;
  @override
  final String? productNameSnapshot;
  @override
  final String? productImageSnapshot;
  @override
  final int? productPriceFcfaSnapshot;

  /// Local file path for an image or voice-note attachment. There's no
  /// real upload backend (this whole app is an in-memory mock), so the
  /// path only stays valid for the current session — same lifetime as
  /// everything else the mock repositories hold.
  @override
  @JsonKey()
  final ChatAttachmentType attachmentType;
  @override
  final String? attachmentPath;

  /// Set only for [ChatAttachmentType.voice] — lets the bubble show a
  /// duration immediately without having to probe the audio file.
  @override
  final int? voiceDurationSeconds;

  @override
  String toString() {
    return 'ChatMessage(id: $id, conversationId: $conversationId, senderId: $senderId, text: $text, sentAt: $sentAt, isRead: $isRead, productId: $productId, productNameSnapshot: $productNameSnapshot, productImageSnapshot: $productImageSnapshot, productPriceFcfaSnapshot: $productPriceFcfaSnapshot, attachmentType: $attachmentType, attachmentPath: $attachmentPath, voiceDurationSeconds: $voiceDurationSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.sentAt, sentAt) || other.sentAt == sentAt) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.productNameSnapshot, productNameSnapshot) ||
                other.productNameSnapshot == productNameSnapshot) &&
            (identical(other.productImageSnapshot, productImageSnapshot) ||
                other.productImageSnapshot == productImageSnapshot) &&
            (identical(
                  other.productPriceFcfaSnapshot,
                  productPriceFcfaSnapshot,
                ) ||
                other.productPriceFcfaSnapshot == productPriceFcfaSnapshot) &&
            (identical(other.attachmentType, attachmentType) ||
                other.attachmentType == attachmentType) &&
            (identical(other.attachmentPath, attachmentPath) ||
                other.attachmentPath == attachmentPath) &&
            (identical(other.voiceDurationSeconds, voiceDurationSeconds) ||
                other.voiceDurationSeconds == voiceDurationSeconds));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    conversationId,
    senderId,
    text,
    sentAt,
    isRead,
    productId,
    productNameSnapshot,
    productImageSnapshot,
    productPriceFcfaSnapshot,
    attachmentType,
    attachmentPath,
    voiceDurationSeconds,
  );

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      __$$ChatMessageImplCopyWithImpl<_$ChatMessageImpl>(this, _$identity);
}

abstract class _ChatMessage implements ChatMessage {
  const factory _ChatMessage({
    required final String id,
    required final String conversationId,
    required final String senderId,
    required final String text,
    required final DateTime sentAt,
    required final bool isRead,
    final String? productId,
    final String? productNameSnapshot,
    final String? productImageSnapshot,
    final int? productPriceFcfaSnapshot,
    final ChatAttachmentType attachmentType,
    final String? attachmentPath,
    final int? voiceDurationSeconds,
  }) = _$ChatMessageImpl;

  @override
  String get id;
  @override
  String get conversationId;
  @override
  String get senderId;
  @override
  String get text;
  @override
  DateTime get sentAt;
  @override
  bool get isRead;

  /// Snapshot of the product this message is asking about, if the client
  /// started the conversation from a product page — denormalized (rather
  /// than just a `productId` lookup) so the supplier still sees exactly
  /// what was asked about even if the product's price/photo/name changes
  /// or the listing is later removed.
  @override
  String? get productId;
  @override
  String? get productNameSnapshot;
  @override
  String? get productImageSnapshot;
  @override
  int? get productPriceFcfaSnapshot;

  /// Local file path for an image or voice-note attachment. There's no
  /// real upload backend (this whole app is an in-memory mock), so the
  /// path only stays valid for the current session — same lifetime as
  /// everything else the mock repositories hold.
  @override
  ChatAttachmentType get attachmentType;
  @override
  String? get attachmentPath;

  /// Set only for [ChatAttachmentType.voice] — lets the bubble show a
  /// duration immediately without having to probe the audio file.
  @override
  int? get voiceDurationSeconds;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
