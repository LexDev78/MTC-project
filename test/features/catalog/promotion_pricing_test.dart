@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/features/catalog/domain/entities/promotion.dart';
import 'package:mtc_app/features/catalog/domain/promotion_pricing.dart';

import '../../support/supabase_test_harness.dart';

// La règle de prix des promotions (`0062`), vérifiée des deux côtés.
//
// Le calcul existe deux fois : en Dart pour afficher, en SQL pour facturer.
// Seule la version SQL fait foi, mais un écart entre les deux annoncerait au
// client un prix que la commande ne respecterait pas. Le dernier test de ce
// fichier confronte donc les deux sur une matrice de cas — c'est lui qui
// tient les deux implémentations ensemble.
Promotion _promo({
  required PromotionKind kind,
  required int value,
  int minQuantity = 1,
  DateTime? startsAt,
  DateTime? endsAt,
  bool isActive = true,
}) {
  return Promotion(
    id: 'p-$kind-$value-$minQuantity',
    productId: 'produit',
    kind: kind,
    value: value,
    minQuantity: minQuantity,
    startsAt: startsAt,
    endsAt: endsAt,
    isActive: isActive,
  );
}

void main() {
  group('règle de prix (côté app)', () {
    test('sans promotion, le prix de base', () {
      expect(
        effectiveUnitPriceFcfa(
          basePriceFcfa: 25000,
          promotions: const [],
          quantity: 1,
        ),
        25000,
      );
    });

    test('un pourcentage tronque, comme la division entière SQL', () {
      // 3333 * 15 / 100 = 499,95 → la remise est de 499, pas 500.
      expect(
        effectiveUnitPriceFcfa(
          basePriceFcfa: 3333,
          promotions: [_promo(kind: PromotionKind.percentage, value: 15)],
          quantity: 1,
        ),
        3333 - 499,
      );
    });

    test(
      'les promotions ne se cumulent pas : la plus avantageuse gagne',
      () {
        final promotions = [
          _promo(kind: PromotionKind.percentage, value: 15),
          _promo(kind: PromotionKind.percentage, value: 20),
        ];
        // 20 % et non 35 % : empiler produirait un prix que personne n'a
        // voulu, et le résultat dépendrait de l'ordre d'application.
        expect(
          effectiveUnitPriceFcfa(
            basePriceFcfa: 10000,
            promotions: promotions,
            quantity: 1,
          ),
          8000,
        );
      },
    );

    test('une remise sur quantité ne s\'applique qu\'au palier', () {
      final promotions = [
        _promo(kind: PromotionKind.percentage, value: 20, minQuantity: 10),
      ];
      expect(
        effectiveUnitPriceFcfa(
          basePriceFcfa: 10000,
          promotions: promotions,
          quantity: 9,
        ),
        10000,
      );
      expect(
        effectiveUnitPriceFcfa(
          basePriceFcfa: 10000,
          promotions: promotions,
          quantity: 10,
        ),
        8000,
      );
    });

    test('hors de sa fenêtre, une promotion ne compte pas', () {
      final now = DateTime(2026, 6, 15);
      final future = _promo(
        kind: PromotionKind.percentage,
        value: 50,
        startsAt: DateTime(2026, 7, 1),
      );
      final past = _promo(
        kind: PromotionKind.percentage,
        value: 50,
        endsAt: DateTime(2026, 6, 1),
      );
      final stopped = _promo(
        kind: PromotionKind.percentage,
        value: 50,
        isActive: false,
      );

      for (final promotion in [future, past, stopped]) {
        expect(
          effectiveUnitPriceFcfa(
            basePriceFcfa: 10000,
            promotions: [promotion],
            quantity: 1,
            now: now,
          ),
          10000,
          reason: '${promotion.id} ne devrait pas s\'appliquer',
        );
      }
    });

    test('le prix ne descend jamais sous 1 franc', () {
      // Un prix nul traverserait les contrôles de stock et de paiement sans
      // que personne ne l'ait décidé.
      expect(
        effectiveUnitPriceFcfa(
          basePriceFcfa: 500,
          promotions: [_promo(kind: PromotionKind.fixedAmount, value: 500)],
          quantity: 1,
        ),
        1,
      );
    });

    test('une remise qui n\'abaisse rien n\'est pas annoncée', () {
      // Sinon la vignette porterait un badge pour un prix inchangé.
      expect(
        bestPromotionFor(
          promotions: [_promo(kind: PromotionKind.fixedAmount, value: 1)],
          basePriceFcfa: 1,
          quantity: 1,
        ),
        isNull,
      );
    });

    test('le palier suivant est celui qu\'on peut atteindre', () {
      final step = nextQuantityStep(
        promotions: [
          _promo(kind: PromotionKind.percentage, value: 20, minQuantity: 10),
          _promo(kind: PromotionKind.percentage, value: 30, minQuantity: 50),
        ],
        basePriceFcfa: 10000,
        quantity: 7,
      );
      // Le plus proche (3 unités), pas le plus gros rabais : c'est celui
      // qu'on peut réellement inciter à atteindre.
      expect(step?.unitsMissing, 3);
      expect(step?.promotion.minQuantity, 10);
    });

    test('au palier atteint, plus rien à inciter', () {
      final step = nextQuantityStep(
        promotions: [
          _promo(kind: PromotionKind.percentage, value: 20, minQuantity: 10),
        ],
        basePriceFcfa: 10000,
        quantity: 10,
      );
      expect(step, isNull);
    });
  });

  group('parité app / base', () {
    const productId = 'b0fe527e-1f73-55e6-b24e-4d985576d473';
    const basePrice = 25000; // « Tissu Bogolan traditionnel »

    late SupabaseClient supplierClient;

    setUp(() async {
      await resetAndSeed();
      supplierClient = createTestSupabaseClient();
      await supplierClient.auth.signInWithPassword(
        email: pseudoEmail('fournisseur1'),
        password: 'password123',
      );
    });

    tearDown(() async {
      await supplierClient.dispose();
    });

    test(
      'le prix calculé pour l\'affichage est celui que la base facturera',
      () async {
        // Un jeu volontairement retors : pourcentage et montant fixe qui se
        // croisent selon la quantité, plus une promotion expirée et une
        // promotion arrêtée, qui ne doivent peser ni d'un côté ni de l'autre.
        // Toutes les lignes portent les mêmes clés : sur un insert multiple,
        // PostgREST unifie les colonnes de l'ensemble et envoie `null` là où
        // une ligne n'en parle pas — ce qui heurte les colonnes `not null`
        // au lieu de laisser jouer leur valeur par défaut.
        final expired = DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 1))
            .toIso8601String();
        final rows = <Map<String, Object?>>[
          {'kind': 'percentage', 'value': 15, 'min_quantity': 1,
            'ends_at': null, 'is_active': true},
          {'kind': 'percentage', 'value': 20, 'min_quantity': 10,
            'ends_at': null, 'is_active': true},
          {'kind': 'fixed_amount', 'value': 6000, 'min_quantity': 20,
            'ends_at': null, 'is_active': true},
          // Expirée, et arrêtée : ni l'une ni l'autre ne doit peser, d'un
          // côté comme de l'autre.
          {'kind': 'percentage', 'value': 90, 'min_quantity': 1,
            'ends_at': expired, 'is_active': true},
          {'kind': 'percentage', 'value': 80, 'min_quantity': 1,
            'ends_at': null, 'is_active': false},
        ];
        await supplierClient.from('product_promotions').insert([
          for (final row in rows) {...row, 'product_id': productId},
        ]);

        final stored = await supplierClient
            .from('product_promotions')
            .select()
            .eq('product_id', productId);
        final promotions = [
          for (final row in stored) Promotion.fromJson(row),
        ];
        expect(promotions, hasLength(5));

        for (final quantity in [1, 2, 9, 10, 19, 20, 100]) {
          final fromApp = effectiveUnitPriceFcfa(
            basePriceFcfa: basePrice,
            promotions: promotions,
            quantity: quantity,
          );
          final fromDatabase = await supplierClient.rpc(
            'effective_unit_price_fcfa',
            params: {
              'p_product_id': productId,
              'p_variant_id': null,
              'p_quantity': quantity,
            },
          );
          expect(
            fromApp,
            fromDatabase,
            reason:
                'quantité $quantity : l\'app annoncerait $fromApp alors que '
                'la commande facturerait $fromDatabase',
          );
        }
      },
    );

    test(
      'un fournisseur ne peut pas promouvoir le produit d\'un autre',
      () async {
        final otherClient = createTestSupabaseClient();
        await otherClient.auth.signInWithPassword(
          email: pseudoEmail('fournisseur2'),
          password: 'password123',
        );

        // Sans cette garde, n'importe quel vendeur pourrait brader le
        // catalogue d'un concurrent.
        await expectLater(
          otherClient.from('product_promotions').insert({
            'product_id': productId,
            'kind': 'percentage',
            'value': 90,
          }),
          throwsA(isA<PostgrestException>()),
        );

        await otherClient.dispose();
      },
    );

    test('une remise de plus de 90 % est refusée', () async {
      // 100 % est un cadeau, et presque toujours une faute de saisie.
      await expectLater(
        supplierClient.from('product_promotions').insert({
          'product_id': productId,
          'kind': 'percentage',
          'value': 100,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
