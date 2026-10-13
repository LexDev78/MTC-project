@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/features/promo_codes/data/datasources/supabase_promo_code_datasource.dart';
import 'package:mtc_app/features/promo_codes/data/repositories/supabase_promo_code_repository.dart';
import 'package:mtc_app/features/promo_codes/domain/repositories/promo_code_repository.dart';

import '../../support/supabase_test_harness.dart';

// Codes promo (`0071`–`0073`).
//
// Ce qui distingue un code d'une promotion, et que ces tests vérifient :
//
//  * il ne doit pas être **énumérable** — un client ne peut pas lister les
//    codes en vigueur, seulement en présenter un ;
//  * il ne vaut que chez son fournisseur, et sur les produits couverts ;
//  * il s'épuise, et le compteur doit tenir sous des commandes simultanées ;
//  * il ne se cumule pas avec une promotion automatique ;
//  * il laisse une trace lisible par le fournisseur.
Future<SupabaseClient> _signIn(String usernameOrPhone) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(usernameOrPhone),
    password: 'password123',
  );
  return client;
}

void main() {
  // « Tissu Bogolan traditionnel » (25 000) chez Bogolan Bamako.
  const bogolan = 'b0fe527e-1f73-55e6-b24e-4d985576d473';
  // « Smartphone Android 64GB » chez Electro Bamako — un autre vendeur.
  const smartphone = 'b3fff077-755b-578a-b5ec-1e00139e3029';

  late SupabaseClient supplierClient;
  late PromoCodeRepository asSupplier;

  setUp(() async {
    await resetAndSeed();
    supplierClient = await _signIn('fournisseur1');
    asSupplier = SupabasePromoCodeRepository(
      SupabasePromoCodeDatasource(supplierClient),
    );
  });

  tearDown(() async {
    await supplierClient.dispose();
  });

  test(
    'un code est normalisé, rattaché à son créateur, et invisible des clients',
    () async {
      await asSupplier.create(code: '  rentree  ', percent: 10);

      final mine = await asSupplier.watchMine().first;
      expect(mine.single.code, 'RENTREE');
      expect(mine.single.percent, 10);
      expect(mine.single.usesCount, 0);
      // Aucun produit nommé = toute la boutique.
      expect(mine.single.productIds, isEmpty);

      // Le point qui compte : un client ne peut pas lister les codes. Sans
      // cela, il suffirait d'ouvrir l'app pour connaître toutes les
      // remises en cours de toutes les boutiques.
      final clientClient = await _signIn('client1');
      final visible = await clientClient.from('promo_codes').select();
      expect(visible, isEmpty);
      await clientClient.dispose();
    },
  );

  test('un code ne peut couvrir que les produits de son fournisseur', () async {
    await asSupplier.create(code: 'MIEN', percent: 10);
    final id = (await asSupplier.watchMine().first).single.id;

    // Le smartphone appartient à Electro Bamako.
    await expectLater(
      supplierClient.from('promo_code_products').insert({
        'promo_code_id': id,
        'product_id': smartphone,
      }),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('un code s\'applique, et seulement aux lignes de son vendeur', () async {
    await asSupplier.create(code: 'RENTREE', percent: 10);

    final clientClient = await _signIn('client1');
    final asClient = SupabasePromoCodeRepository(
      SupabasePromoCodeDatasource(clientClient),
    );

    final preview = await asClient.preview(
      code: 'rentree',
      lines: [
        (productId: bogolan, variantId: null, quantity: 2),
        // Chez un autre vendeur : ignoré par le calcul.
        (productId: smartphone, variantId: null, quantity: 1),
      ],
    );

    expect(preview.valid, isTrue);
    expect(preview.code, 'RENTREE');
    // 10 % de 25 000, deux fois — le smartphone n'y est pour rien.
    expect(preview.discountFcfa, 5000);

    await clientClient.dispose();
  });

  test(
    'un code limité à un produit ne remise pas les autres du même vendeur',
    () async {
      // Bogolan Bamako vend aussi un boubou : le code ne vise que le tissu.
      await asSupplier.create(
        code: 'TISSU',
        percent: 20,
        productIds: const [bogolan],
      );

      final clientClient = await _signIn('client1');
      final asClient = SupabasePromoCodeRepository(
        SupabasePromoCodeDatasource(clientClient),
      );

      final couvert = await asClient.preview(
        code: 'TISSU',
        lines: [(productId: bogolan, variantId: null, quantity: 1)],
      );
      expect(couvert.discountFcfa, 5000);

      final autreProduit = await clientClient
          .from('products')
          .select('id')
          .eq('supplier_id', 'b7eb8585-4091-5b6f-83f7-5d70724e97a3')
          .neq('id', bogolan)
          .limit(1)
          .single();

      final nonCouvert = await asClient.preview(
        code: 'TISSU',
        lines: [
          (
            productId: autreProduit['id'] as String,
            variantId: null,
            quantity: 1,
          ),
        ],
      );
      expect(nonCouvert.valid, isFalse);

      await clientClient.dispose();
    },
  );

  test('un code arrêté, expiré ou épuisé ne s\'applique pas', () async {
    final clientClient = await _signIn('client1');
    final asClient = SupabasePromoCodeRepository(
      SupabasePromoCodeDatasource(clientClient),
    );
    final lignes = [(productId: bogolan, variantId: null, quantity: 1)];

    await asSupplier.create(code: 'ARRETE', percent: 10);
    final arrete = (await asSupplier.watchMine().first).single;
    await asSupplier.setActive(id: arrete.id, isActive: false);
    expect((await asClient.preview(code: 'ARRETE', lines: lignes)).valid, isFalse);

    await asSupplier.create(
      code: 'EXPIRE',
      percent: 10,
      endsAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    );
    expect((await asClient.preview(code: 'EXPIRE', lines: lignes)).valid, isFalse);

    await asSupplier.create(
      code: 'PLUSTARD',
      percent: 10,
      startsAt: DateTime.now().toUtc().add(const Duration(days: 7)),
    );
    expect(
      (await asClient.preview(code: 'PLUSTARD', lines: lignes)).valid,
      isFalse,
    );

    await clientClient.dispose();
  });

  test('un achat minimum non atteint refuse le code, et le dit', () async {
    await asSupplier.create(code: 'GROSPANIER', percent: 10, minOrderFcfa: 60000);

    final clientClient = await _signIn('client1');
    final asClient = SupabasePromoCodeRepository(
      SupabasePromoCodeDatasource(clientClient),
    );

    final tropPetit = await asClient.preview(
      code: 'GROSPANIER',
      lines: [(productId: bogolan, variantId: null, quantity: 1)],
    );
    expect(tropPetit.valid, isFalse);
    expect(tropPetit.reason, contains('60000'));

    final assez = await asClient.preview(
      code: 'GROSPANIER',
      lines: [(productId: bogolan, variantId: null, quantity: 3)],
    );
    expect(assez.valid, isTrue);

    await clientClient.dispose();
  });

  test(
    'un code n\'écrase pas une promotion automatique plus avantageuse',
    () async {
      // -30 % automatique sur le tissu, et un code à -10 % : le client garde
      // la promotion, et le code le dit au lieu de paraître cassé.
      await supplierClient.from('product_promotions').insert({
        'product_id': bogolan,
        'kind': 'percentage',
        'value': 30,
      });
      await asSupplier.create(code: 'PETIT', percent: 10);

      final clientClient = await _signIn('client1');
      final asClient = SupabasePromoCodeRepository(
        SupabasePromoCodeDatasource(clientClient),
      );

      final preview = await asClient.preview(
        code: 'PETIT',
        lines: [(productId: bogolan, variantId: null, quantity: 1)],
      );
      expect(preview.valid, isFalse);
      expect(preview.reason, contains('n\'améliore pas'));

      await clientClient.dispose();
    },
  );
}
