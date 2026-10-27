import 'package:flutter/material.dart';

import 'package:mtc_app/core/shop/shop.dart';

import '../support/shop_capture.dart';

// La galerie des fragments du côté client : chacun rendu en clair et en
// sombre, sans erreur ni débordement. Avec MTC_CAPTURES, les images vont
// dans build/captures/client/ pour la comparaison avec le kit.
const _bogolan = ShopProductData(
  imagePath: 'assets/images/products/textiles/fabric.jpg',
  brand: 'Bogolan Bamako',
  title: 'Tissu bogolan traditionnel, teint à la boue',
  priceFcfa: 12500,
  compareAtFcfa: 15000,
  discountPercent: 17,
);
const _miel = ShopProductData(
  imagePath: 'assets/images/products/alimentation/honey.jpg',
  brand: 'Coopérative de Kita',
  title: 'Miel pur de Kita',
  priceFcfa: 4500,
);

void main() {
  capturerEcran(
    'galerie_1',
    () => Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            OfferBannerStyle1(
              image: 'assets/images/products/textiles/fabric.jpg',
              text: 'Le meilleur du Mali,\nlivré chez vous',
              onTap: () {},
            ),
            const SectionTitle('Catégories'),
            ShopPillRow(
              children: [
                ShopPill(label: 'Toutes', active: true, onTap: () {}),
                ShopPill(label: 'Promotions', icon: ShopIcons.sale, active: false, onTap: () {}),
                ShopPill(label: 'Textiles', icon: ShopIcons.manWoman, active: false, onTap: () {}),
              ],
            ),
            ProductCarouselSection(
              title: 'Produits populaires',
              products: const [_bogolan, _miel, _bogolan],
              onTap: (_) {},
            ),
            ProductCarouselSection(
              title: 'Les plus populaires',
              secondary: true,
              products: const [_bogolan, _miel],
              onTap: (_) {},
            ),
            const ProductCarouselSection(
              title: 'Chargement',
              products: null,
              onTap: _rien,
            ),
          ],
        ),
      ),
    ),
  );

  capturerEcran(
    'galerie_2',
    () => Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            OfferBannerStyle2(
              image: 'assets/images/products/artisanat/mask.jpg',
              title: 'Vendredi\nfou',
              subtitle: 'Collection',
              discountPercent: 50,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            CountdownBanner(
              image: 'assets/images/products/electronique/solar_panel.jpg',
              text: 'Vente flash\n-50 %',
              endsAt: DateTime.now().add(const Duration(hours: 8)),
            ),
            const SizedBox(height: 8),
            const OfferBannerStyle5(
              image: 'assets/images/products/artisanat/basket.jpg',
              title: 'Nouveautés',
              subtitle: '-50 %',
              bottomText: 'COLLECTION',
            ),
            SectionTitle(
              'Vente flash',
              trailing: CountdownBoxes(
                endsAt: DateTime.now().add(const Duration(hours: 3)),
                style: CountdownStyle.outlined,
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: ShopSearchField(onFilterTap: _rien),
            ),
          ],
        ),
      ),
    ),
  );

  capturerEcran(
    'galerie_3',
    () => Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          children: [
            const ShopProductListItem(data: _bogolan),
            const Divider(height: 32),
            ShopProductListItem(
              data: _miel,
              trailing: ShopQuantityStepper(
                quantity: 2,
                label: null,
                compact: true,
                onIncrement: () {},
                onDecrement: () {},
              ),
            ),
            const SizedBox(height: 24),
            const OrderSummaryCard(
              title: 'Récapitulatif de la commande',
              rows: [
                SummaryRow(label: 'Sous-total', value: '17 000 FCFA'),
                SummaryRow(
                  label: 'Livraison',
                  value: 'Gratuite',
                  valueColor: ShopColors.success,
                ),
              ],
              totals: [
                SummaryRow(label: 'Total', value: '17 000 FCFA', emphasized: true),
              ],
            ),
            const SizedBox(height: 24),
            const OrderStatusCard(
              reference: '#B84BF036',
              placedOn: '18 oct. 2026',
              steps: [
                OrderStep('Passée', OrderStepState.done),
                OrderStep('Confirmée', OrderStepState.processing),
                OrderStep('Préparée', OrderStepState.notDoneYet),
                OrderStep('En route', OrderStepState.notDoneYet),
                OrderStep('Livrée', OrderStepState.notDoneYet),
              ],
              items: [ShopProductListItem(data: _bogolan)],
            ),
          ],
        ),
      ),
    ),
  );

  capturerEcran(
    'galerie_4',
    () => Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          children: [
            const RatingSummaryCard(
              rating: 4.6,
              reviewCount: 120,
              countsByStar: [80, 25, 10, 3, 2],
            ),
            const SizedBox(height: 16),
            const ReviewTile(
              author: 'Awa Traoré',
              timeAgo: 'il y a 2 h',
              rating: 4,
              comment: 'Tissu magnifique, couleurs fidèles aux photos.',
            ),
            const NotificationTile(
              icon: ShopIcons.delivery,
              color: ShopColors.primary,
              title: 'Votre commande Bogolan Bamako a été livrée.',
              timeAgo: 'il y a 2 min',
              unread: true,
            ),
            const StatusCountTile(
              icon: ShopIcons.delivery,
              label: 'Livrées',
              count: 5,
              color: ShopColors.price,
            ),
            const SizedBox(height: 16),
            const AddressCard(
              label: 'Maison',
              lines: ['Badalabougou, rue 136', 'Bamako', '+223 70 00 00 00'],
              isDefault: true,
            ),
            const SizedBox(height: 16),
            DashedButton(label: 'Ajouter une adresse', icon: ShopIcons.address, onTap: () {}),
            const SizedBox(height: 16),
            Row(
              children: [
                const AvailabilityTag(isAvailable: true),
                const SizedBox(width: 8),
                const ColorDot(color: Colors.red, isActive: true),
                const SizedBox(width: 8),
                SizeButton(text: 'M', isActive: true, onTap: () {}),
                const SizedBox(width: 8),
                SizeButton(text: 'XL', isActive: false, onTap: () {}),
              ],
            ),
            const ChevronListTile(icon: ShopIcons.order, title: 'Mes commandes'),
            const ChevronListTile(icon: ShopIcons.logout, title: 'Se déconnecter', danger: true),
          ],
        ),
      ),
      bottomNavigationBar: CartButton(priceFcfa: 12500, title: 'Acheter', onPressed: () {}),
    ),
  );
}

void _rien([int _ = 0]) {}
