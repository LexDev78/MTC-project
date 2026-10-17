import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collection/collection.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_pricing.dart';
import 'package:mtc_app/features/catalog/domain/promotion_pricing.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';

import '../../data/datasources/supabase_cart_datasource.dart';
import '../../data/repositories/supabase_cart_repository.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/cart_repository.dart';

final cartDatasourceProvider = Provider<SupabaseCartDatasource>((ref) {
  return SupabaseCartDatasource(ref.watch(supabaseClientProvider));
});

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return SupabaseCartRepository(ref.watch(cartDatasourceProvider));
});

final cartItemsProvider = StreamProvider<List<CartItem>>((ref) {
  // `.select` (not a bare `.watch`) since currentUserProvider can
  // re-emit an equal-but-distinct AppUser instance (Supabase replays
  // auth events to each new onAuthStateChange subscriber) — watching the
  // whole AsyncValue would rebuild this, and lose the in-flight
  // subscription, every time that happens even though the id didn't
  // change.
  final userId = ref.watch(currentUserProvider.select((u) => u.valueOrNull?.id));
  if (userId == null) return Stream.value(const <CartItem>[]);
  return ref.watch(cartRepositoryProvider).watchCart(userId);
});

/// Les données de prix de tous les produits du panier, en **une** lecture
/// (`fetch_pricing_inputs`, `0068`).
///
/// La clé est la liste d'identifiants réduite à une chaîne, et non
/// l'ensemble lui-même : `select` compare par `==`, et deux `Set` de même
/// contenu ne sont pas égaux en Dart — la lecture repartirait à chaque
/// changement de quantité, alors que seules les lignes concernées changent
/// et qu'aucun prix de base n'en dépend.
final cartPricingProvider = FutureProvider<Map<String, ProductPricing>>((
  ref,
) async {
  final key = ref.watch(
    cartItemsProvider.select((value) {
      final ids =
          (value.valueOrNull ?? const <CartItem>[])
              .map((item) => item.productId)
              .toSet()
              .toList()
            ..sort();
      return ids.join(',');
    }),
  );
  if (key.isEmpty) return const {};
  return ref
      .watch(productRepositoryProvider)
      .fetchPricing(key.split(','));
});

/// Le prix unitaire réellement dû pour une ligne, remises comprises.
///
/// Part du prix **courant** du produit (ou de sa variante) et non du prix
/// figé à l'ajout : une remise qui commence après la mise au panier doit en
/// faire baisser le montant, et une remise qui finit doit le faire remonter.
/// C'est de toute façon ce que `place_order` facturera — afficher le prix
/// figé ferait annoncer un total que la commande démentirait.
///
/// Tant que le produit n'est pas chargé, on retombe sur le prix figé : il est
/// faux au plus de quelques francs, là où zéro serait absurde.
final cartLineUnitPriceProvider = Provider.family<int, String>((ref, itemId) {
  final items = ref.watch(cartItemsProvider).valueOrNull ?? const <CartItem>[];
  final item = items.firstWhereOrNull((i) => i.id == itemId);
  if (item == null) return 0;

  final pricing = ref.watch(cartPricingProvider).valueOrNull?[item.productId];
  if (pricing == null) return item.unitPriceFcfaSnapshot;

  return effectiveUnitPriceFcfa(
    basePriceFcfa: pricing.basePriceFor(item.variantId),
    promotions: pricing.promotions,
    quantity: item.quantity,
  );
});

/// Le prix plein de la ligne, pour l'afficher barré — `null` quand il n'y a
/// pas de remise.
final cartLineCompareAtPriceProvider = Provider.family<int?, String>((
  ref,
  itemId,
) {
  final items = ref.watch(cartItemsProvider).valueOrNull ?? const <CartItem>[];
  final item = items.firstWhereOrNull((i) => i.id == itemId);
  if (item == null) return null;
  final pricing = ref.watch(cartPricingProvider).valueOrNull?[item.productId];
  if (pricing == null) return null;

  final base = pricing.basePriceFor(item.variantId);
  final effective = ref.watch(cartLineUnitPriceProvider(itemId));
  return effective < base ? base : null;
});

final cartTotalFcfaProvider = Provider<int>((ref) {
  final items = ref.watch(cartItemsProvider).valueOrNull ?? const <CartItem>[];
  return items.fold(
    0,
    (sum, item) =>
        sum + ref.watch(cartLineUnitPriceProvider(item.id)) * item.quantity,
  );
});

final cartItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(cartItemsProvider).valueOrNull ?? const <CartItem>[];
  return items.fold(0, (sum, item) => sum + item.quantity);
});

/// The client's cart entry for [productId], if any — `null` means it's not
/// in the cart. Drives both the "already added" styling and the remove
/// action on the catalog's quick-add cart button (see `ProductCard`).
final cartItemForProductProvider = Provider.family<CartItem?, String>((
  ref,
  productId,
) {
  final items = ref.watch(cartItemsProvider).valueOrNull ?? const <CartItem>[];
  for (final item in items) {
    if (item.productId == productId) return item;
  }
  return null;
});

/// L'article qu'on achète sans passer par le panier (« Acheter maintenant »).
///
/// Posé ici et non dans les providers de paiement : c'est la même notion que
/// le panier — ce que le client s'apprête à commander —, et deux
/// fonctionnalités en dépendent sans dépendre l'une de l'autre (le paiement
/// et les codes promo). Le laisser côté paiement obligeait les codes promo à
/// importer le paiement, qui les importe déjà.
final buyNowItemProvider = StateProvider<CartItem?>((ref) => null);

/// Ce que le client est en train de commander : l'achat direct s'il y en a
/// un, le panier sinon.
///
/// **Source unique.** L'écran de paiement et le champ « code promo » lisaient
/// chacun leur liste : le paiement tenait compte de l'achat direct, le code
/// promo non. Un code essayé sur un achat direct répondait donc « votre
/// panier est vide », ou se calculait sur des articles qui n'étaient pas
/// ceux de la commande.
final checkoutItemsProvider = FutureProvider<List<CartItem>>((ref) async {
  final buyNow = ref.watch(buyNowItemProvider);
  if (buyNow != null) return [buyNow];
  return ref.watch(cartItemsProvider.future);
});
