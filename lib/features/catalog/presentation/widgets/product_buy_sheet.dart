import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/domain/entities/cart_item.dart';
import 'package:mtc_app/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/bookmark_button.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_characteristic.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/promotion_pricing.dart';
import '../providers/product_selection.dart';
import 'option_colors.dart';
import 'product_info_sheets.dart';
import 'shop_product_data.dart';

/// Ouvre la feuille d'achat (`ProductBuyNowScreen` du kit) : quantité,
/// variante, prix total, et l'ajout au panier.
Future<void> showProductBuySheet(BuildContext context, Product product) {
  return showShopSheet<void>(
    context,
    heightFactor: 0.92,
    child: ProductBuySheet(product: product),
  );
}

/// Vide la pile des feuilles ouvertes au-dessus de la fiche.
void _fermerLesFeuilles(BuildContext context) =>
    Navigator.of(context).popUntil((route) => route is! PopupRoute);

class ProductBuySheet extends ConsumerWidget {
  const ProductBuySheet({super.key, required this.product});

  final Product product;

  void _signaler(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _ajouterAuPanier(
    BuildContext context,
    WidgetRef ref,
    int quantite,
    ProductVariant? variante,
  ) async {
    if (ref.read(currentUserProvider).valueOrNull == null) {
      _signaler(context, 'Connectez-vous pour remplir votre panier.');
      return;
    }
    await ref
        .read(cartControllerProvider.notifier)
        .addProduct(product, quantity: quantite, variant: variante);
    if (!context.mounted) return;
    final etat = ref.read(cartControllerProvider);
    if (etat.hasError) {
      _signaler(
        context,
        messagePourUtilisateur(
          etat.error,
          repli: 'L\'article n\'a pas pu être ajouté au panier.',
        ),
      );
      return;
    }
    unawaited(
      showShopSheet<void>(
        context,
        isDismissible: false,
        child: const AddedToCartSheet(),
      ),
    );
  }

  /// L'achat immédiat de MTC : la commande ne porte que sur cet article, et
  /// le reste du panier n'est pas touché (`buyNowItemProvider`).
  void _acheterMaintenant(
    BuildContext context,
    WidgetRef ref,
    int quantite,
    int prixUnitaire,
    ProductVariant? variante,
  ) {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      _signaler(context, 'Connectez-vous pour commander.');
      return;
    }
    // Le prix de base de la variante, comme le panier : la remise se
    // recalcule au paiement, et en base à la commande.
    ref.read(buyNowItemProvider.notifier).state = CartItem(
      id: 'buy-now-${product.id}',
      userId: user.id,
      productId: product.id,
      supplierId: product.supplierId,
      productNameSnapshot: product.name,
      unitPriceFcfaSnapshot: prixUnitaire,
      quantity: quantite,
      addedAt: DateTime.now(),
      variantId: variante?.id,
      variantNameSnapshot: variante?.name,
    );
    final router = GoRouter.of(context);
    _fermerLesFeuilles(context);
    unawaited(router.push(AppRoutes.clientCheckout));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantite = ref.watch(productQuantityProvider(product.id));
    final variantId = ref.watch(productVariantIdProvider(product.id));
    final picks = ref.watch(productPicksProvider(product.id));
    final enCours = ref.watch(cartControllerProvider).isLoading;
    final variante = product.variants.firstWhereOrNull(
      (v) => v.id == variantId,
    );
    final base = variante?.priceFcfa ?? product.priceFcfa;
    final stock = variante?.stockQuantity ?? product.stockQuantity;
    final prix = product.unitPricing(basePriceFcfa: base, quantity: quantite);

    // La variante choisie peut être épuisée quand le produit ne l'est pas :
    // on le dit sur le bouton, le prix restant lisible.
    final varianteEpuisee =
        product.hasVariants && (variante?.stockQuantity ?? 0) <= 0;
    // Une variante qui regroupe plusieurs tailles attend qu'on en touche
    // une : le fournisseur ne saurait pas laquelle expédier.
    final aTrancher = variante == null
        ? null
        : product.characteristics
              .sortedBy((c) => c.displayOrder)
              .firstWhereOrNull(
                (c) =>
                    (optionsByCharacteristic(variante)[c.id]?.length ?? 0) >
                        1 &&
                    !picks.containsKey(c.id),
              );
    final bloque = stock <= 0 || varianteEpuisee || aTrancher != null;
    // Réduite à ce que le client a choisi (« Noir 46 ») : c'est elle, et
    // non la variante groupée du fournisseur, qui part au panier.
    final aAcheter = variante == null
        ? null
        : resolveVariantForPurchase(variante, picks, product.characteristics);
    final photo =
        variante?.imageUrls.firstOrNull ?? product.imageUrls.firstOrNull;

    return Scaffold(
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.padding,
              ShopSizes.padding / 2,
              ShopSizes.padding,
              0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: bloque || enCours
                    ? null
                    : () => _acheterMaintenant(
                        context,
                        ref,
                        quantite,
                        aAcheter?.priceFcfa ?? product.priceFcfa,
                        aAcheter,
                      ),
                child: const Text('Acheter maintenant'),
              ),
            ),
          ),
          CartButton(
            priceFcfa: prix.priceFcfa * quantite,
            title: varianteEpuisee
                ? 'Variante en rupture'
                : aTrancher != null
                ? 'Choisir : ${aTrancher.type.label.toLowerCase()}'
                : 'Ajouter au panier',
            subtitle: 'Prix total',
            isLoading: enCours,
            onPressed: bloque
                ? null
                : () => _ajouterAuPanier(context, ref, quantite, aAcheter),
          ),
        ],
      ),
      body: Column(
        children: [
          SheetHeader(
            title: product.name,
            action: BookmarkButton(productId: product.id),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ShopSizes.padding,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.05,
                      child: ShopImage(photo, cacheWidth: 800),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(ShopSizes.padding),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ShopUnitPrice(
                            priceFcfa: prix.priceFcfa,
                            compareAtFcfa: prix.compareAtFcfa,
                            footer: _StockEtRemise(
                              product: product,
                              basePriceFcfa: base,
                              quantite: quantite,
                              stock: stock,
                            ),
                          ),
                        ),
                        const SizedBox(width: ShopSizes.padding / 2),
                        ShopQuantityStepper(
                          quantity: quantite,
                          onDecrement: quantite > 1
                              ? () => ref
                                    .read(
                                      productQuantityProvider(
                                        product.id,
                                      ).notifier,
                                    )
                                    .state--
                              : null,
                          onIncrement: quantite < stock
                              ? () => ref
                                    .read(
                                      productQuantityProvider(
                                        product.id,
                                      ).notifier,
                                    )
                                    .state++
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider()),
                if (product.hasVariants)
                  SliverToBoxAdapter(child: _ChoixDeVariante(product: product)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    vertical: ShopSizes.padding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: ChevronListTile(
                      title: 'Détails du produit',
                      icon: ShopIcons.product,
                      fontSize: 16,
                      dividerAbove: true,
                      onTap: () => showProductDetailsSheet(context, product),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ShopSizes.padding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: ShopSizes.padding / 2),
                        Text(
                          'Livraison depuis ${product.city}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: ShopSizes.padding / 2),
                        const Text(
                          'Les frais se calculent à la commande, selon votre '
                          'adresse et le mode choisi.',
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    vertical: ShopSizes.padding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: ChevronListTile(
                      title: 'Modes de livraison',
                      icon: ShopIcons.delivery,
                      fontSize: 16,
                      dividerAbove: true,
                      onTap: () => showDeliveryMethodsSheet(context, product),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: ShopSizes.padding),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sous le prix : le stock de la variante, la remise appliquée, et le
/// palier suivant à atteindre.
///
/// L'incitation (« Encore 3 unités pour… ») vaut d'être montrée : une remise
/// sur quantité que personne ne voit ne fait pas vendre une unité de plus.
class _StockEtRemise extends StatelessWidget {
  const _StockEtRemise({
    required this.product,
    required this.basePriceFcfa,
    required this.quantite,
    required this.stock,
  });

  final Product product;
  final int basePriceFcfa;
  final int quantite;
  final int stock;

  @override
  Widget build(BuildContext context) {
    final appliquee = bestPromotionFor(
      promotions: product.promotions,
      basePriceFcfa: basePriceFcfa,
      quantity: quantite,
    );
    final palier = nextQuantityStep(
      promotions: product.promotions,
      basePriceFcfa: basePriceFcfa,
      quantity: quantite,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stock > 0 ? '$stock en stock' : 'Variante en rupture',
          style: TextStyle(color: stock > 0 ? null : ShopColors.error),
        ),
        if (appliquee != null) ...[
          const SizedBox(height: ShopSizes.padding / 2),
          _PastilleRemise(promotion: appliquee),
        ],
        if (palier != null) ...[
          const SizedBox(height: ShopSizes.padding / 2),
          Text(
            'Encore ${palier.unitsMissing} '
            '${palier.unitsMissing > 1 ? 'unités' : 'unité'} pour '
            '${CurrencyFormatter.formatFcfa(priceUnderPromotion(basePriceFcfa: basePriceFcfa, promotion: palier.promotion))} '
            'l\'unité',
            style: const TextStyle(
              color: ShopColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// La remise en cours, avec sa condition : une remise annoncée sans elle
/// (« dès 10 ») serait une promesse que le panier ne tiendrait pas.
class _PastilleRemise extends StatelessWidget {
  const _PastilleRemise({required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    final montant = switch (promotion.kind) {
      PromotionKind.percentage => '-${promotion.value} %',
      PromotionKind.fixedAmount =>
        '-${CurrencyFormatter.formatFcfaCompact(promotion.value)}',
    };
    final condition = promotion.minQuantity > 1
        ? ' dès ${promotion.minQuantity}'
        : '';
    final libelle = promotion.label?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ShopSizes.padding / 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: ShopColors.error,
        borderRadius: BorderRadius.circular(ShopSizes.radius),
      ),
      child: Text(
        '$montant$condition${libelle.isEmpty ? '' : ' · $libelle'}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Les choix d'un produit à variantes : une rangée de pastilles pour la
/// `couleur`, des boutons ronds pour le reste (taille, stockage, poids…).
///
/// Une valeur n'est touchable que si une variante la porte *avec* ce qui
/// est déjà choisi ailleurs : prendre « Rouge » réduit les tailles à celles
/// qui existent en rouge. Avant tout choix, la condition est vraie d'office,
/// et seules les valeurs qu'aucune variante ne porte restent estompées.
class _ChoixDeVariante extends ConsumerWidget {
  const _ChoixDeVariante({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variantId = ref.watch(productVariantIdProvider(product.id));
    final picks = ref.watch(productPicksProvider(product.id));
    final variante = product.variants.firstWhereOrNull(
      (v) => v.id == variantId,
    );
    final selection = variante == null
        ? const <String, Set<String>>{}
        : optionsByCharacteristic(variante);

    void choisir(String caracteristique, String option) {
      ref.read(productPicksProvider(product.id).notifier).state = {
        ...ref.read(productPicksProvider(product.id)),
        caracteristique: option,
      };
    }

    void aller(String caracteristique, String option) {
      final cible = variantForOption(
        product,
        caracteristique,
        option,
        selection,
      );
      if (cible == null) return;
      // Le geste est noté *avant* le changement de variante : celui-ci
      // recalcule les choix pour la nouvelle variante (`derivePicks`), et
      // quand elle regroupe elle aussi plusieurs valeurs de cette
      // caractéristique, seul un choix déjà posé peut être reporté. Sans
      // cela, le premier toucher semblait sans effet.
      choisir(caracteristique, option);
      ref.read(productVariantIdProvider(product.id).notifier).state = cible.id;
    }

    bool accessible(String caracteristique, String option) {
      return product.variants.any((v) {
        final parCaracteristique = optionsByCharacteristic(v);
        if (!(parCaracteristique[caracteristique]?.contains(option) ??
            false)) {
          return false;
        }
        return selection.entries
            .where((e) => e.key != caracteristique)
            .every(
              (e) => e.value.any(
                (o) => parCaracteristique[e.key]?.contains(o) ?? false,
              ),
            );
      });
    }

    final groupes = <Widget>[];
    for (final c in product.characteristics.sortedBy((c) => c.displayOrder)) {
      final propres = selection[c.id] ?? const <String>{};
      // La variante choisie liste plusieurs valeurs ici (42/46/48 vendues
      // ensemble) : les toucher ne change pas de variante, cela dit
      // laquelle le client veut.
      final groupee = propres.length > 1;
      final choisie = picks[c.id];
      final allumees = groupee
          ? (choisie != null ? {choisie} : const <String>{})
          : propres;

      void toucher(String option) =>
          propres.contains(option) ? choisir(c.id, option) : aller(c.id, option);

      final options = c.options.sortedBy((o) => o.displayOrder);
      final aide = groupee && choisie == null
          ? Text(
              'Choisissez une valeur.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ShopColors.error),
            )
          : null;

      groupes.add(
        c.type.id == 'couleur'
            ? ShopOptionGroup(
                title: c.type.label,
                scrollable: true,
                footer: aide,
                children: [
                  for (final o in options)
                    ColorOption(
                      label: o.value,
                      color:
                          teinteDeCouleur(o.value) ??
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      image: _photoDeLaCouleur(c, o),
                      isActive: allumees.contains(o.id),
                      onTap: accessible(c.id, o.id)
                          ? () => toucher(o.id)
                          : null,
                    ),
                ],
              )
            : ShopOptionGroup(
                title: c.type.label,
                footer: aide,
                children: [
                  for (final o in options)
                    Opacity(
                      opacity: accessible(c.id, o.id) ? 1 : 0.35,
                      child: SizeButton(
                        text: o.value,
                        uppercase: false,
                        isActive: allumees.contains(o.id),
                        onTap: accessible(c.id, o.id)
                            ? () => toucher(o.id)
                            : null,
                      ),
                    ),
                ],
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupes,
    );
  }

  /// La photo propre à une couleur, si une variante qui la porte en a une.
  /// Pas la photo du produit en repli : la même image sur chaque pastille
  /// ne dirait rien de la couleur.
  Widget? _photoDeLaCouleur(
    ProductCharacteristic caracteristique,
    ProductCharacteristicOption option,
  ) {
    final photo = product.variants
        .firstWhereOrNull(
          (v) =>
              v.imageUrls.isNotEmpty &&
              v.optionRefs.any(
                (r) =>
                    r.characteristicId == caracteristique.id &&
                    r.optionId == option.id,
              ),
        )
        ?.imageUrls
        .first;
    return photo == null ? null : ShopImage(photo, radius: 20, cacheWidth: 120);
  }
}

/// Après l'ajout (`AddedToCartMessageScreen` du kit).
class AddedToCartSheet extends ConsumerWidget {
  const AddedToCartSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: IllustratedMessage(
          illustration: ShopIllustration.addedToCart,
          title: 'Ajouté au panier',
          message: 'Touchez « Commander » pour finaliser votre achat.',
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () {
                  final router = GoRouter.of(context);
                  _fermerLesFeuilles(context);
                  router.go(AppRoutes.clientHome);
                },
                child: const Text('Continuer mes achats'),
              ),
              const SizedBox(height: ShopSizes.padding),
              ElevatedButton(
                onPressed: () {
                  final router = GoRouter.of(context);
                  // Le panier entier, comme son propre bouton « Commander » :
                  // un achat immédiat resté en attente ne doit pas passer
                  // devant.
                  ref.read(buyNowItemProvider.notifier).state = null;
                  _fermerLesFeuilles(context);
                  unawaited(router.push(AppRoutes.clientCheckout));
                },
                child: const Text('Commander'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
