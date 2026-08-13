import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';

import '../../domain/entities/product_comment.dart';
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
      final product = await ref.read(productRepositoryProvider).getById(productId);
      await ref
          .read(productCommentRepositoryProvider)
          .addComment(
            productId: productId,
            supplierId: product.supplierId,
            authorId: user.id,
            authorName: user.displayName,
            isSupplier: user.role != UserRole.client,
            text: trimmed,
            parentId: parentId,
          );
    });

    return !state.hasError;
  }

  Future<bool> addImageComment({
    required String productId,
    required String imagePath,
    String? parentId,
  }) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final product = await ref.read(productRepositoryProvider).getById(productId);
      await ref
          .read(productCommentRepositoryProvider)
          .addComment(
            productId: productId,
            supplierId: product.supplierId,
            authorId: user.id,
            authorName: user.displayName,
            isSupplier: user.role != UserRole.client,
            text: '',
            parentId: parentId,
            attachmentType: CommentAttachmentType.image,
            attachmentPath: imagePath,
          );
    });

    return !state.hasError;
  }

  Future<bool> addVoiceComment({
    required String productId,
    required String voicePath,
    required int durationSeconds,
    String? parentId,
  }) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final product = await ref.read(productRepositoryProvider).getById(productId);
      await ref
          .read(productCommentRepositoryProvider)
          .addComment(
            productId: productId,
            supplierId: product.supplierId,
            authorId: user.id,
            authorName: user.displayName,
            isSupplier: user.role != UserRole.client,
            text: '',
            parentId: parentId,
            attachmentType: CommentAttachmentType.voice,
            attachmentPath: voicePath,
            voiceDurationSeconds: durationSeconds,
          );
    });

    return !state.hasError;
  }

  Future<void> toggleLike(String commentId) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;
    await ref
        .read(productCommentRepositoryProvider)
        .toggleLike(commentId: commentId, userId: userId);
  }
}

final commentControllerProvider = AsyncNotifierProvider<CommentController, void>(
  CommentController.new,
);
