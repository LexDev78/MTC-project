@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/catalog/data/datasources/supabase_product_datasource.dart';
import 'package:mtc_app/features/catalog/data/repositories/supabase_product_repository.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_status.dart';
import 'package:mtc_app/features/catalog/domain/entities/stock_movement.dart';
import 'package:mtc_app/features/catalog/domain/repositories/product_repository.dart';

import '../../support/supabase_test_harness.dart';

// `products_write_own` RLS scopes writes to the owning supplier's own
// session, and `products_select_public` only shows a draft/unverified
// product back to its own owner — so "as the supplier" vs "as a visiting
// client" has to be two genuinely different sessions, not just two calls
// on the same repository.
Future<ProductRepository> _repositoryAs(String? usernameOrPhone) async {
  final client = createTestSupabaseClient();
  if (usernameOrPhone != null) {
    await client.auth.signInWithPassword(
      email: pseudoEmail(usernameOrPhone),
      password: 'password123',
    );
  }
  return SupabaseProductRepository(SupabaseProductDatasource(client));
}

void main() {
  late ProductRepository asFournisseur1; // Bogolan Bamako
  late ProductRepository asClient; // unauthenticated visitor

  setUp(() async {
    await resetAndSeed();
    asFournisseur1 = await _repositoryAs('fournisseur1');
    asClient = await _repositoryAs(null);
  });

  Future<String> createDraftProduct({
    ProductRepository? repository,
    String supplierId = DemoIds.supplierBogolanBamako,
    int stockQuantity = 10,
  }) async {
    final product = await (repository ?? asFournisseur1).createProduct(
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
      final asFournisseur2 = await _repositoryAs('fournisseur2'); // Artisanat Sikasso

      final mine = await asFournisseur2
          .watchMyProducts(DemoIds.supplierArtisanatSikasso)
          .first;

      expect(mine, hasLength(3));
      expect(mine.every((p) => !p.isSupplierVerified), isTrue);

      final visibleToClients = await asClient
          .watchProducts(supplierId: DemoIds.supplierArtisanatSikasso)
          .first;
      expect(visibleToClients, isEmpty);
    },
  );

  test('a newly created product starts as draft, hidden from clients', () async {
    final id = await createDraftProduct();

    final product = await asFournisseur1.getById(id);
    expect(product.status, ProductStatus.draft);

    final visibleToClients = await asClient
        .watchProducts(supplierId: DemoIds.supplierBogolanBamako)
        .first;
    expect(visibleToClients.any((p) => p.id == id), isFalse);
  });

  test(
    'activating a draft product makes it appear in the client-facing query',
    () async {
      final id = await createDraftProduct();
      await asFournisseur1.setStatus(id: id, status: ProductStatus.active);

      final visibleToClients = await asClient
          .watchProducts(supplierId: DemoIds.supplierBogolanBamako)
          .first;
      expect(visibleToClients.any((p) => p.id == id), isTrue);
    },
  );

  test('updateProduct replaces the stored record', () async {
    final id = await createDraftProduct();
    final original = await asFournisseur1.getById(id);

    await asFournisseur1.updateProduct(
      original.copyWith(name: 'Nom modifié', priceFcfa: 12000),
    );

    final updated = await asFournisseur1.getById(id);
    expect(updated.name, 'Nom modifié');
    expect(updated.priceFcfa, 12000);
  });

  group('adjustStock', () {
    test('increases stock and records a movement', () async {
      final id = await createDraftProduct(stockQuantity: 10);

      await asFournisseur1.adjustStock(
        id: id,
        quantityDelta: 5,
        reason: StockMovementReason.restock,
        note: 'Livraison fournisseur',
      );

      final product = await asFournisseur1.getById(id);
      expect(product.stockQuantity, 15);

      final movements = await asFournisseur1.watchStockMovements(id).first;
      expect(movements, hasLength(1));
      expect(movements.single.quantityDelta, 5);
      expect(movements.single.reason, StockMovementReason.restock);
      expect(movements.single.note, 'Livraison fournisseur');
    });

    test('decreases stock down to exactly zero', () async {
      final id = await createDraftProduct(stockQuantity: 10);

      await asFournisseur1.adjustStock(
        id: id,
        quantityDelta: -10,
        reason: StockMovementReason.sale,
      );

      final product = await asFournisseur1.getById(id);
      expect(product.stockQuantity, 0);
    });

    test('throws InsufficientStockException rather than going negative', () async {
      final id = await createDraftProduct(stockQuantity: 3);

      await expectLater(
        () => asFournisseur1.adjustStock(
          id: id,
          quantityDelta: -4,
          reason: StockMovementReason.sale,
        ),
        throwsA(isA<InsufficientStockException>()),
      );

      final product = await asFournisseur1.getById(id);
      expect(product.stockQuantity, 3, reason: 'stock must be unchanged');
    });

    test('newest movement is listed first', () async {
      final id = await createDraftProduct(stockQuantity: 10);

      await asFournisseur1.adjustStock(
        id: id,
        quantityDelta: 5,
        reason: StockMovementReason.restock,
      );
      await asFournisseur1.adjustStock(
        id: id,
        quantityDelta: -2,
        reason: StockMovementReason.sale,
      );

      final movements = await asFournisseur1.watchStockMovements(id).first;
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
      final asFournisseur2 = await _repositoryAs('fournisseur2');
      final adminClient = createTestSupabaseClient();
      await adminClient.auth.signInWithPassword(
        email: pseudoEmail('admin1'),
        password: 'password123',
      );
      final asAdmin = SupabaseProductRepository(SupabaseProductDatasource(adminClient));

      // ignore: avoid_print
      print('DIAG admin profile: ${await adminClient.from('profiles').select().eq('id', adminClient.auth.currentUser!.id)}');

      final before = await asFournisseur2.watchMyProducts(supplierId).first;
      expect(before.every((p) => !p.isSupplierVerified), isTrue);

      final updateResult = await adminClient
          .from('products')
          .update({'is_supplier_verified': true})
          .eq('supplier_id', supplierId)
          .select();
      // ignore: avoid_print
      print('DIAG raw update affected rows: ${updateResult.length}');

      await asAdmin.updateSupplierVerification(
        supplierId: supplierId,
        isVerified: true,
      );

      // ignore: avoid_print
      print('DIAG after-as-admin: ${(await asAdmin.watchMyProducts(supplierId).first).map((p) => p.isSupplierVerified).toList()}');

      final after = await asFournisseur2.watchMyProducts(supplierId).first;
      // ignore: avoid_print
      print('DIAG after-as-fournisseur2: ${after.map((p) => p.isSupplierVerified).toList()}');
      expect(after.every((p) => p.isSupplierVerified), isTrue);
    },
  );
}
