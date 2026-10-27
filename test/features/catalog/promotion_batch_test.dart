@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/features/catalog/data/datasources/supabase_product_datasource.dart';
import 'package:mtc_app/features/catalog/data/repositories/supabase_product_repository.dart';
import 'package:mtc_app/features/catalog/domain/entities/promotion.dart';
import 'package:mtc_app/features/catalog/domain/repositories/product_repository.dart';

import '../../support/supabase_test_harness.dart';

// Une remise créée une fois, posée sur plusieurs produits (`0090`).
//
// Ce qui se vérifie ici n'est pas le calcul du prix — `promotion_pricing_test`
// s'en charge — mais le **groupement** : que les lignes créées ensemble se
// retrouvent ensemble, s'arrêtent ensemble, et qu'un fournisseur ne puisse
// pas toucher au lot d'un autre.

Future<ProductRepository> _repositoryAs(String usernameOrPhone) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(usernameOrPhone),
    password: 'password123',
  );
  addTearDown(client.dispose);
  return SupabaseProductRepository(SupabaseProductDatasource(client));
}

void main() {
  // Trois articles de Bogolan Bamako.
  const bogolan = 'b0fe527e-1f73-55e6-b24e-4d985576d473';
  const boubou = '62599202-a3f0-5adc-ae1c-fe2a691adf92';
  const sac = '31987995-52ae-5c1f-81ce-b253f7fe55c3';

  late ProductRepository asFournisseur1;

  setUp(() async {
    await resetAndSeed();
    asFournisseur1 = await _repositoryAs('fournisseur1');
  });

  test('une remise posée en lot couvre tous les produits choisis', () async {
    await asFournisseur1.createPromotionBatch(
      productIds: const [bogolan, boubou, sac],
      kind: PromotionKind.percentage,
      value: 20,
      label: 'Soldes de saison',
    );

    for (final id in [bogolan, boubou, sac]) {
      final product = await asFournisseur1.getById(id);
      expect(
        product.promotions.where((p) => p.value == 20),
        hasLength(1),
        reason: 'le produit $id devrait porter la remise',
      );
    }
  });

  test('le lot se lit comme une seule remise, pas comme trois', () async {
    await asFournisseur1.createPromotionBatch(
      productIds: const [bogolan, boubou, sac],
      kind: PromotionKind.percentage,
      value: 20,
      label: 'Soldes de saison',
    );

    final batches = await asFournisseur1.fetchMyPromotionBatches();
    expect(batches, hasLength(1));
    expect(batches.single.productCount, 3);
    expect(batches.single.label, 'Soldes de saison');
    expect(batches.single.isGrouped, isTrue);
    // Les noms servent à l'affichage : « 3 produits » ne dit pas lesquels.
    expect(batches.single.productNames, hasLength(3));
  });

  test('une remise posée produit par produit apparaît quand même', () async {
    // Celles d'avant `0090`, et celles posées depuis la fiche d'un article :
    // l'écran doit les montrer, sinon il ment par omission.
    await asFournisseur1.createPromotion(
      productId: bogolan,
      kind: PromotionKind.percentage,
      value: 15,
    );

    final batches = await asFournisseur1.fetchMyPromotionBatches();
    expect(batches, hasLength(1));
    expect(batches.single.isGrouped, isFalse);
    expect(batches.single.productCount, 1);
  });

  test('arrêter un lot l\'arrête sur tous ses produits d\'un coup', () async {
    final batchId = await asFournisseur1.createPromotionBatch(
      productIds: const [bogolan, boubou, sac],
      kind: PromotionKind.percentage,
      value: 20,
    );

    final touched = await asFournisseur1.setPromotionBatchActive(
      batchId: batchId,
      isActive: false,
    );
    expect(touched, 3);

    for (final id in [bogolan, boubou, sac]) {
      final product = await asFournisseur1.getById(id);
      expect(product.promotions.single.isActive, isFalse);
    }

    // Et la reprise rend les trois à la fois.
    expect(
      await asFournisseur1.setPromotionBatchActive(
        batchId: batchId,
        isActive: true,
      ),
      3,
    );
  });

  test('supprimer un lot le retire partout', () async {
    final batchId = await asFournisseur1.createPromotionBatch(
      productIds: const [bogolan, boubou],
      kind: PromotionKind.fixedAmount,
      value: 1000,
    );

    expect(await asFournisseur1.deletePromotionBatch(batchId), 2);
    expect(await asFournisseur1.fetchMyPromotionBatches(), isEmpty);
    for (final id in [bogolan, boubou]) {
      expect((await asFournisseur1.getById(id)).promotions, isEmpty);
    }
  });

  test('un fournisseur ne touche pas au lot d\'un autre', () async {
    final batchId = await asFournisseur1.createPromotionBatch(
      productIds: const [bogolan],
      kind: PromotionKind.percentage,
      value: 20,
    );

    final asFournisseur2 = await _repositoryAs('fournisseur2');

    // La RPC lève au lieu de ne rien faire : un `update` direct serait
    // filtré par la policy et paraîtrait réussir, et l'écran annoncerait
    // un arrêt qui n'a pas eu lieu.
    await expectLater(
      asFournisseur2.setPromotionBatchActive(
        batchId: batchId,
        isActive: false,
      ),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      asFournisseur2.deletePromotionBatch(batchId),
      throwsA(isA<PostgrestException>()),
    );

    // Et la remise est intacte.
    expect((await asFournisseur1.getById(bogolan)).promotions.single.isActive, isTrue);
  });

  test('le lot d\'un autre fournisseur n\'apparaît pas dans ma liste', () async {
    await asFournisseur1.createPromotionBatch(
      productIds: const [bogolan],
      kind: PromotionKind.percentage,
      value: 20,
    );

    final asFournisseur2 = await _repositoryAs('fournisseur2');
    expect(await asFournisseur2.fetchMyPromotionBatches(), isEmpty);
  });

  test('modifier une remise change sa valeur sur tous ses produits', () async {
    final batchId = await asFournisseur1.createPromotionBatch(
      productIds: const [bogolan, boubou],
      kind: PromotionKind.percentage,
      value: 20,
    );

    await asFournisseur1.updatePromotionBatch(
      batchId: batchId,
      productIds: const [bogolan, boubou],
      kind: PromotionKind.percentage,
      value: 35,
      label: 'Soldes prolongées',
    );

    for (final id in [bogolan, boubou]) {
      final promotion = (await asFournisseur1.getById(id)).promotions.single;
      expect(promotion.value, 35);
      expect(promotion.label, 'Soldes prolongées');
    }
  });

  test('modifier la couverture ajoute et retire les bons produits', () async {
    final batchId = await asFournisseur1.createPromotionBatch(
      productIds: const [bogolan, boubou],
      kind: PromotionKind.percentage,
      value: 20,
    );

    // Le boubou sort, le sac entre, le bogolan reste.
    final couverts = await asFournisseur1.updatePromotionBatch(
      batchId: batchId,
      productIds: const [bogolan, sac],
      kind: PromotionKind.percentage,
      value: 20,
    );
    expect(couverts, 2);

    expect((await asFournisseur1.getById(bogolan)).promotions, hasLength(1));
    expect((await asFournisseur1.getById(sac)).promotions, hasLength(1));
    expect((await asFournisseur1.getById(boubou)).promotions, isEmpty);
  });

  test('le produit conservé garde sa ligne, il n\'est pas recréé', () async {
    final batchId = await asFournisseur1.createPromotionBatch(
      productIds: const [bogolan, boubou],
      kind: PromotionKind.percentage,
      value: 20,
    );
    final avant = (await asFournisseur1.getById(bogolan)).promotions.single.id;

    await asFournisseur1.updatePromotionBatch(
      batchId: batchId,
      productIds: const [bogolan, sac],
      kind: PromotionKind.percentage,
      value: 25,
    );

    // Supprimer puis tout réinsérer aurait été plus court à écrire, et
    // aurait laissé les prix au plein tarif entre les deux.
    final apres = (await asFournisseur1.getById(bogolan)).promotions.single;
    expect(apres.id, avant);
    expect(apres.value, 25);
  });

  test('une remise ne peut pas couvrir le produit d\'un autre', () async {
    final batchId = await asFournisseur1.createPromotionBatch(
      productIds: const [bogolan],
      kind: PromotionKind.percentage,
      value: 20,
    );

    // « Smartphone Android 64GB », chez Electro Bamako.
    await expectLater(
      asFournisseur1.updatePromotionBatch(
        batchId: batchId,
        productIds: const [bogolan, 'b3fff077-755b-578a-b5ec-1e00139e3029'],
        kind: PromotionKind.percentage,
        value: 20,
      ),
      throwsA(isA<PostgrestException>()),
    );
    // Refusé **avant** toute écriture : la remise est intacte.
    expect((await asFournisseur1.getById(bogolan)).promotions.single.value, 20);
  });

  test('une remise sans produit est refusée', () async {
    final batchId = await asFournisseur1.createPromotionBatch(
      productIds: const [bogolan],
      kind: PromotionKind.percentage,
      value: 20,
    );

    await expectLater(
      asFournisseur1.updatePromotionBatch(
        batchId: batchId,
        productIds: const [],
        kind: PromotionKind.percentage,
        value: 20,
      ),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('un fournisseur ne modifie pas le lot d\'un autre', () async {
    final batchId = await asFournisseur1.createPromotionBatch(
      productIds: const [bogolan],
      kind: PromotionKind.percentage,
      value: 20,
    );

    final asFournisseur2 = await _repositoryAs('fournisseur2');
    await expectLater(
      asFournisseur2.updatePromotionBatch(
        batchId: batchId,
        productIds: const [bogolan],
        kind: PromotionKind.percentage,
        value: 90,
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect((await asFournisseur1.getById(bogolan)).promotions.single.value, 20);
  });
}
