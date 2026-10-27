import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/storage/media_picker.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../controllers/review_comment_controller.dart';
import 'review_media.dart';

/// Rédige un commentaire sous un avis, avec ses photos ou sa vidéo.
Future<void> showReviewCommentSheet(
  BuildContext context, {
  required String reviewId,
}) {
  return showShopSheet<void>(
    context,
    heightFactor: 0.7,
    child: _Redaction(reviewId: reviewId),
  );
}

class _Redaction extends ConsumerStatefulWidget {
  const _Redaction({required this.reviewId});

  final String reviewId;

  @override
  ConsumerState<_Redaction> createState() => _RedactionState();
}

class _RedactionState extends ConsumerState<_Redaction> {
  final _texte = TextEditingController();
  final _photos = <String>[];
  String? _video;
  bool _envoiDeMedia = false;

  @override
  void initState() {
    super.initState();
    // Sans cette écoute, le bouton resterait grisé pendant toute la saisie :
    // son état dépend du texte, et rien d'autre ne reconstruit la feuille.
    _texte.addListener(_auChangement);
  }

  void _auChangement() => setState(() {});

  @override
  void dispose() {
    _texte.removeListener(_auChangement);
    _texte.dispose();
    super.dispose();
  }

  /// Le dossier d'envoi est l'identifiant de l'auteur : c'est ce que la
  /// policy Storage impose, et ce que la base revérifie à l'écriture de la
  /// ligne (`validate_media_paths`, `0061`).
  String? get _dossier => ref.read(currentUserProvider).valueOrNull?.id;

  void _signaler(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _ajouterDesPhotos() async {
    final dossier = _dossier;
    if (dossier == null) return;
    setState(() => _envoiDeMedia = true);
    final resultat = await pickAndUploadImages(
      client: ref.read(supabaseClientProvider),
      bucket: reviewMediaBucket,
      folder: dossier,
      // Quatre, comme le plafond posé en base : annoncer plus serait
      // promettre un envoi que l'écriture refusera.
      limit: 4,
    );
    if (!mounted) return;
    setState(() {
      _envoiDeMedia = false;
      _photos.addAll(resultat.paths);
      if (_photos.length > 4) _photos.removeRange(4, _photos.length);
    });
    if (resultat.failures > 0) {
      _signaler(
        resultat.failures == 1
            ? 'Une photo n\'a pas pu être ajoutée.'
            : '${resultat.failures} photos n\'ont pas pu être ajoutées.',
      );
    }
  }

  Future<void> _ajouterUneVideo() async {
    final dossier = _dossier;
    if (dossier == null) return;
    setState(() => _envoiDeMedia = true);
    try {
      final chemin = await pickAndUploadVideo(
        client: ref.read(supabaseClientProvider),
        bucket: reviewMediaBucket,
        folder: dossier,
      );
      if (!mounted) return;
      setState(() => _video = chemin ?? _video);
    } catch (e) {
      _signaler(
        messagePourUtilisateur(e, repli: 'Impossible d\'ajouter cette vidéo.'),
      );
    } finally {
      if (mounted) setState(() => _envoiDeMedia = false);
    }
  }

  Future<void> _publier() async {
    final ok = await ref
        .read(reviewCommentControllerProvider.notifier)
        .add(
          reviewId: widget.reviewId,
          body: _texte.text.trim(),
          imagePaths: _photos,
          videoPath: _video,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      _signaler('Votre commentaire est publié.');
      return;
    }
    final erreur = ref.read(reviewCommentControllerProvider).error;
    _signaler(
      messagePourUtilisateur(
        erreur,
        repli: 'Le commentaire n\'a pas pu être publié.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final occupe =
        ref.watch(reviewCommentControllerProvider).isLoading || _envoiDeMedia;

    return Column(
      children: [
        const SheetHeader(title: 'Commenter cet avis'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.padding,
              ShopSizes.padding / 2,
              ShopSizes.padding,
              ShopSizes.padding,
            ),
            children: [
              const Text(
                'Votre commentaire sera visible par tous les visiteurs de ce '
                'produit.',
              ),
              const SizedBox(height: ShopSizes.padding),
              TextField(
                controller: _texte,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Votre commentaire',
                ),
              ),
              if (_photos.isNotEmpty || _video != null)
                MediaStrip(imagePaths: _photos, videoPath: _video),
              const SizedBox(height: ShopSizes.padding),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: occupe || _photos.length >= 4
                          ? null
                          : _ajouterDesPhotos,
                      icon: const ShopIcon(ShopIcons.cameraAdd, size: 20),
                      label: Text(
                        _photos.isEmpty ? 'Photos' : '${_photos.length}/4',
                      ),
                    ),
                  ),
                  const SizedBox(width: ShopSizes.padding / 2),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: occupe ? null : _ajouterUneVideo,
                      icon: const ShopIcon(ShopIcons.image, size: 20),
                      label: Text(_video == null ? 'Vidéo' : 'Remplacer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        BottomActionBar(
          label: 'Publier',
          isLoading: occupe,
          // Un commentaire vide est refusé en base (`length(btrim(body))
          // > 0`) : autant ne pas laisser croire que le bouton part.
          onPressed: _texte.text.trim().isEmpty ? null : _publier,
        ),
      ],
    );
  }
}
