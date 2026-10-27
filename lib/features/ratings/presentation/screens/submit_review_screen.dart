import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/storage/media_picker.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/order.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';

import '../controllers/review_controller.dart';
import '../providers/review_providers.dart';
import '../widgets/review_media.dart';

/// Donner son avis sur la part d'une commande livrée (maquette « Add
/// review » du kit) : ce qu'on note en tête, les étoiles, le texte, les
/// photos, et l'envoi en bas.
///
/// Un avis porte sur la part d'**une** boutique : une commande livrée par
/// deux boutiques en reçoit deux. [groupId] dit laquelle ; sans lui (un
/// lien ancien), c'est la première part livrée.
///
/// Le titre, facultatif, suit la maquette (« Set a Title for your
/// review », `0119`). « Recommanderiez-vous ce produit ? » n'a pas
/// d'équivalent en base : il n'est pas proposé.
class SubmitReviewScreen extends ConsumerWidget {
  const SubmitReviewScreen({super.key, required this.orderId, this.groupId});

  final String orderId;
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commande = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Laisser un avis')),
      body: commande.when(
        skipLoadingOnReload: true,
        loading: () => const _Chargement(),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'La commande n\'a pas pu être chargée',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(orderDetailProvider(orderId)),
            child: const Text('Réessayer'),
          ),
        ),
        data: (commande) {
          final groupe = groupId == null
              ? commande.supplierGroups.firstWhereOrNull(
                      (g) => g.status == OrderStatus.delivered,
                    ) ??
                    commande.supplierGroups.firstOrNull
              : commande.supplierGroups.firstWhereOrNull(
                  (g) => g.id == groupId,
                );
          if (groupe == null) {
            return const IllustratedMessage(
              illustration: ShopIllustration.noResult,
              title: 'Commande introuvable',
              message: 'Cette part de commande n\'existe plus.',
            );
          }
          if (groupe.status != OrderStatus.delivered) {
            return const IllustratedMessage(
              illustration: ShopIllustration.emptyState,
              title: 'Pas encore livrée',
              message:
                  'Vous pourrez donner votre avis une fois la commande '
                  'reçue.',
            );
          }
          final peutNoter = ref.watch(
            canReviewProvider((orderId: orderId, groupId: groupe.id)),
          );
          return peutNoter.when(
            skipLoadingOnReload: true,
            loading: () => const _Chargement(),
            error: (erreur, _) => IllustratedMessage(
              illustration: ShopIllustration.serverError,
              title: 'L\'avis n\'a pas pu être préparé',
              message: messagePourUtilisateur(erreur),
            ),
            data: (peutNoter) => peutNoter
                ? _Formulaire(
                    orderId: orderId,
                    groupe: groupe,
                    clientId: commande.clientId,
                  )
                : IllustratedMessage(
                    illustration: ShopIllustration.orderSuccess,
                    title: 'Avis déjà publié',
                    message:
                        'Merci ! Vous avez déjà donné votre avis sur votre '
                        'commande chez ${groupe.supplierName}.',
                  ),
          );
        },
      ),
    );
  }
}

