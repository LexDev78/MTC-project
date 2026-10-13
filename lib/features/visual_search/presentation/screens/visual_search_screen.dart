import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_grid.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/favorite_toggle_button.dart';

import '../../domain/visual_search_result.dart';
import '../providers/visual_search_providers.dart';

/// Chercher un produit à partir d'une photo.
///
/// Pensé pour le cas qui motive la fonctionnalité : on a vu un tissu au
/// marché, on ne sait pas comment il s'appelle. Taper « bogolan bleu à
/// motifs » suppose de connaître le mot ; prendre la photo, non.
///
/// L'appareil photo d'abord, la galerie ensuite : c'est l'ordre de l'usage,
/// pas celui de la facilité d'implémentation.
class VisualSearchScreen extends ConsumerWidget {
  const VisualSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(visualSearchProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rechercher par photo')),
      body: state.when(
        loading: () => const _Analysing(),
        error: (error, _) => _Error(error: error),
        data: (result) {
          if (result == null) return const _Invitation();
          if (result.products.isEmpty) {
            return _Empty(remaining: result.remaining);
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${result.products.length} produit'
                        '${result.products.length > 1 ? 's' : ''} ressemblant'
                        '${result.products.length > 1 ? 's' : ''} à votre photo',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '${result.remaining} restantes',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ProductGrid(
                  products: result.products,
                  cardOverlayBuilder: (product) =>
                      FavoriteToggleButton(productId: product.id),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickAndSearch(context, ref),
        icon: const Icon(Icons.photo_camera_rounded),
        label: const Text('Prendre une photo'),
      ),
    );
  }

  Future<void> _pickAndSearch(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // Redimensionnée et compressée **avant** l'envoi : une photo de
    // téléphone pèse plusieurs mégaoctets, que la fonction edge refuserait,
    // et qu'un modèle redimensionnerait de toute façon. Autant ne pas les
    // faire traverser le réseau depuis une connexion mobile.
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    await ref
        .read(visualSearchProvider.notifier)
        .search(
          imageBytes: bytes,
          contentType: file.mimeType ?? 'image/jpeg',
        );
  }
}

class _Invitation extends StatelessWidget {
  const _Invitation();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: MtcEmptyState(
        icon: Icons.photo_camera_rounded,
        title: 'Vous avez vu un produit sans connaître son nom ?',
        subtitle:
            'Prenez-le en photo : nous cherchons ce qui lui ressemble dans '
            'le catalogue.',
      ),
    );
  }
}

class _Analysing extends StatelessWidget {
  const _Analysing();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Analyse de votre photo…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: MtcEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Rien de ressemblant pour l\'instant',
        // On ne propose pas « les moins éloignés » : un résultat qui ne
        // ressemble pas est pire qu'aucun, parce qu'on le croit.
        subtitle:
            'Aucun produit du catalogue ne ressemble assez à cette photo. '
            'Essayez un autre angle, ou cherchez par mot-clé. '
            '($remaining recherches restantes aujourd\'hui)',
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final quotaExhausted =
        error is VisualSearchException &&
        (error as VisualSearchException).quotaExhausted;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: MtcEmptyState(
        icon: quotaExhausted
            ? Icons.hourglass_bottom_rounded
            : Icons.cloud_off_rounded,
        title: quotaExhausted
            ? 'Vos recherches du jour sont épuisées'
            : 'Recherche indisponible',
        subtitle: error.toString(),
      ),
    );
  }
}
