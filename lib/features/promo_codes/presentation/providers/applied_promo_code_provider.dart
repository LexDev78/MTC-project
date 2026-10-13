import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/cart/domain/entities/cart_item.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';

import '../../domain/entities/promo_code.dart';
import 'promo_code_providers.dart';

/// Le code tel que le client l'a tapé, et ce que le serveur en dit.
///
/// Deux états séparés plutôt qu'un seul : le texte saisi survit à un refus,
/// pour que le client puisse le corriger sans tout retaper.
final typedPromoCodeProvider = StateProvider<String>((ref) => '');

/// La réponse du serveur au dernier code essayé — `null` tant qu'aucun n'a
/// été soumis.
///
/// Remise à zéro quand le **contenu** du panier change : une remise calculée
/// sur deux articles ne vaut plus quand il y en a trois, et afficher
/// l'ancien montant annoncerait un prix que la commande ne respecterait pas.
///
/// Sur le contenu et non sur chaque émission du flux : `cartItemsProvider`
/// ré-émet à chaque rafraîchissement, y compris sans rien changer. Écouter
/// les émissions faisait disparaître le code aussitôt appliqué — la
/// commande partait alors sans lui, au prix plein.
final appliedPromoCodeProvider =
    NotifierProvider<AppliedPromoCode, PromoCodePreview?>(AppliedPromoCode.new);

/// Ce qui, dans le panier, peut changer la valeur d'un code : les articles
/// et leurs quantités. Trié, pour qu'un simple réordonnancement n'ait pas
/// l'air d'un changement.
String _cartSignature(AsyncValue<List<CartItem>> value) {
  final items = value.valueOrNull ?? const <CartItem>[];
  final parts = [
    for (final item in items)
      '${item.productId}:${item.variantId ?? ''}:${item.quantity}',
  ]..sort();
  return parts.join('|');
}

class AppliedPromoCode extends Notifier<PromoCodePreview?> {
  @override
  PromoCodePreview? build() {
    ref.listen(cartItemsProvider.select(_cartSignature), (previous, next) {
      if (previous == null || previous == next) return;
      state = null;
    });
    return null;
  }

  /// Soumet un code. Ne consomme rien : `preview_promo_code` peut être
  /// rejouée autant de fois que le client se trompe de frappe.
  Future<void> apply(String code) async {
    // `await` et non une lecture immédiate : le panier peut n'être pas
    // encore chargé quand le client colle son code, et un panier vu vide
    // renverrait « code sans effet » sur un panier qui ne l'est pas.
    final items = await ref.read(cartItemsProvider.future);
    if (items.isEmpty || code.trim().isEmpty) {
      state = null;
      return;
    }
    state = await ref
        .read(promoCodeRepositoryProvider)
        .preview(
          code: code.trim(),
          lines: [
            for (final item in items)
              (
                productId: item.productId,
                variantId: item.variantId,
                quantity: item.quantity,
              ),
          ],
        );
  }

  void clear() {
    state = null;
    ref.read(typedPromoCodeProvider.notifier).state = '';
  }
}