class _Chargement extends StatelessWidget {
  const _Chargement();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: ShopColors.primary));
}

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({
    required this.orderId,
    required this.groupe,
    required this.clientId,
  });

  final String orderId;
  final OrderSupplierGroup groupe;

  /// Sert de dossier d'envoi des médias, pas d'identité déclarée : la base
  /// repose le nom affiché elle-même (`stamp_review_author`, `0061`).
  final String clientId;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  final _formulaire = GlobalKey<FormState>();
  final _titre = TextEditingController();
  final _commentaire = TextEditingController();

  /// La longueur que `0119` accepte pour un titre.
  static const _titreMax = 100;

  /// Aucune étoile au départ, comme dans le kit : une note pré-remplie à 5
  /// tire toutes les notes vers le haut sans que personne l'ait choisie.
  int _etoiles = 0;
  bool _noteManquante = false;

  /// Photos et vidéo de l'acheteur, déjà téléversées : ce sont des chemins
  /// Storage, pas des fichiers en attente. L'avis peut donc partir en une
  /// seule écriture, et un envoi qui échoue ne fait pas perdre le texte.
  final _images = <String>[];
  String? _video;
  bool _televersement = false;

  @override
  void initState() {
    super.initState();
    // Le compte des caractères restants suit la saisie.
    _titre.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titre.dispose();
    _commentaire.dispose();
    super.dispose();
  }

  void _signaler(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Le dossier d'envoi est l'identifiant du client : c'est ce que la policy
  /// Storage impose et ce que la base revérifie à l'écriture de la ligne
  /// (`validate_media_paths`, `0061`).
  Future<void> _ajouterPhotos() async {
    setState(() => _televersement = true);
    final resultat = await pickAndUploadImages(
      client: ref.read(supabaseClientProvider),
      bucket: 'review-media',
      folder: widget.clientId,
      limit: 6,
    );
    if (!mounted) return;
    setState(() {
      _televersement = false;
      _images.addAll(resultat.paths);
      if (_images.length > 6) _images.removeRange(6, _images.length);
    });
    if (resultat.failures > 0) {
      _signaler(
        resultat.failures == 1
            ? 'Une photo n\'a pas pu être ajoutée.'
            : '${resultat.failures} photos n\'ont pas pu être ajoutées.',
      );
    }
  }

  Future<void> _ajouterVideo() async {
    setState(() => _televersement = true);
    try {
      final chemin = await pickAndUploadVideo(
        client: ref.read(supabaseClientProvider),
        bucket: 'review-media',
        folder: widget.clientId,
      );
      if (!mounted) return;
      setState(() => _video = chemin ?? _video);
    } catch (erreur) {
      _signaler(
        messagePourUtilisateur(
          erreur,
          repli: 'Impossible d\'ajouter cette vidéo.',
        ),
      );
    } finally {
      if (mounted) setState(() => _televersement = false);
    }
  }

  Future<void> _envoyer() async {
    final texteValide = _formulaire.currentState!.validate();
    setState(() => _noteManquante = _etoiles == 0);
    if (!texteValide || _etoiles == 0) return;

    final ok = await ref
        .read(reviewControllerProvider.notifier)
        .submit(
          orderId: widget.orderId,
          supplierGroupId: widget.groupe.id,
          supplierId: widget.groupe.supplierId,
          stars: _etoiles,
          title: _titre.text.trim().isEmpty ? null : _titre.text.trim(),
          comment: _commentaire.text.trim(),
          imagePaths: _images,
          videoPath: _video,
        );
    if (!mounted) return;
    final messager = ScaffoldMessenger.of(context);
    if (ok) {
      // L'écran se fermait sans un mot : rien ne disait au client que son
      // avis était parti. Le message est porté par le messager de l'app,
      // pas par cet écran, pour rester affiché sur la commande où l'on
      // revient — qui montre désormais « Avis publié ».
      context.pop();
      messager.showSnackBar(
        const SnackBar(content: Text('Merci ! Votre avis est publié.')),
      );
      return;
    }
    messager.showSnackBar(
      SnackBar(
        content: Text(
          messagePourUtilisateur(
            ref.read(reviewControllerProvider).error,
            repli: 'Votre avis n\'a pas pu être envoyé. Réessayez.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final envoi = ref.watch(reviewControllerProvider).isLoading;

    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formulaire,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                ShopSizes.screenMargin,
                ShopSizes.padding,
                ShopSizes.screenMargin,
                ShopSizes.padding,
              ),
              children: [
                _EnTete(groupe: widget.groupe),
                const Divider(height: ShopSizes.padding * 3),
                Text(
                  'Votre note pour cette commande',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: ShopSizes.padding / 2),
                StarRatingField(
                  value: _etoiles,
                  onChanged: (n) => setState(() {
                    _etoiles = n;
                    _noteManquante = false;
                  }),
                ),
                if (_noteManquante)
                  Text(
                    'Choisissez une note de 1 à 5 étoiles.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: ShopColors.error,
                    ),
                  ),
                const Divider(height: ShopSizes.padding * 3),
                Text(
                  'Un titre pour votre avis',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: ShopSizes.padding),
                TextFormField(
                  controller: _titre,
                  maxLength: _titreMax,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  // Le compte est écrit dessous, à gauche, comme dans le kit.
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  decoration: const InputDecoration(
                    hintText: 'Résumez votre avis (facultatif)',
                  ),
                ),
                const SizedBox(height: ShopSizes.padding / 2),
                Text(
                  _titreMax - _titre.text.length <= 1
                      ? '${_titreMax - _titre.text.length} caractère restant'
                      : '${_titreMax - _titre.text.length} caractères restants',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: ShopSizes.padding * 1.5),
                Text(
                  'Qu\'avez-vous aimé, ou moins aimé ?',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: ShopSizes.padding),
                TextFormField(
                  controller: _commentaire,
                  minLines: 5,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  validator: Validators.required,
                  decoration: const InputDecoration(
                    hintText: 'Ce que les prochains acheteurs devraient savoir',
                  ),
                ),
                const SizedBox(height: ShopSizes.padding * 1.5),
                Text('Photos et vidéo', style: theme.textTheme.titleSmall),
                const SizedBox(height: ShopSizes.padding / 4),
                // Une photo d'acheteur vaut plus qu'un paragraphe : c'est la
                // seule image du produit que le vendeur n'a pas choisie.
                Text(
                  'Montrez l\'article reçu : c\'est la seule photo que la '
                  'boutique n\'a pas choisie.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (_images.isNotEmpty || _video != null)
                  MediaStrip(imagePaths: _images, videoPath: _video),
                const SizedBox(height: ShopSizes.padding),
                // L'un sous l'autre : côte à côte, « Ajouter des photos »
                // passait sur deux lignes et déséquilibrait la rangée.
                OutlinedButton.icon(
                  onPressed: _televersement || _images.length >= 6
                      ? null
                      : _ajouterPhotos,
                  icon: const ShopIcon(ShopIcons.image, size: 20),
                  label: Text(
                    _images.isEmpty
                        ? 'Ajouter des photos'
                        : 'Ajouter des photos (${_images.length}/6)',
                  ),
                ),
                const SizedBox(height: ShopSizes.padding / 2),
                OutlinedButton.icon(
                  onPressed: _televersement ? null : _ajouterVideo,
                  icon: const ShopIcon(ShopIcons.cameraBold, size: 20),
                  label: Text(
                    _video == null ? 'Ajouter une vidéo' : 'Remplacer la vidéo',
                  ),
                ),
              ],
            ),
          ),
        ),
        BottomActionBar(
          label: 'Envoyer l\'avis',
          isLoading: envoi || _televersement,
          onPressed: envoi || _televersement ? null : _envoyer,
        ),
      ],
    );
  }
}

/// Ce qu'on note, en tête comme dans la maquette : la photo du premier
/// article, la boutique en capitales grises, et l'article — ou le compte des
/// articles quand la part en a plusieurs.
class _EnTete extends ConsumerWidget {
  const _EnTete({required this.groupe});

  final OrderSupplierGroup groupe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final premier = groupe.items.firstOrNull;
    final produit = premier == null
        ? null
        : ref.watch(productDetailProvider(premier.productId)).valueOrNull;
    final variante = produit?.variants.firstWhereOrNull(
      (v) => v.id == premier?.variantId,
    );
    final autres = groupe.items.length - 1;
    return Row(
      children: [
        SizedBox.square(
          dimension: 88,
          child: ShopImage(
            variante?.imageUrls.firstOrNull ?? produit?.imageUrls.firstOrNull,
          ),
        ),
        const SizedBox(width: ShopSizes.padding * 1.5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                groupe.supplierName.toUpperCase(),
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: ShopSizes.padding / 2),
              Text(
                premier?.productNameSnapshot ?? groupe.supplierName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (autres > 0) ...[
                const SizedBox(height: ShopSizes.padding / 4),
                Text(
                  autres == 1
                      ? 'et 1 autre article'
                      : 'et $autres autres articles',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
