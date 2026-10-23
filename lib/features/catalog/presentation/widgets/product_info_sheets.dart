import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/features/orders/domain/delivery_pricing.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart'
    show priorityOrderFeeFcfa;

import '../../domain/entities/product.dart';

/// « Détails du produit » (maquette « Product details » du kit) : la
/// description entière, les caractéristiques en liste, puis l'origine et
/// l'expédition.
Future<void> showProductDetailsSheet(BuildContext context, Product product) {
  return showShopSheet<void>(
    context,
    heightFactor: 0.92,
    child: ProductDetailsSheet(product: product),
  );
}

/// « Modes de livraison » (maquette « Shipping methods » du kit), d'après
/// ce que le fournisseur accepte pour ce produit.
Future<void> showDeliveryMethodsSheet(BuildContext context, Product product) {
  return showShopSheet<void>(
    context,
    heightFactor: 0.92,
    child: DeliveryMethodsSheet(product: product),
  );
}

/// « 1 kg », « 0,5 kg », « 25 kg ».
String _poids(double kg) {
  final texte = kg == kg.roundToDouble()
      ? kg.toStringAsFixed(0)
      : kg.toString().replaceAll('.', ',');
  return '$texte kg';
}

/// Le contenu de [showProductDetailsSheet].
class ProductDetailsSheet extends StatelessWidget {
  const ProductDetailsSheet({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final caracteristiques = product.characteristics.sortedBy(
      (c) => c.displayOrder,
    );
    return Column(
      children: [
        const SheetHeader(title: 'Détails du produit'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: ShopSizes.padding),
            child: DetailSections(
              sections: [
                DetailSection(
                  title: 'Description',
                  child: Text(product.description),
                ),
                if (caracteristiques.isNotEmpty)
                  DetailSection(
                    title: 'Caractéristiques',
                    child: BulletList([
                      for (final c in caracteristiques)
                        '${c.type.label} : ${c.options.sortedBy((o) => o.displayOrder).map((o) => o.value).join(', ')}',
                    ]),
                  ),
                DetailSection(
                  title: 'Informations',
                  child: Text(
                    [
                      'Catégorie : ${product.category.label}',
                      'Origine : ${product.region.label}',
                      'Poids : ${_poids(product.weightKg)}',
                      'Expédié depuis : ${product.city}',
                      'Vendu par : ${product.supplierName}',
                    ].join('\n'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Le contenu de [showDeliveryMethodsSheet].
class DeliveryMethodsSheet extends StatelessWidget {
  const DeliveryMethodsSheet({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final fourchette =
        '${CurrencyFormatter.formatFcfaCompact(homeDeliveryMinFeeFcfa)} – '
        '${CurrencyFormatter.formatFcfaCompact(homeDeliveryMaxFeeFcfa)}';
    final cartes = <Widget>[
      if (product.allowsMtcDelivery)
        ShippingMethodCard(
          accent: ShippingAccent.primary,
          icon: ShopIcons.standard,
          title: 'Livraison MTC',
          subtitle: 'Un livreur MTC, suivi en direct jusqu\'à votre porte.',
          rates: [
            ('Selon la distance et le poids :', fourchette),
            (
              'Commande prioritaire :',
              '+ ${CurrencyFormatter.formatFcfaCompact(priorityOrderFeeFcfa)}',
            ),
          ],
          footer: 'Le montant exact s\'affiche à la commande',
        ),
      if (product.allowsSelfDelivery)
        const ShippingMethodCard(
          accent: ShippingAccent.light,
          icon: ShopIcons.stores,
          title: 'Par la boutique',
          subtitle: 'La boutique vous contacte pour convenir de la livraison.',
          price: 'Gratuit',
          footer: 'Aucun frais de livraison MTC',
        ),
      // MTC va chercher le colis chez le fournisseur et l'apporte au point :
      // sans la livraison MTC, pas de point de livraison
      // (`CheckoutScreen`).
      if (product.allowsMtcDelivery)
        const ShippingMethodCard(
          title: 'Point de livraison',
          subtitle:
              'Retirez votre colis dans un point MTC de votre ville, au tarif '
              'de la livraison MTC.',
        ),
    ];

    return Column(
      children: [
        const SheetHeader(title: 'Modes de livraison'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.screenMargin,
              ShopSizes.padding,
              ShopSizes.screenMargin,
              ShopSizes.padding * 2,
            ),
            children: [
              for (final carte in cartes) ...[
                carte,
                const SizedBox(height: ShopSizes.padding),
              ],
              const SizedBox(height: ShopSizes.padding / 2),
              const Text(
                'Les frais exacts dépendent de votre adresse : ils s\'affichent '
                'avant le paiement.',
                style: TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: ShopSizes.padding / 2),
              Text(
                'Expédié depuis ${product.city} par ${product.supplierName}.',
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
