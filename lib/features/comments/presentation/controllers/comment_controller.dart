import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../providers/comment_providers.dart';

class CommentController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> addComment({
    required String productId,
    required String text,
    String? parentId,
  }) async {
    final trimmed = text.trim();
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || trimmed.isEmpty) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(productCommentRepositoryProvider)
          .addComment(
            productId: productId,
            authorId: user.id,
            authorName: user.displayName,
            isSupplier: user.role != UserRole.client,
            text: trimmed,
            parentId: parentId,
          );
    });

    return !state.hasError;
  }
}

final commentControllerProvider = AsyncNotifierProvider<CommentController, void>(
  CommentController.new,
);
