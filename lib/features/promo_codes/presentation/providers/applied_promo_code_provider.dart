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
/// Remise à zéro quand le **contenu** de la commande change : une remise
/// calculée sur deux articles ne vaut plus quand il y en a trois, et
/// afficher l'ancien montant annoncerait un prix que la commande ne
/// respecterait pas.
///
/// « La commande » et non « le panier » : un achat direct ne passe jamais
/// par le panier (`checkoutItemsProvider`). S'accrocher au panier rendait le
/// code promo inopérant sur ce parcours — il répondait « votre panier est
/// vide » alors que la commande portait bien sur un produit remisable.
///
/// Sur le contenu et non sur chaque émission du flux : la source ré-émet à
/// chaque rafraîchissement, y compris sans rien changer. Écouter les
/// émissions faisait disparaître le code aussitôt appliqué — la commande
/// partait alors sans lui, au prix plein.
final appliedPromoCodeProvider =
    NotifierProvider<AppliedPromoCode, PromoCodePreview?>(AppliedPromoCode.new);

/// Ce qui, dans la commande, peut changer la valeur d'un code : les
/// articles et leurs quantités. Trié, pour qu'un simple réordonnancement
/// n'ait pas l'air d'un changement.
String _commandeSignature(AsyncValue<List<CartItem>> value) {
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
    ref.listen(checkoutItemsProvider.select(_commandeSignature), (
      previous,
      next,
    ) {
      if (previous == null || previous == next) return;
      state = null;
    });
    return null;
  }

  /// Soumet un code. Ne consomme rien : `preview_promo_code` peut être
  /// rejouée autant de fois que le client se trompe de frappe.
  ///
  /// **Aucun chemin ne se termine en silence.** Une version précédente
  /// posait `state = null` quand le code était vide ou le panier aussi, et
  /// laissait toute exception remonter : dans les trois cas le client
  /// appuyait sur « Appliquer » et il ne se passait rien — ni message, ni
  /// changement. Un bouton qui ne répond pas se lit comme une panne de
  /// l'application, et on recommence au lieu de corriger sa saisie.
  Future<void> apply(String code) async {
    if (code.trim().isEmpty) {
      state = const PromoCodePreview(
        valid: false,
        reason: 'Saisissez un code promo.',
      );
      return;
    }

    final List<CartItem> items;
    try {
      // `await` et non une lecture immédiate : la commande peut n'être pas
      // encore chargée quand le client colle son code, et une liste vue
      // vide renverrait « code sans effet » sur une commande qui ne l'est
      // pas.
      items = await ref.read(checkoutItemsProvider.future);
    } catch (_) {
      state = const PromoCodePreview(
        valid: false,
        reason: 'Commande illisible pour le moment. Réessayez.',
      );
      return;
    }

    if (items.isEmpty) {
      state = const PromoCodePreview(
        valid: false,
        reason: 'Aucun article à remiser.',
      );
      return;
    }

    try {
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
    } catch (_) {
      // Volontairement distinct d'un refus : dire « code invalide » quand
      // c'est le réseau qui a lâché envoie le client corriger un code qui
      // était bon. Le motif annonce donc une vérification impossible, pas un
      // verdict.
      state = const PromoCodePreview(
        valid: false,
        reason: 'Impossible de vérifier ce code pour le moment. Réessayez.',
      );
    }
  }

  void clear() {
    state = null;
    ref.read(typedPromoCodeProvider.notifier).state = '';
  }
}
