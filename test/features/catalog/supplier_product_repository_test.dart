import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/catalog/data/datasources/in_memory_product_datasource.dart';
import 'package:mtc_app/features/catalog/data/repositories/in_memory_product_repository.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_status.dart';
import 'package:mtc_app/features/catalog/domain/entities/stock_movement.dart';

void main() {
  late InMemoryProductRepository repository;

  setUp(() {
    repository = InMemoryProductRepository(InMemoryProductDatasource());
  });

  Future<String> createDraftProduct({
    String supplierId = DemoIds.supplierBogolanBamako,
    int stockQuantity = 10,
  }) async {
    final product = await repository.createProduct(
      supplierId: supplierId,
      supplierName: 'Bogolan Bamako',
      supplierType: SupplierType.tiers,
      isSupplierVerified: true,
      name: 'Nouveau tissu',
      description: 'Un tissu fraîchement ajouté.',
      category: ProductCategory.textilesBogolan,
      priceFcfa: 10000,
      stockQuantity: stockQuantity,
      weightKg: 0.5,
      city: 'Bamako',
      imageUrls: const [],
      allowsSelfDelivery: true,
      allowsMtcDelivery: true,
      sizes: const [],
      colors: const [],
      region: ProductRegion.mali,
    );
    return product.id;
  }

  test(
    'watchMyProducts shows every one of a supplier\'s products, including '
    'unverified/non-active ones the client-facing query hides',
    () async {
      final mine = await repository
          .watchMyProducts(DemoIds.supplierArtisanatSikasso)
          .first;

      expect(mine, hasLength(3));
      expect(mine.every((p) => !p.isSupplierVerified), isTrue);

      final visibleToClients = await repository
          .watchProducts(supplierId: DemoIds.supplierArtisanatSikasso)
          .first;
      expect(visibleToClients, isEmpty);
    },
  );

  test('a newly created product starts as draft, hidden from clients', () async {
    final id = await createDraftProduct();

    final product = await repository.getById(id);
    expect(product.status, ProductStatus.draft);

    final visibleToClients = await repository
        .watchProducts(supplierId: DemoIds.supplierBogolanBamako)
        .first;
    expect(visibleToClients.any((p) => p.id == id), isFalse);
  });

  test(
    'activating a draft product makes it appear in the client-facing query',
    () async {
      final id = await createDraftProduct();
      await repository.setStatus(id: id, status: ProductStatus.active);

      final visibleToClients = await repository
          .watchProducts(supplierId: DemoIds.supplierBogolanBamako)
          .first;
      expect(visibleToClients.any((p) => p.id == id), isTrue);
    },
  );

  test('updateProduct replaces the stored record', () async {
    final id = await createDraftProduct();
    final original = await repository.getById(id);

    await repository.updateProduct(
      original.copyWith(name: 'Nom modifié', priceFcfa: 12000),
    );

    final updated = await repository.getById(id);
    expect(updated.name, 'Nom modifié');
    expect(updated.priceFcfa, 12000);
  });

  group('adjustStock', () {
    test('increases stock and records a movement', () async {
      final id = await createDraftProduct(stockQuantity: 10);

      await repository.adjustStock(
        id: id,
        quantityDelta: 5,
        reason: StockMovementReason.restock,
        note: 'Livraison fournisseur',
      );

      final product = await repository.getById(id);
      expect(product.stockQuantity, 15);

      final movements = await repository.watchStockMovements(id).first;
      expect(movements, hasLength(1));
      expect(movements.single.quantityDelta, 5);
      expect(movements.single.reason, StockMovementReason.restock);
      expect(movements.single.note, 'Livraison fournisseur');
    });

    test('decreases stock down to exactly zero', () async {
      final id = await createDraftProduct(stockQuantity: 10);

      await repository.adjustStock(
        id: id,
        quantityDelta: -10,
        reason: StockMovementReason.sale,
      );

      final product = await repository.getById(id);
      expect(product.stockQuantity, 0);
    });

    test('throws InsufficientStockException rather than going negative', () async {
      final id = await createDraftProduct(stockQuantity: 3);

      expect(
        () => repository.adjustStock(
          id: id,
          quantityDelta: -4,
          reason: StockMovementReason.sale,
        ),
        throwsA(isA<InsufficientStockException>()),
      );

      final product = await repository.getById(id);
      expect(product.stockQuantity, 3, reason: 'stock must be unchanged');
    });

    test('newest movement is listed first', () async {
      final id = await createDraftProduct(stockQuantity: 10);

      await repository.adjustStock(
        id: id,
        quantityDelta: 5,
        reason: StockMovementReason.restock,
      );
      await repository.adjustStock(
        id: id,
        quantityDelta: -2,
        reason: StockMovementReason.sale,
      );

      final movements = await repository.watchStockMovements(id).first;
      expect(movements, hasLength(2));
      expect(movements.first.reason, StockMovementReason.sale);
      expect(movements.last.reason, StockMovementReason.restock);
    });
  });

  test(
    'updateSupplierVerification flips isSupplierVerified on every one of '
    "the supplier's products",
    () async {
      const supplierId = DemoIds.supplierArtisanatSikasso;
      final before = await repository.watchMyProducts(supplierId).first;
      expect(before.every((p) => !p.isSupplierVerified), isTrue);

      await repository.updateSupplierVerification(
        supplierId: supplierId,
        isVerified: true,
      );

      final after = await repository.watchMyProducts(supplierId).first;
      expect(after.every((p) => p.isSupplierVerified), isTrue);
    },
  );
}
