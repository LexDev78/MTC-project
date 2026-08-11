import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

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

final messagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});

final conversationProvider = Provider.family<ChatConversation?, String>((
  ref,
  conversationId,
) {
  final conversations =
      ref.watch(conversationsProvider).valueOrNull ?? const [];
  for (final c in conversations) {
    if (c.id == conversationId) return c;
  }
  return null;
});

final totalUnreadCountProvider = Provider<int>((ref) {
  final conversations =
      ref.watch(conversationsProvider).valueOrNull ?? const [];
  return conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
});
