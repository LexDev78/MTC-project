import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/shop/shop.dart';

import '../../domain/entities/product.dart';
import 'shop_product_data.dart';

/// La grille de produits du kit (`BookmarkScreen`, résultats de
/// recherche) : des cartes de 200 points au plus, espacées de 16. En
/// « sliver », pour se glisser sous un en-tête dans la page qui défile
/// (catalogue, recherche, vitrine, recherche par photo).
class SliverShopProductGrid extends StatelessWidget {
  const SliverShopProductGrid({
    super.key,
    required this.products,
    this.padding = ShopSizes.padding,
    this.top,
    this.onOpened,
  });

  final List<Product> products;

  /// Marge des bords : 16 dans les écrans issus du code du kit, 32 dans
  /// ceux issus de ses maquettes (résultats de recherche).
  final double padding;

  /// La marge du haut quand un titre précède la grille ; [padding] sinon.
  final double? top;

  /// Prévenu à l'ouverture d'un produit (journal de la recherche par photo).
  final void Function(Product product)? onOpened;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(padding, top ?? padding, padding, padding),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: ShopSizes.padding,
          crossAxisSpacing: ShopSizes.padding,
          childAspectRatio: 0.66,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final produit = products[index];
          return ShopProductCard(
            width: null,
            height: null,
            data: produit.shopData(),
            onTap: () {
              onOpened?.call(produit);
              context.push(AppRoutes.productDetail(produit.id));
            },
          );
        }, childCount: products.length),
      ),
    );
  }
}
