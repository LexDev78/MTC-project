import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/presentation/providers/supplier_product_providers.dart';

import '../../domain/entities/product_comment.dart';
import 'comment_providers.dart';

/// One top-level comment plus its replies, resolved against the product it
/// was left on — a presentation-layer projection (like `SupplierOrderView`)
/// rather than a repository join, since it combines two features'
/// repositories (`ProductCommentRepository` + `ProductRepository`).
class SupplierCommentInboxItem {
  const SupplierCommentInboxItem({
    required this.comment,
    required this.replies,
    required this.productName,
  });

  final ProductComment comment;
  final List<ProductComment> replies;
  final String productName;

  bool get hasSupplierReply => replies.any((r) => r.isSupplier);
}

/// Every top-level comment across [supplierId]'s products, newest first,
/// each paired with its replies and the name of the product it's about.
final supplierCommentInboxProvider =
    Provider.family<AsyncValue<List<SupplierCommentInboxItem>>, String>((
      ref,
      supplierId,
    ) {
      final commentsAsync = ref.watch(supplierProductCommentsProvider(supplierId));
      final productsAsync = ref.watch(myProductsProvider(supplierId));

      if (commentsAsync.isLoading || productsAsync.isLoading) {
        return const AsyncLoading();
      }
      if (commentsAsync.hasError) {
        return AsyncError(commentsAsync.error!, commentsAsync.stackTrace!);
      }
      if (productsAsync.hasError) {
        return AsyncError(productsAsync.error!, productsAsync.stackTrace!);
      }

      final comments = commentsAsync.value ?? const <ProductComment>[];
      final products = productsAsync.value ?? const <Product>[];
      final productNameById = <String, String>{
        for (final p in products) p.id: p.name,
      };

      final topLevel = comments.where((c) => !c.isReply).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return AsyncData([
        for (final comment in topLevel)
          SupplierCommentInboxItem(
            comment: comment,
            replies: comments.where((c) => c.parentId == comment.id).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
            productName: productNameById[comment.productId] ?? 'Produit',
          ),
      ]);
    });
