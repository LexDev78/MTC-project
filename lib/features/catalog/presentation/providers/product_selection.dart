import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_characteristic.dart';
import '../../domain/entities/product_variant.dart';

/// Ce que le client choisit sur une fiche produit — la quantité, la
/// variante, et la valeur précise quand une variante en regroupe plusieurs.
///
/// Partagé entre la fiche, sa feuille d'achat et la barre du bas, qui ne
/// sont pas parentes les unes des autres : d'où un état Riverpod plutôt que
/// des champs locaux. Isolé par produit, pour qu'une fiche laissée en
/// arrière-plan ne prête pas sa quantité à une autre.
///
/// `autoDispose` sans danger ici (contrairement à `buyNowItemProvider`) :
/// tout est lu et écrit pendant que la fiche reste montée.
final productQuantityProvider = StateProvider.autoDispose.family<int, String>(
  (ref, productId) => 1,
);

/// La variante choisie, `null` pour un produit sans variantes.
final productVariantIdProvider = StateProvider.autoDispose
    .family<String?, String>((ref, productId) => null);

/// Pour chaque caractéristique où la variante choisie regroupe plusieurs
/// valeurs (une « Taille » vendue en 42, 46 et 48 au même prix), celle que
/// le client veut vraiment — `ProductVariant.optionRefs` dit seulement
/// lesquelles le fournisseur a regroupées. Indexé par caractéristique,
/// recalculé par [derivePicks] à chaque changement de variante.
final productPicksProvider = StateProvider.autoDispose
    .family<Map<String, String>, String>((ref, productId) => const {});

/// Les valeurs de [variant], par caractéristique — une variante peut en
/// lister *plusieurs* pour une même caractéristique (S, M et L vendues
/// ensemble), d'où un ensemble et non une valeur.
Map<String, Set<String>> optionsByCharacteristic(ProductVariant variant) {
  final result = <String, Set<String>>{};
  for (final r in variant.optionRefs) {
    (result[r.characteristicId] ??= {}).add(r.optionId);
  }
  return result;
}

/// La variante où aller quand le client touche [optionId] pour
/// [characteristicId], compte tenu de ce qui est déjà choisi ailleurs.
///
/// Jamais une impasse : deux variantes ne listent pas forcément les mêmes
/// valeurs (une « Noir » en 42/46/48, une « Rouge » en 46/48 seulement), et
/// exiger que tout le reste corresponde exactement rendait une couleur bien
/// réelle inaccessible, selon la taille affichée à ce moment-là. On préfère
/// une variante qui garde les autres choix, et à défaut n'importe laquelle
/// qui offre [optionId].
ProductVariant? variantForOption(
  Product product,
  String characteristicId,
  String optionId,
  Map<String, Set<String>> currentSelection,
) {
  ProductVariant? fallback;
  for (final v in product.variants) {
    final byCharacteristic = optionsByCharacteristic(v);
    if (!(byCharacteristic[characteristicId]?.contains(optionId) ?? false)) {
      continue;
    }
    fallback ??= v;
    final matchesOthers = currentSelection.entries
        .where((e) => e.key != characteristicId)
        .every(
          (e) =>
              e.value.any((o) => byCharacteristic[e.key]?.contains(o) ?? false),
        );
    if (matchesOthers) return v;
  }
  return fallback;
}

/// Pour chaque caractéristique de [variant], la valeur à tenir pour
/// choisie : la seule quand il n'y en a qu'une ; celle de [previous] quand
/// elle fait encore partie de [variant] (changer de couleur en gardant la
/// taille) ; aucune sinon — le client devra en toucher une avant d'acheter
/// (voir [hasUnresolvedChoice]).
Map<String, String> derivePicks(
  ProductVariant variant,
  Map<String, String> previous,
) {
  final byCharacteristic = optionsByCharacteristic(variant);
  final result = <String, String>{};
  for (final entry in byCharacteristic.entries) {
    final own = entry.value;
    if (own.length == 1) {
      result[entry.key] = own.single;
    } else {
      final carriedOver = previous[entry.key];
      if (carriedOver != null && own.contains(carriedOver)) {
        result[entry.key] = carriedOver;
      }
    }
  }
  return result;
}

/// Vrai quand [variant] regroupe plusieurs valeurs d'une caractéristique
/// que [picks] n'a pas encore tranchées : l'achat attend, sans quoi le
/// fournisseur ne saurait pas laquelle expédier.
bool hasUnresolvedChoice(ProductVariant variant, Map<String, String> picks) {
  final byCharacteristic = optionsByCharacteristic(variant);
  return byCharacteristic.entries.any(
    (e) => e.value.length > 1 && !picks.containsKey(e.key),
  );
}

/// [variant] dont le nom est réduit à ce que [picks] a tranché (« Noir 46 »
/// au lieu du « Noir 42 46 48 » du fournisseur) — c'est ce qui est recopié
/// sur la ligne de panier, de commande ou de message, pour que la taille
/// voulue survive à cet écran. Inchangé si [picks] ne tranche rien.
ProductVariant resolveVariantForPurchase(
  ProductVariant variant,
  Map<String, String> picks,
  List<ProductCharacteristic> characteristics,
) {
  final parts = [
    for (final c in characteristics.sortedBy((c) => c.displayOrder))
      if (picks[c.id] case final pickedId?)
        if (c.options.firstWhereOrNull((o) => o.id == pickedId)
            case final option?)
          option.value,
  ];
  return parts.isEmpty ? variant : variant.copyWith(name: parts.join(' '));
}

/// La variante par défaut d'un produit qui en a : celle que le fournisseur
/// a marquée, ou la première.
ProductVariant? defaultVariantOf(Product product) {
  if (!product.hasVariants) return null;
  return product.variants.firstWhereOrNull((v) => v.isDefault) ??
      product.variants.firstOrNull;
}
