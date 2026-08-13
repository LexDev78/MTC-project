import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../data/datasources/in_memory_chat_datasource.dart';
import '../../data/repositories/in_memory_chat_repository.dart';
import '../../domain/entities/chat.dart';
import '../../domain/repositories/chat_repository.dart';

final chatDatasourceProvider = Provider<InMemoryChatDatasource>((ref) {
  return InMemoryChatDatasource();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return InMemoryChatRepository(ref.watch(chatDatasourceProvider));
});

final conversationsProvider = StreamProvider<List<ChatConversation>>((ref) {
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (userId == null) return Stream.value(const <ChatConversation>[]);
  return ref.watch(chatRepositoryProvider).watchConversationsForUser(userId);
});

final supplierConversationsProvider =
    StreamProvider.family<List<ChatConversation>, String>((ref, supplierId) {
      return ref
          .watch(chatRepositoryProvider)
          .watchConversationsForSupplier(supplierId);
    });

final messagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});

/// Looks up a single conversation by id, from whichever side's list
/// (client or operating supplier) the current user belongs to — lets
/// `ChatThreadScreen` stay a single screen shared by both roles.
final conversationProvider = Provider.family<ChatConversation?, String>((
  ref,
  conversationId,
) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final List<ChatConversation> conversations;
  if (user is ClientUser) {
    conversations = ref.watch(conversationsProvider).valueOrNull ?? const [];
  } else {
    final supplierId = ref.watch(operatingSupplierIdProvider);
    conversations = supplierId == null
        ? const []
        : ref.watch(supplierConversationsProvider(supplierId)).valueOrNull ??
              const [];
  }
  for (final c in conversations) {
    if (c.id == conversationId) return c;
  }
  return null;
});

final totalUnreadCountProvider = Provider<int>((ref) {
  final conversations =
      ref.watch(conversationsProvider).valueOrNull ?? const [];
  return conversations.fold<int>(0, (sum, c) => sum + c.unreadCountClient);
});
