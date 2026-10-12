import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/storage/media_picker.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';

import '../controllers/review_controller.dart';
import '../providers/review_providers.dart';
import '../widgets/product_reviews_section.dart' show MediaStrip;
import '../widgets/star_rating_input.dart';

class SubmitReviewScreen extends ConsumerWidget {
  const SubmitReviewScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Laisser un avis')),
      body: AsyncValueWidget(
        value: orderAsync,
        data: (order) {
          final group = order.supplierGroups.firstWhere(
            (g) => g.status == OrderStatus.delivered,
            orElse: () => order.supplierGroups.first,
          );
          final canReviewAsync = ref.watch(
            canReviewProvider((orderId: orderId, groupId: group.id)),
          );

          return AsyncValueWidget(
            value: canReviewAsync,
            data: (canReview) {
              if (!canReview) {
                return const MtcEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Vous avez déjà noté cette commande',
                );
              }
              return _ReviewForm(
                orderId: orderId,
                supplierGroupId: group.id,
                supplierId: group.supplierId,
                supplierName: group.supplierName,
                clientId: order.clientId,
              );
            },
          );
        },
      ),
    );
  }
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({
    required this.orderId,
    required this.supplierGroupId,
    required this.supplierId,
    required this.supplierName,
    required this.clientId,
  });

  final String orderId;
  final String supplierGroupId;
  final String supplierId;
  final String supplierName;

  /// Sert de dossier d'envoi des médias, pas d'identité déclarée : la base
  /// repose le nom affiché elle-même (`stamp_review_author`, `0061`).
  final String clientId;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  int _stars = 5;
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// Photos et vidéo de l'acheteur, déjà téléversées : ce sont des chemins
  /// Storage, pas des fichiers en attente. L'avis peut donc partir en une
  /// seule écriture, et un envoi qui échoue ne fait pas perdre le texte.
  final _images = <String>[];
  String? _videoPath;
  bool _uploading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _signal(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Le dossier d'envoi est l'identifiant du client : c'est ce que la policy
  /// Storage impose et ce que la base revérifie à l'écriture de la ligne
  /// (`validate_media_paths`, `0061`).
  Future<void> _addPhotos() async {
    setState(() => _uploading = true);
    final result = await pickAndUploadImages(
      client: ref.read(supabaseClientProvider),
      bucket: 'review-media',
      folder: widget.clientId,
      limit: 6,
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      _images.addAll(result.paths);
      if (_images.length > 6) _images.removeRange(6, _images.length);
    });
    if (result.failures > 0) {
      _signal(
        result.failures == 1
            ? 'Une photo n\'a pas pu être ajoutée.'
            : '${result.failures} photos n\'ont pas pu être ajoutées.',
      );
    }
  }

  Future<void> _addVideo() async {
    setState(() => _uploading = true);
    try {
      final path = await pickAndUploadVideo(
        client: ref.read(supabaseClientProvider),
        bucket: 'review-media',
        folder: widget.clientId,
      );
      if (!mounted) return;
      setState(() => _videoPath = path ?? _videoPath);
    } catch (e) {
      _signal('Impossible d\'ajouter cette vidéo. $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(reviewControllerProvider.notifier)
        .submit(
          orderId: widget.orderId,
          supplierGroupId: widget.supplierGroupId,
          supplierId: widget.supplierId,
          stars: _stars,
          comment: _commentController.text.trim(),
          imagePaths: _images,
          videoPath: _videoPath,
        );
    if (!mounted) return;
    if (success) {
      context.pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Une erreur est survenue')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.supplierName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            StarRatingInput(
              value: _stars,
              onChanged: (value) => setState(() => _stars = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            MtcTextField(
              label: 'Votre commentaire',
              controller: _commentController,
              validator: Validators.required,
            ),
            if (_images.isNotEmpty || _videoPath != null)
              MediaStrip(imagePaths: _images, videoPath: _videoPath),
            const SizedBox(height: AppSpacing.md),
            // Une photo d'acheteur vaut plus qu'un paragraphe : c'est la
            // seule image du produit que le vendeur n'a pas choisie.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading || _images.length >= 6
                        ? null
                        : _addPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _images.isEmpty ? 'Ajouter des photos' : '${_images.length}/6',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : _addVideo,
                    icon: const Icon(Icons.videocam_outlined),
                    label: Text(
                      _videoPath == null ? 'Vidéo' : 'Remplacer la vidéo',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            MtcPrimaryButton(
              label: "Envoyer l'avis",
              isLoading: reviewState.isLoading || _uploading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
