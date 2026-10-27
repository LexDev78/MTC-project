import 'package:flutter/material.dart';

import 'package:mtc_app/core/utils/currency_formatter.dart';

import '../shop_icons.dart';
import '../shop_tokens.dart';
import 'shop_image.dart';

/// La galerie de la fiche produit (`ProductImages` du kit) : une photo aux
/// coins de 24 qui laisse voir le bord de la suivante, et une pastille de
/// points en bas à droite dès qu'il y en a plusieurs.
class ShopProductGallery extends StatefulWidget {
  const ShopProductGallery({
    super.key,
    required this.images,
    this.bucket = 'product-images',
    this.onTap,
    this.overlay,
  });

  /// Vide : la silhouette d'image, comme sur les cartes.
  final List<String> images;
  final String bucket;

  /// Reçoit l'indice de la photo touchée (plein écran).
  final ValueChanged<int>? onTap;

  /// Posé en haut à gauche de la photo affichée (vidéo, remise).
  final Widget? overlay;

  @override
  State<ShopProductGallery> createState() => _ShopProductGalleryState();
}

class _ShopProductGalleryState extends State<ShopProductGallery> {
  final _controller = PageController(viewportFraction: 0.9);
  int _courante = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final images = widget.images;
    final nombre = images.isEmpty ? 1 : images.length;
    final encre = theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) =>
          _galerie(theme, images, nombre, encre, constraints.maxWidth),
    );
  }

  Widget _galerie(
    ThemeData theme,
    List<String> images,
    int nombre,
    Color encre,
    double largeur,
  ) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: nombre,
            onPageChanged: (page) => setState(() => _courante = page),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: ShopSizes.padding),
              child: GestureDetector(
                onTap: images.isEmpty || widget.onTap == null
                    ? null
                    : () => widget.onTap!(index),
                child: ShopImage(
                  images.isEmpty ? null : images[index],
                  bucket: widget.bucket,
                  radius: ShopSizes.radius * 2,
                  cacheWidth: 900,
                ),
              ),
            ),
          ),
          // La page courante est centrée : son bord gauche est à 5 % de
          // la largeur (`viewportFraction` 0,9).
          if (widget.overlay != null)
            Positioned(
              top: ShopSizes.padding,
              left: largeur * 0.05 + ShopSizes.padding,
              child: widget.overlay!,
            ),
          if (nombre > 1)
            Positioned(
              height: 20,
              bottom: 24,
              right: largeur * 0.15,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ShopSizes.padding * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.all(Radius.circular(50)),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < nombre; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            right: i == nombre - 1 ? 0 : ShopSizes.padding / 4,
                          ),
                          child: CircleAvatar(
                            radius: 3,
                            backgroundColor: encre.withValues(
                              alpha: i == _courante ? 1 : 0.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le bloc d'en-tête de la fiche (`ProductInfo` du kit) : la marque en
/// capitales, le nom, la disponibilité et la note, puis la description.
class ShopProductInfo extends StatelessWidget {
  const ShopProductInfo({
    super.key,
    required this.brand,
    required this.title,
    required this.availability,
    required this.rating,
    required this.reviewCount,
    required this.description,
    this.descriptionTitle = 'Description',
    this.descriptionMaxLines = 5,
  });

  final String brand;
  final String title;

  /// Une [AvailabilityTag], le plus souvent.
  final Widget availability;
  final double rating;

  /// À zéro, « Pas encore d'avis » plutôt qu'une note de 0.
  final int reviewCount;
  final String description;
  final String descriptionTitle;

  /// Le texte entier reste lisible ailleurs (feuille « Détails du produit ») :
  /// ici il ne doit pas repousser les rubriques sous le pli.
  final int descriptionMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(ShopSizes.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            brand.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: ShopSizes.padding / 2),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: ShopSizes.padding),
          Row(
            children: [
              availability,
              const SizedBox(width: ShopSizes.padding / 2),
              // La note cède la place (et s'abrège) plutôt que de déborder
              // sur un petit écran ou avec un texte agrandi.
              Expanded(
                child: reviewCount == 0
                    ? const Text(
                        'Pas encore d\'avis',
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const ShopIcon(ShopIcons.starFilled, tint: false),
                          const SizedBox(width: ShopSizes.padding / 4),
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                text:
                                    '${rating.toStringAsFixed(1).replaceAll('.', ',')} ',
                                style: theme.textTheme.bodyLarge,
                                children: [
                                  TextSpan(
                                    text: reviewCount == 1
                                        ? '(1 avis)'
                                        : '($reviewCount avis)',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: ShopSizes.padding),
          Text(
            descriptionTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: ShopSizes.padding / 2),
          Text(
            description,
            maxLines: descriptionMaxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: ShopSizes.padding / 2),
        ],
      ),
    );
  }
}

/// Le prix d'une unité dans la feuille d'achat (`UnitPrice` du kit) : son
/// titre, le montant, et l'ancien prix barré s'il y a une baisse.
class ShopUnitPrice extends StatelessWidget {
  const ShopUnitPrice({
    super.key,
    required this.priceFcfa,
    this.compareAtFcfa,
    this.label = 'Prix unitaire',
    this.footer,
  });

  final int priceFcfa;
  final int? compareAtFcfa;
  final String label;

  /// Sous le prix : le stock, la remise et le palier suivant.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avant = compareAtFcfa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: ShopSizes.padding),
        Text.rich(
          TextSpan(
            text: '${CurrencyFormatter.formatFcfa(priceFcfa)}  ',
            style: theme.textTheme.titleLarge,
            children: [
              // Sans unité, comme sur les cartes : il se lit comme une
              // comparaison, et tient sur la ligne du prix.
              if (avant != null && avant > priceFcfa)
                TextSpan(
                  text: CurrencyFormatter.formatAmount(avant),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.textTheme.bodyMedium?.color,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: ShopSizes.padding / 2),
          footer!,
        ],
      ],
    );
  }
}

/// Un choix de la feuille d'achat (`SelectedColors`, `SelectedSize` du
/// kit) : son titre, puis les valeurs — en rangée qui défile pour des
/// pastilles, à la ligne pour des boutons.
class ShopOptionGroup extends StatelessWidget {
  const ShopOptionGroup({
    super.key,
    required this.title,
    required this.children,
    this.scrollable = false,
    this.footer,
  });

  final String title;
  final List<Widget> children;

  /// Une seule rangée qui défile (les couleurs), plutôt qu'un retour à la
  /// ligne (les tailles).
  final bool scrollable;

  /// Sous les valeurs : « Choisissez une valeur. ».
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    const marge = EdgeInsets.symmetric(horizontal: ShopSizes.padding);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(ShopSizes.padding),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: marge,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < children.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : ShopSizes.padding / 2,
                    ),
                    child: children[i],
                  ),
              ],
            ),
          )
        else
          Padding(
            padding: marge,
            child: Wrap(
              spacing: ShopSizes.padding / 2,
              runSpacing: ShopSizes.padding / 2,
              children: children,
            ),
          ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.padding,
              ShopSizes.padding / 2,
              ShopSizes.padding,
              0,
            ),
            child: footer,
          ),
      ],
    );
  }
}
