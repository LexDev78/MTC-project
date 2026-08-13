import 'dart:async';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_status.dart';
import '../../domain/entities/stock_movement.dart';

/// Curated stock photos bundled as local assets (see `pubspec.yaml`), one
/// per product so the catalog isn't a wall of repeated images even though
/// several products in the same category share source photography.
abstract final class _ProductImages {
  static const _base = 'assets/images/products';

  static const fabric = '$_base/textiles/fabric.jpg';
  static const fabric2 = '$_base/textiles/fabric_2.jpg';
  static const mask = '$_base/artisanat/mask.jpg';
  static const basket = '$_base/artisanat/basket.jpg';
  static const basket2 = '$_base/artisanat/basket_2.jpg';
  static const smartphone = '$_base/electronique/smartphone.jpg';
  static const smartphone2 = '$_base/electronique/smartphone_2.jpg';
  static const solarPanel = '$_base/electronique/solar_panel.jpg';
  static const solarPanel2 = '$_base/electronique/solar_panel_2.jpg';
  static const speaker = '$_base/electronique/speaker.jpg';
  static const speaker2 = '$_base/electronique/speaker_2.jpg';
  static const radio = '$_base/electronique/radio.jpg';
  static const radio2 = '$_base/electronique/radio_2.jpg';
  static const rice = '$_base/alimentation/rice.jpg';
  static const rice2 = '$_base/alimentation/rice_2.jpg';
  static const millet = '$_base/alimentation/millet.jpg';
  static const millet2 = '$_base/alimentation/millet_2.jpg';
  static const oil = '$_base/alimentation/oil.jpg';
  static const oil2 = '$_base/alimentation/oil_2.jpg';
  static const honey = '$_base/alimentation/honey.jpg';
  static const honey2 = '$_base/alimentation/honey_2.jpg';
  static const cement = '$_base/materiaux/cement.jpg';
  static const corrugatedSheets = '$_base/materiaux/corrugated_sheets.jpg';
  static const corrugatedSheets2 = '$_base/materiaux/corrugated_sheets_2.jpg';
  static const steel = '$_base/materiaux/steel.jpg';
  static const steel2 = '$_base/materiaux/steel_2.jpg';
}

/// Seeded with realistic Malian products across every category. Products
/// from unverified/pending tiers suppliers (`isSupplierVerified: false`,
/// see `Artisanat Sikasso` below) are kept in the list on purpose — they
/// demonstrate that [InMemoryProductRepository] filters them out of every
/// client-facing query, matching the platform's verification-gates-
/// visibility rule.
class InMemoryProductDatasource {
  InMemoryProductDatasource() {
    _products.addAll(_seed());
  }

  final List<Product> _products = [];
  final List<StockMovement> _stockMovements = [];
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  final StreamController<void> _stockMovementsController =
      StreamController<void>.broadcast();

  Stream<List<Product>> watchAll() {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changesController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map((_) => List<Product>.unmodifiable(_products));
  }

  Product getById(String id) {
    return _products.firstWhere(
      (p) => p.id == id,
      orElse: () => throw NotFoundException('Produit introuvable : $id'),
    );
  }

  void updateSupplierRating(
    String supplierId,
    double ratingAverage,
    int ratingCount,
  ) {
    for (var i = 0; i < _products.length; i++) {
      if (_products[i].supplierId == supplierId) {
        _products[i] = _products[i].copyWith(
          ratingAverage: ratingAverage,
          ratingCount: ratingCount,
        );
      }
    }
    _changesController.add(null);
  }

  List<Product> watchMyProducts(String supplierId) {
    return _products.where((p) => p.supplierId == supplierId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Product add(Product product) {
    _products.add(product);
    _changesController.add(null);
    return product;
  }

  void update(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index == -1) {
      throw NotFoundException('Produit introuvable : ${product.id}');
    }
    _products[index] = product;
    _changesController.add(null);
  }

  void setStatus(String id, ProductStatus status) {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) throw NotFoundException('Produit introuvable : $id');
    _products[index] = _products[index].copyWith(status: status);
    _changesController.add(null);
  }

