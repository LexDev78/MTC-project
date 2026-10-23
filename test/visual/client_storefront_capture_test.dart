import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/ratings/domain/entities/review.dart';
import 'package:mtc_app/features/ratings/presentation/providers/review_providers.dart';
import 'package:mtc_app/features/suppliers/domain/entities/supplier_profile.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/screens/shops_screen.dart';
import 'package:mtc_app/features/suppliers/presentation/screens/supplier_profile_screen.dart';

import '../support/shop_capture.dart';
import '../support/shop_fixtures.dart';

const _boutique = SupplierProfile(
  id: 'f-Atelier de Mopti',
  businessName: 'Atelier de Mopti',
  supplierType: SupplierType.tiers,
  city: 'Mopti',
  ratingAverage: 4.7,
  ratingCount: 23,
  productCount: 2,
  listedProductCount: 2,
  verificationStatus: VerificationStatus.verified,
  description:
      'Masques, paniers et sculptures du pays dogon, faits main par les '
      'artisans de l\'atelier depuis 1998.',
  fullAddress: 'Quartier Komoguel, près du port, Mopti',
  openingHoursLabel: 'Lun.–sam., 8 h – 18 h',
  publicPhoneNumbers: ['+223 76 12 34 56'],
  deliveryZones: ['Mopti', 'Sévaré', 'Bamako'],
);

Review _avis(String id, int etoiles, String texte, {String? reponse}) => Review(
  id: id,
  orderId: 'cmd-$id',
  supplierGroupId: 'g-$id',
  clientId: 'client-$id',
  supplierId: _boutique.id,
  stars: etoiles,
  comment: texte,
  createdAt: maintenant.subtract(const Duration(days: 3)),
  supplierReply: reponse,
);

List<Override> _donnees({List<Review>? avis}) {
  final produits = [
    for (final p in catalogueDemo())
      if (p.supplierName == _boutique.businessName) p,
  ];
  return [
    supplierDetailProvider(_boutique.id).overrideWith((ref) async => _boutique),
    supplierProductsProvider(
      _boutique.id,
    ).overrideWith((ref) => Stream.value(produits)),
    supplierReviewsProvider(_boutique.id).overrideWith(
      (ref) => Stream.value(
        avis ??
            [
              _avis(
                'a1',
                5,
                'Masque superbe, emballé avec soin.',
                reponse: 'Merci ! Le sculpteur sera ravi.',
              ),
              _avis('a2', 4, 'Panier solide, un peu plus petit que prévu.'),
            ],
      ),
    ),
  ];
}

/// « Boutiques du Mali » : la liste telle que le provider la rend (MTC
/// Officiel d'abord, puis les plus suivies).
final _boutiques = [
  const SupplierProfile(
    id: 'mtc',
    businessName: 'MTC Officiel',
    supplierType: SupplierType.principal,
    city: 'Bamako',
    ratingAverage: 4.9,
    ratingCount: 340,
    productCount: 4,
    listedProductCount: 4,
  ),
  const SupplierProfile(
    id: 'segou',
    businessName: 'Alimentation Ségou',
    supplierType: SupplierType.tiers,
    city: 'Ségou',
    ratingAverage: 4.8,
    ratingCount: 210,
    productCount: 4,
    listedProductCount: 4,
    verificationStatus: VerificationStatus.verified,
  ),
  const SupplierProfile(
    id: 'electro',
    businessName: 'Electro Bamako',
    supplierType: SupplierType.tiers,
    city: 'Bamako',
    ratingAverage: 4.2,
    ratingCount: 54,
    productCount: 4,
    listedProductCount: 4,
    verificationStatus: VerificationStatus.verified,
    isOpen: false,
  ),
  _boutique.copyWith(ratingCount: 23),
  const SupplierProfile(
    id: 'koutiala',
    businessName: 'Matériaux Koutiala',
    supplierType: SupplierType.tiers,
    city: 'Koutiala',
    ratingAverage: 0,
    ratingCount: 0,
    productCount: 1,
    listedProductCount: 1,
    verificationStatus: VerificationStatus.verified,
  ),
];

List<Override> _liste() => [
  listedShopsProvider.overrideWith((ref) async => _boutiques),
];

void main() {
  capturerEcran('boutiques', () => const ShopsScreen(), overrides: _liste);
  capturerEcran(
    'boutiques_page',
    () => const ShopsScreen(),
    overrides: _liste,
    hauteur: 1100,
  );
  capturerEcran(
    'boutiques_recherche_vide',
    () => const ShopsScreen(),
    overrides: _liste,
    geste: (tester) async {
      await tester.enterText(find.byType(TextField), 'Tombouctou');
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
  capturerEcran(
    'boutique',
    () => SupplierProfileScreen(supplierId: _boutique.id),
    overrides: _donnees,
    hauteur: 1700,
  );
  capturerEcran(
    'boutique_sans_avis',
    () => SupplierProfileScreen(supplierId: _boutique.id),
    overrides: () => _donnees(avis: const []),
  );
}
