import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/storage/image_upload.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

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

  /// Folder Storage RLS expects for this author (`comment_attachments_
  /// author_write`) — the client's own id, or the operating supplier's id
  /// when a staff/tiers account is replying as the shop.
  String? _attachmentFolder(AppUser user) {
    return user.role == UserRole.client ? user.id : ref.read(operatingSupplierIdProvider);
  }

  Future<bool> addImageComment({
    required String productId,
    required XFile image,
    String? parentId,
  }) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    final folder = user == null ? null : _attachmentFolder(user);
    if (user == null || folder == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final product = await ref.read(productRepositoryProvider).getById(productId);
      final path = await uploadPickedImage(
        client: ref.read(supabaseClientProvider),
        bucket: 'comment-attachments',
        folder: folder,
        file: image,
      );
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
            attachmentPath: path,
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
    final folder = user == null ? null : _attachmentFolder(user);
    if (user == null || folder == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final product = await ref.read(productRepositoryProvider).getById(productId);
      final path = await uploadPickedImage(
        client: ref.read(supabaseClientProvider),
        bucket: 'comment-attachments',
        folder: folder,
        file: XFile(voicePath),
        contentType: 'audio/mp4',
      );
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
            attachmentPath: path,
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