  void adjustStock(
    String id,
    int quantityDelta,
    StockMovementReason reason,
    String? note,
  ) {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) throw NotFoundException('Produit introuvable : $id');

    final newQuantity = _products[index].stockQuantity + quantityDelta;
    if (newQuantity < 0) {
      throw InsufficientStockException(
        'Stock insuffisant pour ${_products[index].name} : '
        '${_products[index].stockQuantity} disponible(s), '
        '${-quantityDelta} demandé(s).',
      );
    }

    _products[index] = _products[index].copyWith(stockQuantity: newQuantity);
    _stockMovements.add(
      StockMovement(
        id: IdGenerator.next(),
        productId: id,
        quantityDelta: quantityDelta,
        reason: reason,
        occurredAt: DateTime.now(),
        note: note,
      ),
    );
    _changesController.add(null);
    _stockMovementsController.add(null);
  }

  Stream<List<StockMovement>> watchStockMovements(String productId) {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _stockMovementsController.stream.listen(
        controller.add,
      );
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map((_) {
      final movements = _stockMovements
          .where((m) => m.productId == productId)
          .toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return List<StockMovement>.unmodifiable(movements);
    });
  }

  void updateSupplierVerification(String supplierId, bool isVerified) {
    for (var i = 0; i < _products.length; i++) {
      if (_products[i].supplierId == supplierId) {
        _products[i] = _products[i].copyWith(isSupplierVerified: isVerified);
      }
    }
    _changesController.add(null);
  }

  List<Product> _seed() {
    final now = DateTime.now();
    var idCounter = 0;
    String nextId() => 'product-${(++idCounter).toString().padLeft(3, '0')}';

    Product product({
      required String supplierId,
      required String supplierName,
      required SupplierType supplierType,
      required String name,
      required String description,
      required ProductCategory category,
      required int priceFcfa,
      required int stockQuantity,
      required String city,
      required double ratingAverage,
      required int ratingCount,
      required double weightKg,
      bool allowsSelfDelivery = true,
      bool allowsMtcDelivery = true,
      bool isSupplierVerified = true,
      List<String> imageUrls = const [],
      List<String> sizes = const [],
      List<String> colors = const [],
      ProductRegion region = ProductRegion.mali,
    }) {
      return Product(
        id: nextId(),
        supplierId: supplierId,
        supplierName: supplierName,
        supplierType: supplierType,
        name: name,
        description: description,
        category: category,
        priceFcfa: priceFcfa,
        stockQuantity: stockQuantity,
        imageUrls: imageUrls,
        city: city,
        ratingAverage: ratingAverage,
        ratingCount: ratingCount,
        allowsSelfDelivery: allowsSelfDelivery,
        allowsMtcDelivery: allowsMtcDelivery,
        weightKg: weightKg,
        isSupplierVerified: isSupplierVerified,
        createdAt: now,
        sizes: sizes,
        colors: colors,
        region: region,
      );
    }

    return [
      // Bogolan Bamako — verified, 4.6
      product(
        supplierId: DemoIds.supplierBogolanBamako,
        supplierName: 'Bogolan Bamako',
        supplierType: SupplierType.tiers,
        name: 'Tissu Bogolan traditionnel',
        description:
            'Tissu bogolan teint et peint à la main selon la tradition malienne, 2m x 1,5m.',
        category: ProductCategory.textilesBogolan,
        priceFcfa: 25000,
        stockQuantity: 40,
        city: 'Bamako',
        ratingAverage: 4.6,
        ratingCount: 132,
        weightKg: 0.6,
        imageUrls: const [_ProductImages.fabric, _ProductImages.fabric2],
        colors: const ['Marron', 'Ocre', 'Noir', 'Beige'],
      ),
      product(
        supplierId: DemoIds.supplierBogolanBamako,
        supplierName: 'Bogolan Bamako',
        supplierType: SupplierType.tiers,
        name: 'Boubou en bogolan brodé',
        description:
            'Boubou homme brodé main, tissu bogolan 100% coton, plusieurs tailles disponibles.',
        category: ProductCategory.textilesBogolan,
        priceFcfa: 45000,
        stockQuantity: 15,
        city: 'Bamako',
        ratingAverage: 4.6,
        ratingCount: 132,
        weightKg: 0.8,
        imageUrls: const [_ProductImages.fabric, _ProductImages.fabric2],
        sizes: const ['S', 'M', 'L', 'XL'],
        colors: const ['Marron', 'Noir', 'Ocre'],
      ),
      product(
        supplierId: DemoIds.supplierBogolanBamako,
        supplierName: 'Bogolan Bamako',
        supplierType: SupplierType.tiers,
        name: 'Sac en bogolan',
        description:
            'Sac à main artisanal en tissu bogolan doublé, fermeture éclair.',
        category: ProductCategory.textilesBogolan,
        priceFcfa: 15000,
        stockQuantity: 60,
        city: 'Bamako',
        ratingAverage: 4.6,
        ratingCount: 132,
        weightKg: 0.5,
        allowsMtcDelivery: false,
        imageUrls: const [_ProductImages.basket, _ProductImages.basket2],
        colors: const ['Marron', 'Noir'],
      ),
      product(
        supplierId: DemoIds.supplierBogolanBamako,
        supplierName: 'Bogolan Bamako',
        supplierType: SupplierType.tiers,
        name: 'Masque décoratif Bambara',
        description:
            'Masque décoratif en bois sculpté, style Bambara, pièce unique.',
        category: ProductCategory.artisanat,
        priceFcfa: 20000,
        stockQuantity: 20,
        city: 'Bamako',
        ratingAverage: 4.6,
        ratingCount: 132,
        weightKg: 1.5,
        imageUrls: const [_ProductImages.mask],
      ),

      // Tissus Mopti — verified, 4.4
      product(
        supplierId: DemoIds.supplierTissusMopti,
        supplierName: 'Tissus Mopti',
        supplierType: SupplierType.tiers,
        name: 'Pagne Wax 6 yards',
        description: 'Pagne wax haute qualité, 6 yards, motifs colorés.',
        category: ProductCategory.textilesBogolan,
        priceFcfa: 18000,
        stockQuantity: 80,
        city: 'Mopti',
        ratingAverage: 4.4,
        ratingCount: 76,
        weightKg: 0.9,
        imageUrls: const [_ProductImages.fabric, _ProductImages.fabric2],
        colors: const ['Rouge', 'Bleu', 'Jaune', 'Vert'],
      ),
      product(
        supplierId: DemoIds.supplierTissusMopti,
        supplierName: 'Tissus Mopti',
        supplierType: SupplierType.tiers,
        name: 'Foulard traditionnel',
        description: 'Foulard en coton local, teinture artisanale.',
        category: ProductCategory.textilesBogolan,
        priceFcfa: 8000,
        stockQuantity: 100,
        city: 'Mopti',
        ratingAverage: 4.4,
        ratingCount: 76,
        weightKg: 0.2,
        imageUrls: const [_ProductImages.fabric, _ProductImages.fabric2],
        colors: const ['Rouge', 'Bleu', 'Blanc'],
      ),
      product(
        supplierId: DemoIds.supplierTissusMopti,
        supplierName: 'Tissus Mopti',
        supplierType: SupplierType.tiers,
        name: 'Nappe brodée',
        description: 'Nappe de table brodée main, 8 personnes.',
        category: ProductCategory.textilesBogolan,
        priceFcfa: 22000,
        stockQuantity: 25,
        city: 'Mopti',
        ratingAverage: 4.4,
        ratingCount: 76,
        weightKg: 0.7,
        imageUrls: const [_ProductImages.fabric, _ProductImages.fabric2],
        colors: const ['Blanc', 'Beige'],
      ),

      // Artisanat Sikasso — PENDING verification -> hidden from clients
      product(
        supplierId: DemoIds.supplierArtisanatSikasso,
        supplierName: 'Artisanat Sikasso',
        supplierType: SupplierType.tiers,
        name: 'Masque en bois sculpté',
        description: 'Masque cérémoniel en bois local sculpté à la main.',
        category: ProductCategory.artisanat,
        priceFcfa: 35000,
        stockQuantity: 12,
        city: 'Sikasso',
        ratingAverage: 0,
        ratingCount: 0,
        weightKg: 2.0,
        isSupplierVerified: false,
        imageUrls: const [_ProductImages.mask],
      ),
      product(
        supplierId: DemoIds.supplierArtisanatSikasso,
        supplierName: 'Artisanat Sikasso',
        supplierType: SupplierType.tiers,
        name: 'Statuette Bambara',
        description: 'Statuette en bois dur, finition huilée.',
        category: ProductCategory.artisanat,
        priceFcfa: 28000,
        stockQuantity: 8,
        city: 'Sikasso',
        ratingAverage: 0,
        ratingCount: 0,
        weightKg: 3.0,
        isSupplierVerified: false,
        imageUrls: const [_ProductImages.mask],
      ),
      product(
        supplierId: DemoIds.supplierArtisanatSikasso,
        supplierName: 'Artisanat Sikasso',
        supplierType: SupplierType.tiers,
        name: 'Panier tressé',
        description: 'Panier tressé à la main en fibres naturelles.',
        category: ProductCategory.artisanat,
        priceFcfa: 6000,
        stockQuantity: 50,
        city: 'Sikasso',
        ratingAverage: 0,
        ratingCount: 0,
        weightKg: 0.8,
        isSupplierVerified: false,
        imageUrls: const [_ProductImages.basket, _ProductImages.basket2],
      ),

      // Electro Bamako — verified, 4.2
      product(
        supplierId: DemoIds.supplierElectroBamako,
        supplierName: 'Electro Bamako',
        supplierType: SupplierType.tiers,
        name: 'Smartphone Android 64GB',
        description:
            'Smartphone double SIM, 64GB, écran 6,5", garantie 12 mois.',
        category: ProductCategory.electronique,
        priceFcfa: 85000,
        stockQuantity: 30,
        city: 'Bamako',
        ratingAverage: 4.2,
        ratingCount: 54,
        weightKg: 0.3,
        imageUrls: const [
          _ProductImages.smartphone,
          _ProductImages.smartphone2,
        ],
        sizes: const ['64 Go', '128 Go'],
        colors: const ['Noir', 'Bleu', 'Or'],
        region: ProductRegion.chine,
      ),
      product(
        supplierId: DemoIds.supplierElectroBamako,
        supplierName: 'Electro Bamako',
        supplierType: SupplierType.tiers,
        name: 'Chargeur solaire portable',
        description: 'Panneau solaire pliable 20W avec batterie intégrée.',
        category: ProductCategory.electronique,
        priceFcfa: 12000,
        stockQuantity: 70,
        city: 'Bamako',
        ratingAverage: 4.2,
        ratingCount: 54,
        weightKg: 1.0,
        imageUrls: const [
          _ProductImages.solarPanel,
          _ProductImages.solarPanel2,
        ],
        sizes: const ['20W', '40W'],
        colors: const ['Noir'],
        region: ProductRegion.chine,
      ),
      product(
        supplierId: DemoIds.supplierElectroBamako,
        supplierName: 'Electro Bamako',
        supplierType: SupplierType.tiers,
        name: 'Radio FM à piles',
        description: 'Radio portable FM/AM, fonctionne à piles ou secteur.',
        category: ProductCategory.electronique,
        priceFcfa: 9500,
        stockQuantity: 45,
        city: 'Bamako',
        ratingAverage: 4.2,
        ratingCount: 54,
        weightKg: 0.7,
        allowsMtcDelivery: false,
        imageUrls: const [_ProductImages.radio, _ProductImages.radio2],
        colors: const ['Noir', 'Gris'],
        region: ProductRegion.chine,
      ),
      product(
        supplierId: DemoIds.supplierElectroBamako,
        supplierName: 'Electro Bamako',
        supplierType: SupplierType.tiers,
        name: 'Enceinte Bluetooth',
        description: 'Enceinte portable Bluetooth 10W, autonomie 8h.',
        category: ProductCategory.electronique,
        priceFcfa: 18000,
        stockQuantity: 35,
        city: 'Bamako',
        ratingAverage: 4.2,
        ratingCount: 54,
        weightKg: 0.9,
        imageUrls: const [_ProductImages.speaker, _ProductImages.speaker2],
        colors: const ['Noir', 'Rouge', 'Bleu'],
        region: ProductRegion.chine,
      ),

      // Alimentation Ségou — verified, 4.8
      product(
        supplierId: DemoIds.supplierAlimentationSegou,
        supplierName: 'Alimentation Ségou',
        supplierType: SupplierType.tiers,
        name: 'Riz local 25kg',
        description: 'Riz malien de qualité supérieure, sac de 25kg.',
        category: ProductCategory.alimentation,
        priceFcfa: 12500,
        stockQuantity: 200,
        city: 'Ségou',
        ratingAverage: 4.8,
        ratingCount: 210,
        weightKg: 25.0,
        imageUrls: const [_ProductImages.rice, _ProductImages.rice2],
      ),
      product(
        supplierId: DemoIds.supplierAlimentationSegou,
        supplierName: 'Alimentation Ségou',
        supplierType: SupplierType.tiers,
        name: 'Mil (sac 50kg)',
        description: 'Mil local, sac de 50kg, récolte récente.',
        category: ProductCategory.alimentation,
        priceFcfa: 18000,
        stockQuantity: 150,
        city: 'Ségou',
        ratingAverage: 4.8,
        ratingCount: 210,
        weightKg: 50.0,
        imageUrls: const [_ProductImages.millet, _ProductImages.millet2],
      ),
      product(
        supplierId: DemoIds.supplierAlimentationSegou,
        supplierName: 'Alimentation Ségou',
        supplierType: SupplierType.tiers,
        name: "Huile d'arachide 5L",
        description:
            "Huile d'arachide pure, pressée à froid, bidon de 5 litres.",
        category: ProductCategory.alimentation,
        priceFcfa: 7500,
        stockQuantity: 90,
        city: 'Ségou',
        ratingAverage: 4.8,
        ratingCount: 210,
        weightKg: 4.6,
        imageUrls: const [_ProductImages.oil, _ProductImages.oil2],
      ),
      product(
        supplierId: DemoIds.supplierAlimentationSegou,
        supplierName: 'Alimentation Ségou',
        supplierType: SupplierType.tiers,
        name: 'Miel pur de brousse 1L',
        description: 'Miel artisanal récolté en brousse, pot de 1 litre.',
        category: ProductCategory.alimentation,
        priceFcfa: 6000,
        stockQuantity: 60,
        city: 'Ségou',
        ratingAverage: 4.8,
        ratingCount: 210,
        weightKg: 1.3,
        imageUrls: const [_ProductImages.honey, _ProductImages.honey2],
      ),

      // Matériaux Koutiala — verified, 3.9
      product(
        supplierId: DemoIds.supplierMateriauxKoutiala,
        supplierName: 'Matériaux Koutiala',
        supplierType: SupplierType.tiers,
        name: 'Ciment (sac 50kg)',
        description: 'Ciment CPJ 32,5, sac de 50kg.',
        category: ProductCategory.materiauxConstruction,
        priceFcfa: 5000,
        stockQuantity: 500,
        city: 'Koutiala',
        ratingAverage: 3.9,
        ratingCount: 41,
        weightKg: 50.0,
        imageUrls: const [_ProductImages.cement],
        region: ProductRegion.afriqueHorsMali,
      ),
      product(
        supplierId: DemoIds.supplierMateriauxKoutiala,
        supplierName: 'Matériaux Koutiala',
        supplierType: SupplierType.tiers,
        name: 'Tôles ondulées (unité)',
        description: 'Tôle galvanisée ondulée, 2m, épaisseur 0,4mm.',
        category: ProductCategory.materiauxConstruction,
        priceFcfa: 8500,
        stockQuantity: 120,
        city: 'Koutiala',
        ratingAverage: 3.9,
        ratingCount: 41,
        weightKg: 6.0,
        imageUrls: const [
          _ProductImages.corrugatedSheets,
          _ProductImages.corrugatedSheets2,
        ],
        region: ProductRegion.afriqueHorsMali,
      ),
      product(
        supplierId: DemoIds.supplierMateriauxKoutiala,
        supplierName: 'Matériaux Koutiala',
        supplierType: SupplierType.tiers,
        name: 'Fer à béton 12mm (barre)',
        description: 'Barre de fer à béton torsadé, diamètre 12mm, 6m.',
        category: ProductCategory.materiauxConstruction,
        priceFcfa: 6500,
        stockQuantity: 300,
        city: 'Koutiala',
        ratingAverage: 3.9,
        ratingCount: 41,
        weightKg: 5.3,
        allowsMtcDelivery: false,
        imageUrls: const [_ProductImages.steel, _ProductImages.steel2],
        region: ProductRegion.afriqueHorsMali,
      ),

      // MTC Officiel — principal
      product(
        supplierId: DemoIds.supplierMtcOfficiel,
        supplierName: 'MTC Officiel',
        supplierType: SupplierType.principal,
        name: 'Kit solaire MTC 100W',
        description:
            'Kit solaire complet 100W avec batterie et régulateur, garantie MTC 24 mois.',
        category: ProductCategory.electronique,
        priceFcfa: 95000,
        stockQuantity: 25,
        city: 'Bamako',
        ratingAverage: 4.9,
        ratingCount: 340,
        weightKg: 8.0,
        allowsMtcDelivery: false,
        imageUrls: const [
          _ProductImages.solarPanel,
          _ProductImages.solarPanel2,
        ],
        sizes: const ['100W', '200W'],
        colors: const ['Noir'],
        region: ProductRegion.europe,
      ),
      product(
        supplierId: DemoIds.supplierMtcOfficiel,
        supplierName: 'MTC Officiel',
        supplierType: SupplierType.principal,
        name: 'Sac de riz MTC Premium 25kg',
        description:
            'Riz premium sélectionné et conditionné par MTC, sac de 25kg.',
        category: ProductCategory.alimentation,
        priceFcfa: 14000,
        stockQuantity: 100,
        city: 'Bamako',
        ratingAverage: 4.9,
        ratingCount: 340,
        weightKg: 25.0,
        allowsMtcDelivery: false,
        imageUrls: const [_ProductImages.rice, _ProductImages.rice2],
      ),
      product(
        supplierId: DemoIds.supplierMtcOfficiel,
        supplierName: 'MTC Officiel',
        supplierType: SupplierType.principal,
        name: 'Pagne MTC édition limitée',
        description:
            'Pagne exclusif MTC, édition limitée, tissage haut de gamme.',
        category: ProductCategory.textilesBogolan,
        priceFcfa: 30000,
        stockQuantity: 40,
        city: 'Bamako',
        ratingAverage: 4.9,
        ratingCount: 340,
        weightKg: 0.9,
        allowsMtcDelivery: false,
        imageUrls: const [_ProductImages.fabric, _ProductImages.fabric2],
        colors: const ['Bleu', 'Vert', 'Or'],
      ),
      product(
        supplierId: DemoIds.supplierMtcOfficiel,
        supplierName: 'MTC Officiel',
        supplierType: SupplierType.principal,
        name: 'Ciment MTC Pro (sac 50kg)',
        description: 'Ciment haute résistance distribué par MTC, sac de 50kg.',
        category: ProductCategory.materiauxConstruction,
        priceFcfa: 5200,
        stockQuantity: 400,
        city: 'Bamako',
        ratingAverage: 4.9,
        ratingCount: 340,
        weightKg: 50.0,
        allowsMtcDelivery: false,
        imageUrls: const [_ProductImages.cement],
      ),
    ];
  }
}
