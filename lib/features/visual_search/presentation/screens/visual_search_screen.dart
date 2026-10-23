import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/shop_product_grid.dart';

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
    final etat = ref.watch(visualSearchProvider);
    final theme = Theme.of(context);
    // Quota épuisé : une nouvelle photo échouerait de la même façon.
    final epuise = switch (etat.error) {
      VisualSearchException(:final quotaExhausted) => quotaExhausted,
      _ => false,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Rechercher par photo')),
      body: etat.when(
        loading: () => const _Analyse(),
        error: (erreur, _) => _Erreur(erreur: erreur),
        data: (resultat) {
          if (resultat == null) return const _Invitation();
          if (resultat.products.isEmpty) {
            return IllustratedMessage(
              illustration: ShopIllustration.noResult,
              title: 'Rien de ressemblant pour l\'instant',
              // On ne propose pas « les moins éloignés » : un résultat qui
              // ne ressemble pas est pire qu'aucun, parce qu'on le croit.
              message:
                  'Aucun produit du catalogue ne ressemble assez à cette '
                  'photo. Essayez un autre angle, ou cherchez par mot-clé. '
                  '(${_restantes(resultat.remaining)} aujourd\'hui)',
            );
          }
          final n = resultat.products.length;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  ShopSizes.screenMargin,
                  ShopSizes.padding,
                  ShopSizes.screenMargin,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n == 1
                            ? '1 produit ressemblant à votre photo'
                            : '$n produits ressemblant à votre photo',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: ShopSizes.padding / 4),
                      Text(
                        '${_restantes(resultat.remaining)} aujourd\'hui',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              SliverShopProductGrid(
                products: resultat.products,
                padding: ShopSizes.screenMargin,
                // Ouvrir un résultat est l'étiquette du futur jeu
                // d'entraînement (`0086`) : c'est ici, et nulle part
                // ailleurs, qu'on apprend ce que la personne cherchait
                // vraiment.
                onOpened: (produit) => ref
                    .read(visualSearchProvider.notifier)
                    .recordOpened(produit.id),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomActionBar(
        label: 'Prendre une photo',
        icon: const ShopIcon(ShopIcons.cameraBold, color: Colors.white),
        onPressed: etat.isLoading || epuise
            ? null
            : () => _choisirEtChercher(context, ref),
      ),
    );
  }

  static String _restantes(int n) =>
      n == 1 ? '1 recherche restante' : '$n recherches restantes';

  Future<void> _choisirEtChercher(BuildContext context, WidgetRef ref) async {
    final source = await showShopSheet<ImageSource>(
      context,
      heightFactor: 0.32,
      child: Scaffold(
        body: Column(
          children: [
            const SheetHeader(title: 'Votre photo'),
            Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ShopSizes.padding,
                ),
                child: Column(
                  children: [
                    ChevronListTile(
                      icon: ShopIcons.cameraBold,
                      title: 'Prendre une photo',
                      onTap: () =>
                          Navigator.of(context).pop(ImageSource.camera),
                    ),
                    ChevronListTile(
                      icon: ShopIcons.image,
                      title: 'Choisir dans la galerie',
                      showDivider: false,
                      onTap: () =>
                          Navigator.of(context).pop(ImageSource.gallery),
                    ),
                  ],
                ),
              ),
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
    final fichier = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (fichier == null) return;

    final octets = await fichier.readAsBytes();
    await ref
        .read(visualSearchProvider.notifier)
        .search(
          imageBytes: octets,
          contentType: fichier.mimeType ?? 'image/jpeg',
        );
  }
}

class _Invitation extends StatelessWidget {
  const _Invitation();

  @override
  Widget build(BuildContext context) {
    return const IllustratedMessage(
      illustration: ShopIllustration.noResult,
      title: 'Vous avez vu un produit sans connaître son nom ?',
      // La seconde phrase est là parce qu'on conserve désormais la photo
      // (`0086`). Le dire en clair, à l'endroit où la personne décide,
      // plutôt que de l'enterrer dans des conditions d'utilisation que
      // personne ne lit.
      message:
          'Prenez-le en photo : nous cherchons ce qui lui ressemble dans le '
          'catalogue. Vos photos nous servent à améliorer la reconnaissance, '
          'et vous pouvez les effacer à tout moment.',
    );
  }
}

class _Analyse extends StatelessWidget {
  const _Analyse();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: ShopColors.primary),
          const SizedBox(height: ShopSizes.padding),
          Text(
            'Analyse de votre photo…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Erreur extends StatelessWidget {
  const _Erreur({required this.erreur});

  final Object erreur;

  @override
  Widget build(BuildContext context) {
    final quotaEpuise =
        erreur is VisualSearchException &&
        (erreur as VisualSearchException).quotaExhausted;

    return IllustratedMessage(
      illustration: quotaEpuise
          ? ShopIllustration.failed
          : ShopIllustration.noInternet,
      title: quotaEpuise
          ? 'Vos recherches du jour sont épuisées'
          : 'Recherche indisponible',
      // Le message de la recherche par photo est déjà écrit pour le client
      // (quota, photo illisible) : le traducteur d'erreurs ne le connaît
      // pas et le remplaçait par une phrase générique.
      message: erreur is VisualSearchException
          ? (erreur as VisualSearchException).message
          : messagePourUtilisateur(
              erreur,
              repli: 'La recherche par photo est indisponible pour le moment.',
            ),
    );
  }
}
