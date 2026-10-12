import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/id_generator.dart';

/// Raw `reviews` I/O — no `Review` entity knowledge here. No Realtime (out
/// of scope, same "notify after my own write" shape as Lot 4's
/// datasources).
class SupabaseReviewDatasource {
  SupabaseReviewDatasource(this._client);

  final SupabaseClient _client;

  final _changes = StreamController<void>.broadcast();

  Stream<T> _watch<T>(Future<T> Function() fetch) {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changes.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).asyncMap((_) => fetch());
  }

  void _notify() => _changes.add(null);

  Stream<List<Map<String, dynamic>>> watchForSupplier(String supplierId) {
    return _watch(
      () => _client
          .from('reviews')
          .select()
          .eq('supplier_id', supplierId)
          .order('created_at', ascending: false),
    );
  }

  Future<void> submitReview(Map<String, dynamic> row) async {
    await _client.from('reviews').insert({'id': IdGenerator.next(), ...row});
    _notify();
  }

  Future<bool> hasReview({
    required String orderId,
    required String supplierGroupId,
  }) async {
    final existing = await _client
        .from('reviews')
        .select('id')
        .eq('order_id', orderId)
        .eq('supplier_group_id', supplierGroupId)
        .maybeSingle();
    return existing != null;
  }

  Future<Map<String, dynamic>?> getById(String reviewId) {
    return _client.from('reviews').select().eq('id', reviewId).maybeSingle();
  }

  Future<void> reply({
    required String reviewId,
    required String reply,
  }) async {
    await _client
        .from('reviews')
        .update({
          'supplier_reply': reply,
          'supplier_replied_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reviewId);
    _notify();
  }

  /// Avis des acheteurs d'un produit, commentaires compris
  /// (`fetch_product_reviews`, `0061`).
  ///
  /// Une RPC et non un `select` : le rattachement d'un avis à un produit
  /// passe par `order_items`, que ni un visiteur sans compte ni un autre
  /// client ne peut lire. La fonction est `security definer` et ne renvoie
  /// rien de la commande elle-même.
  Future<List<Map<String, dynamic>>> fetchProductReviews({
    required String productId,
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'fetch_product_reviews',
      params: {
        'p_product_id': productId,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>?> fetchProductReviewSummary(
    String productId,
  ) async {
    final rows = await _client.rpc(
      'fetch_product_review_summary',
      params: {'p_product_id': productId},
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.isEmpty ? null : list.first;
  }

  /// Commente un avis.
  ///
  /// `author_id` n'est pas transmis : un trigger le pose depuis
  /// `auth.uid()`, avec le nom affiché et le fait que l'auteur soit ou non
  /// le vendeur (`stamp_review_comment_author`, `0061`). L'envoyer d'ici
  /// laisserait croire que l'app décide de qui signe.
  Future<void> addComment({
    required String reviewId,
    required String body,
    List<String> imagePaths = const [],
    String? videoPath,
  }) async {
    await _client.from('review_comments').insert({
      'review_id': reviewId,
      'body': body,
      'image_paths': imagePaths,
      'video_path': videoPath,
    });
    _notify();
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('review_comments').delete().eq('id', commentId);
    _notify();
  }
}
