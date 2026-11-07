library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/cart/domain/entities/cart_item.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_pricing.dart';
import 'package:mtc_app/features/catalog/domain/repositories/product_repository.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';
import 'package:mtc_app/features/promo_codes/domain/entities/promo_code.dart';
import 'package:mtc_app/features/promo_codes/domain/repositories/promo_code_repository.dart';
import 'package:mtc_app/features/promo_codes/presentation/providers/applied_promo_code_provider.dart';
import 'package:mtc_app/features/promo_codes/presentation/providers/promo_code_providers.dart';

/// Appliquer un code promo ne doit pas refaire l'écran de paiement.
///
/// Le symptôme était visible : la page entière repassait par son indicateur
/// de chargement à chaque code essayé. La cause ne l'était pas — le code
/// promo était lu **dans** `checkoutGroupsProvider`, qui est asynchrone et
/// commence par aller chercher les prix au serveur. Un code mal tapé coûtait
/// donc une requête réseau, et la page avec.
///
/// Ce test compte les appels plutôt que de regarder l'écran : c'est la seule
/// façon de vérifier qu'une requête n'a **pas** eu lieu.

const _fournisseur = 'fournisseur-1';
const _produit = 'produit-1';

class _DepotProduits implements ProductRepository {
  int appelsPrix = 0;

  @override
  Future<Map<String, ProductPricing>> fetchPricing(List<String> productIds) async {
    appelsPrix++;
    return {
      _produit: const ProductPricing(
        priceFcfa: 10000,
        stockQuantity: 10,
        weightKg: 1,
        category: ProductCategory.textilesBogolan,
        city: 'Bamako',
        supplierId: _fournisseur,
        supplierName: 'Boutique',
        allowsSelfDelivery: true,
        allowsMtcDelivery: true,
      ),
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non utilisé ici');
}

class _DepotCodes implements PromoCodeRepository {
  int appelsDisponibilite = 0;

  @override
  Future<bool> existsForProducts(List<String> productIds) async {
    appelsDisponibilite++;
    return true;
  }

  @override
  Future<PromoCodePreview> preview({
    required String code,
    required List<({String productId, String? variantId, int quantity})> lines,
  }) async {
    if (code != 'BIENVENUE') {
      return const PromoCodePreview(valid: false, reason: 'Code inconnu.');
    }
    return const PromoCodePreview(
      valid: true,
      code: 'BIENVENUE',
      supplierId: _fournisseur,
      discountFcfa: 1500,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non utilisé ici');
}

final _article = CartItem(
  id: 'ligne-1',
  userId: 'client-1',
  productId: _produit,
  supplierId: _fournisseur,
  productNameSnapshot: 'Tissu',
  unitPriceFcfaSnapshot: 10000,
  quantity: 1,
  addedAt: DateTime(2026, 10, 14),
);

void main() {
  late _DepotProduits produits;
  late _DepotCodes codes;
  late ProviderContainer container;

  setUp(() {
    produits = _DepotProduits();
    codes = _DepotCodes();
    container = ProviderContainer(
      overrides: [
        productRepositoryProvider.overrideWithValue(produits),
        promoCodeRepositoryProvider.overrideWithValue(codes),
        cartItemsProvider.overrideWith((ref) => Stream.value([_article])),
      ],
    );
    addTearDown(container.dispose);
  });

  test('un code promo ne redemande pas les prix au serveur', () async {
    // L'écran s'ouvre : une lecture des prix, c'est normal.
    await container.read(checkoutGroupsProvider.future);
    expect(produits.appelsPrix, 1);

    // Trois codes essayés, dont deux refusés.
    for (final code in ['FAUX', 'ENCOREFAUX', 'BIENVENUE']) {
      await container.read(appliedPromoCodeProvider.notifier).apply(code);
      await container.read(checkoutGroupsProvider.future);
    }

    expect(
      produits.appelsPrix,
      1,
      reason: 'les prix ne changent pas parce qu\'on tape un code',
    );
  });

  test('la remise acceptée arrive bien dans les groupes', () async {
    await container.read(checkoutGroupsProvider.future);

    await container.read(appliedPromoCodeProvider.notifier).apply('BIENVENUE');
    final groupes = await container.read(checkoutGroupsProvider.future);

    expect(groupes.single.promoDiscountFcfa, 1500);
    expect(groupes.single.subtotalFcfa, 10000 - 1500);
  });

  test('un code refusé laisse les montants intacts', () async {
    final avant = await container.read(checkoutGroupsProvider.future);

    await container.read(appliedPromoCodeProvider.notifier).apply('FAUX');
    final apres = await container.read(checkoutGroupsProvider.future);

    expect(apres.single.subtotalFcfa, avant.single.subtotalFcfa);
    expect(apres.single.promoDiscountFcfa, 0);
  });

  test(
    'pendant le recalcul, les groupes gardent leur valeur précédente',
    () async {
      // C'est cette propriété que l'écran exploite (`skipLoadingOnReload`) :
      // sans valeur conservée, il n'aurait rien d'autre à afficher qu'un
      // indicateur de chargement.
      await container.read(checkoutGroupsProvider.future);

      // Volontairement sans `await` : on veut observer l'état **pendant** le
      // recalcul, pas après.
      unawaited(
        container.read(appliedPromoCodeProvider.notifier).apply('BIENVENUE'),
      );
      final pendant = container.read(checkoutGroupsProvider);

      expect(
        pendant.hasValue,
        isTrue,
        reason: 'la page doit pouvoir continuer à montrer ce qu\'elle montrait',
      );
    },
  );

  test(
    'savoir si un code existe ne se redemande pas à chaque code tapé',
    () async {
      // Même piège que pour les prix : cette interrogation est branchée sur
      // le contenu du panier, pas sur le code appliqué. L'accrocher aux
      // groupes la relancerait à chaque frappe.
      await container.read(checkoutHasPromoCodeProvider.future);
      expect(codes.appelsDisponibilite, 1);

      for (final code in ['FAUX', 'BIENVENUE']) {
        await container.read(appliedPromoCodeProvider.notifier).apply(code);
        await container.read(checkoutHasPromoCodeProvider.future);
      }

      expect(codes.appelsDisponibilite, 1);
    },
  );
}
