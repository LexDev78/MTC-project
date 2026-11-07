import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../widgets/shop_product_data.dart';
import 'catalog_providers.dart';

/// Le catalogue entier, sans aucun filtre : la matière de l'accueil.
///
/// Distinct de `productListProvider`, qui suit les filtres posés dans la
/// découverte : choisir une catégorie là-bas ne doit pas vider l'accueil.
final homeProductsProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchProducts();
});

/// Un produit en promotion, avec ce que l'accueil en dit.
typedef PromotedProduct = ({
  Product product,
  int percent,
  DateTime? endsAt,
  String? label,
});

/// Les sections de l'accueil du kit, tirées du catalogue.
///
/// Fonctions pures, sans `Ref` : chaque règle se teste sur une liste.
class HomeSections {
  HomeSections(List<Product> products, {DateTime? now})
    : _products = products,
      _now = now ?? DateTime.now();

  final List<Product> _products;
  final DateTime _now;

  static const _taille = 10;

  /// « Produits populaires » : la meilleure note d'abord, puis le plus
  /// d'avis — une note de 5 sur un seul avis ne passe pas devant 4,8 sur
  /// cinquante.
  List<Product> get popular {
    final tries = [..._products]
      ..sort((a, b) {
        final note = b.ratingAverage.compareTo(a.ratingAverage);
        return note != 0 ? note : b.ratingCount.compareTo(a.ratingCount);
      });
    return tries.take(_taille).toList();
  }

  /// « Les plus populaires » : les plus consultés.
  List<Product> get mostViewed {
    final tries = [..._products]
      ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
    return tries.take(_taille).toList();
  }

  /// Les produits dont une remise court en ce moment, la plus forte
  /// d'abord.
  List<PromotedProduct> get onSale {
    final liste = <PromotedProduct>[];
    for (final product in _products) {
      final remise = product.runningPromotion(_now);
      final pourcentage = product.shopData(_now).discountPercent;
      if (remise == null || pourcentage == null || pourcentage <= 0) continue;
      liste.add((
        product: product,
        percent: pourcentage,
        endsAt: remise.endsAt,
        label: remise.label,
      ));
    }
    liste.sort((a, b) => b.percent.compareTo(a.percent));
    return liste;
  }

  /// La vente flash : les remises qui ont une fin annoncée.
  List<PromotedProduct> get flashSale =>
      onSale.where((p) => p.endsAt != null && p.endsAt!.isAfter(_now)).toList();

  /// La fin la plus proche parmi les ventes flash — celle que le compte à
  /// rebours affiche.
  DateTime? get flashSaleEndsAt {
    final fins = flashSale.map((p) => p.endsAt!).toList()..sort();
    return fins.isEmpty ? null : fins.first;
  }

  List<Product> ofSupplierType(SupplierType type) =>
      _products.where((p) => p.supplierType == type).take(_taille).toList();
}
