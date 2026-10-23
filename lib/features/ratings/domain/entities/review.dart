import 'package:freezed_annotation/freezed_annotation.dart';

part 'review.freezed.dart';
part 'review.g.dart';

@freezed
class Review with _$Review {
  const factory Review({
    required String id,
    required String orderId,
    required String supplierGroupId,
    required String clientId,
    required String supplierId,
    required int stars,
    required String comment,

    /// Le titre de l'avis (`0119`), facultatif : une ligne qui résume.
    String? title,
    required DateTime createdAt,

    /// Photos et vidéo de l'acheteur (`0061`). Le fournisseur les voit dans
    /// sa gestion des avis : un reproche illustré se traite autrement qu'un
    /// reproche décrit.
    @Default([]) List<String> imagePaths,
    String? videoPath,

    /// The supplier's public reply to this review, if they've written one —
    /// re-calling `ReviewRepository.reply` edits it in place rather than
    /// appending a second one.
    String? supplierReply,
    DateTime? supplierRepliedAt,
  }) = _Review;

  factory Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);
}
