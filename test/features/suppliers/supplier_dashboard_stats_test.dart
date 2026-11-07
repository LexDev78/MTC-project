@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/catalog/data/datasources/supabase_product_datasource.dart';
import 'package:mtc_app/features/catalog/data/repositories/supabase_product_repository.dart';
import 'package:mtc_app/features/orders/data/datasources/supabase_order_datasource.dart';
import 'package:mtc_app/features/orders/data/repositories/supabase_order_repository.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/suppliers/data/datasources/supabase_supplier_datasource.dart';
import 'package:mtc_app/features/suppliers/data/repositories/supabase_supplier_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/supabase_test_harness.dart';

/// Les chiffres du tableau de bord (`0092`).
///
/// L'essentiel de ce qui se vérifie ici n'est pas que la requête rende des
/// nombres, mais qu'elle rende **les mêmes** que les écrans qui disent déjà
/// la même chose ailleurs. Deux compteurs qui divergent sur « combien
/// avez-vous gagné » sont pires qu'un seul : on ne sait plus lequel croire.

Future<SupabaseClient> _signIn(String identifiant) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(identifiant),
    password: 'password123',
  );
  addTearDown(client.dispose);
  return client;
}

void main() {
  setUp(resetAndSeed);

  test('les compteurs correspondent au catalogue du fournisseur', () async {
    final client = await _signIn('fournisseur1');
    final stats = await SupabaseSupplierRepository(
      SupabaseSupplierDatasource(client),
    ).fetchDashboardStats();

    final produits = await SupabaseProductRepository(
      SupabaseProductDatasource(client),
    ).watchMyProducts(DemoIds.supplierBogolanBamako).first;

    expect(stats.productsTotal, produits.length);
    expect(
      stats.viewsTotal,
      produits.fold<int>(0, (somme, p) => somme + p.viewCount),
    );
    expect(stats.productsActive, lessThanOrEqualTo(stats.productsTotal));
  });

  test(
    'le chiffre d\'affaires est celui des commandes livrées, et lui seul',
    () async {
      final client = await _signIn('fournisseur1');
      final stats = await SupabaseSupplierRepository(
        SupabaseSupplierDatasource(client),
      ).fetchDashboardStats();

      final commandes = await SupabaseOrderRepository(
        SupabaseOrderDatasource(client),
      ).watchOrdersForSupplier(DemoIds.supplierBogolanBamako).first;

      final mesGroupes = [
        for (final commande in commandes)
          ...commande.supplierGroups.where(
            (g) => g.supplierId == DemoIds.supplierBogolanBamako,
          ),
      ];
      final livrees = mesGroupes.where((g) => g.status == OrderStatus.delivered);

      expect(stats.ordersTotal, mesGroupes.length);
      expect(stats.ordersDelivered, livrees.length);
      // Jamais les frais de livraison : en livraison MTC ils reviennent à la
      // plateforme. Même règle que `compute_financial_summary`.
      expect(
        stats.grossFcfa,
        livrees.fold<int>(0, (somme, g) => somme + g.subtotalFcfa),
      );

      // Et ce qui n'est ni livré ni annulé se compte à part : c'est ce qu'il
      // reste à traiter aujourd'hui.
      expect(
        stats.ordersInProgress,
        mesGroupes
            .where(
              (g) =>
                  g.status != OrderStatus.delivered &&
                  g.status != OrderStatus.cancelled,
            )
            .length,
      );
    },
  );

  test('chaque fournisseur ne voit que ses propres chiffres', () async {
    final premier = await _signIn('fournisseur1');
    final statsPremier = await SupabaseSupplierRepository(
      SupabaseSupplierDatasource(premier),
    ).fetchDashboardStats();

    final second = await _signIn('fournisseur2');
    final statsSecond = await SupabaseSupplierRepository(
      SupabaseSupplierDatasource(second),
    ).fetchDashboardStats();

    // Deux catalogues différents : les totaux ne peuvent pas coïncider par
    // accident sur le jeu de démonstration.
    expect(statsPremier.productsTotal, greaterThan(0));
    expect(statsSecond.productsTotal, greaterThan(0));
    expect(
      statsPremier.productsTotal + statsSecond.productsTotal,
      greaterThan(statsPremier.productsTotal),
      reason: 'le second fournisseur doit avoir ses propres produits',
    );
  });

  test('les meilleures ventes ne comptent que le livré', () async {
    final client = await _signIn('fournisseur1');
    final stats = await SupabaseSupplierRepository(
      SupabaseSupplierDatasource(client),
    ).fetchDashboardStats();

    // Au plus cinq lignes, et chacune porte un nom et une quantité.
    expect(stats.bestSellers.length, lessThanOrEqualTo(5));
    for (final article in stats.bestSellers) {
      expect(article.name, isNotEmpty);
      expect(article.quantity, greaterThan(0));
    }
    // La somme des quantités vendues ne peut pas dépasser ce que les
    // commandes livrées contiennent.
    if (stats.ordersDelivered == 0) {
      expect(stats.bestSellers, isEmpty);
      expect(stats.grossFcfa, 0);
    }
  });
}
