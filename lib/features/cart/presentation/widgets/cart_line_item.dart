import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';

import '../../domain/entities/cart_item.dart';
import '../controllers/cart_controller.dart';
import '../providers/cart_providers.dart';

/// Un article du panier, en ligne du kit (« Review your order ») : la
/// photo, la boutique, le nom, le prix — puis ce que MTC y ajoute dessous :
/// la variante choisie, le stock quand il compte, la quantité et le retrait.
///
/// La boutique n'est pas décorative chez MTC : la livraison et les codes
/// promo se règlent boutique par boutique (`place_order` découpe la commande
/// en groupes fournisseur). Le client doit voir que deux articles viennent
/// de deux endroits avant de découvrir deux frais de livraison.
class CartLineItem extends ConsumerWidget {
  const CartLineItem({super.key, required this.item});

  final CartItem item;

  Future<void> _agir(
    BuildContext context,
    Future<void> Function() action,
    String repli,
  ) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (erreur) {
      messager.showSnackBar(
        SnackBar(content: Text(messagePourUtilisateur(erreur, repli: repli))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controleur = ref.read(cartControllerProvider.notifier);
    final produit = ref
        .watch(productDetailProvider(item.productId))
        .valueOrNull;
    final variante = produit?.variants.firstWhereOrNull(
      (v) => v.id == item.variantId,
    );
    // Le stock de la variante quand la ligne en a une, celui du produit
    // sinon. `null` tant que le produit n'est pas chargé : la quantité reste
    // alors libre plutôt que bloquée sur une limite encore inconnue.
    final stock = variante?.stockQuantity ?? produit?.stockQuantity;
    final enRupture = stock != null && stock <= 0;
    final stockBas = stock != null && stock > 0 && stock <= 5;
    final quantite = item.quantity;

    return ShopProductListItem(
      onTap: () => context.push(AppRoutes.productDetail(item.productId)),
      data: ShopProductData(
        imagePath:
            variante?.imageUrls.firstOrNull ?? produit?.imageUrls.firstOrNull,
        brand: produit?.supplierName ?? '',
        title: item.productNameSnapshot,
        priceFcfa: ref.watch(cartLineUnitPriceProvider(item.id)),
        compareAtFcfa: ref.watch(cartLineCompareAtPriceProvider(item.id)),
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.variantNameSnapshot case final nom?)
            Row(
              children: [
                Flexible(
                  child: Text(
                    nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: ShopSizes.padding / 2),
                // Une autre taille, une autre couleur : c'est sur la fiche
                // qu'on la choisit.
                GestureDetector(
                  onTap: () =>
                      context.push(AppRoutes.productDetail(item.productId)),
                  child: const Text(
                    'Changer',
                    style: TextStyle(
                      color: ShopColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          // Le stock ne s'affiche que quand il change quelque chose : un
          // « 248 en stock » sous chaque article ne dit rien, un stock bas
          // invite à ne pas attendre, une rupture explique pourquoi la
          // quantité ne monte plus.
          if (enRupture || stockBas)
            Padding(
              padding: const EdgeInsets.only(top: ShopSizes.padding / 4),
              child: Text(
                enRupture ? 'Rupture de stock' : 'Plus que $stock en stock',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: enRupture ? ShopColors.error : ShopColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: ShopSizes.padding / 2),
          Row(
            children: [
              ShopQuantityStepper(
                label: null,
                compact: true,
                quantity: quantite,
                onDecrement: quantite > 1
                    ? () => _agir(
                        context,
                        () =>
                            controleur.updateQuantity(item.id, quantite - 1),
                        'La quantité n\'a pas pu être changée.',
                      )
                    : null,
                onIncrement: stock == null || quantite < stock
                    ? () => _agir(
                        context,
                        () =>
                            controleur.updateQuantity(item.id, quantite + 1),
                        'La quantité n\'a pas pu être changée.',
                      )
                    : null,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Retirer du panier',
                onPressed: () => _agir(
                  context,
                  () => controleur.removeItem(item.id),
                  'L\'article n\'a pas pu être retiré.',
                ),
                icon: const ShopIcon(ShopIcons.delete, color: ShopColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
