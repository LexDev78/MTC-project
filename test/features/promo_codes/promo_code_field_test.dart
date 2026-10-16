library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/cart/domain/entities/cart_item.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/promo_codes/domain/entities/promo_code.dart';
import 'package:mtc_app/features/promo_codes/domain/repositories/promo_code_repository.dart';
import 'package:mtc_app/features/promo_codes/presentation/providers/promo_code_providers.dart';
import 'package:mtc_app/features/promo_codes/presentation/widgets/promo_code_field.dart';

/// Ce que l'écran de paiement montre quand un code est refusé.
///
/// Sans base de données : le refus vient du serveur sous forme de données
/// (`{valid: false, reason: …}`), pas d'exception, donc un faux dépôt suffit
/// à reproduire exactement ce que le client voit — et c'est bien l'affichage
/// qui est en cause ici, pas le calcul.

const _refus = 'Code inconnu, expiré, ou sans effet sur les articles de ce panier.';

class _DepotFactice implements PromoCodeRepository {
  _DepotFactice(this.reponse);

  final PromoCodePreview reponse;
  int appels = 0;
  bool echoue = false;

  @override
  Future<PromoCodePreview> preview({
    required String code,
    required List<({String productId, String? variantId, int quantity})> lines,
  }) async {
    appels++;
    if (echoue) throw Exception('réseau');
    return reponse;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non utilisé ici');
}

final _article = CartItem(
  id: 'ligne-1',
  userId: 'client-1',
  productId: 'produit-1',
  supplierId: 'fournisseur-1',
  productNameSnapshot: 'Tissu',
  unitPriceFcfaSnapshot: 10000,
  quantity: 1,
  addedAt: DateTime(2026, 10, 14),
);

Future<_DepotFactice> _poser(
  WidgetTester tester, {
  required PromoCodePreview reponse,
  List<CartItem> panier = const [],
}) async {
  final depot = _DepotFactice(reponse);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        promoCodeRepositoryProvider.overrideWithValue(depot),
        cartItemsProvider.overrideWith((ref) => Stream.value(panier)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: Padding(
          padding: EdgeInsets.all(16),
          child: PromoCodeField(),
        )),
      ),
    ),
  );
  await tester.pump();
  return depot;
}

Future<void> _saisirEtAppliquer(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextFormField), code);
  await tester.tap(find.text('Appliquer le code'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('un code refusé affiche le motif du serveur', (tester) async {
    final depot = await _poser(
      tester,
      reponse: const PromoCodePreview(valid: false, reason: _refus),
      panier: [_article],
    );

    await _saisirEtAppliquer(tester, 'NIMPORTEQUOI');

    expect(depot.appels, 1, reason: 'le code doit être soumis au serveur');
    expect(find.text(_refus), findsOneWidget);
  });

  testWidgets('un code accepté remplace le champ par son résultat', (
    tester,
  ) async {
    await _poser(
      tester,
      reponse: const PromoCodePreview(
        valid: true,
        code: 'BIENVENUE',
        discountFcfa: 1500,
      ),
      panier: [_article],
    );

    await _saisirEtAppliquer(tester, 'BIENVENUE');

    expect(find.textContaining('BIENVENUE'), findsOneWidget);
    expect(find.text('Appliquer le code'), findsNothing);
  });

  testWidgets('un champ vide ne part pas au serveur, mais le dit', (
    tester,
  ) async {
    final depot = await _poser(
      tester,
      reponse: const PromoCodePreview(valid: false, reason: _refus),
      panier: [_article],
    );

    await tester.tap(find.text('Appliquer le code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(depot.appels, 0, reason: 'rien à vérifier sur un champ vide');
    // Le client a appuyé sur un bouton : il doit se passer quelque chose.
    expect(find.text('Saisissez un code promo.'), findsOneWidget);
  });

  testWidgets('une panne de vérification ne se lit pas comme un refus', (
    tester,
  ) async {
    // Dire « code invalide » quand c'est le réseau qui a lâché envoie le
    // client corriger un code qui était bon.
    final depot = _DepotFactice(
      const PromoCodePreview(valid: false),
    )..echoue = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          promoCodeRepositoryProvider.overrideWithValue(depot),
          cartItemsProvider.overrideWith((ref) => Stream.value([_article])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PromoCodeField()),
        ),
      ),
    );
    await tester.pump();

    await _saisirEtAppliquer(tester, 'BIENVENUE');

    expect(find.textContaining('Impossible de vérifier'), findsOneWidget);
    // Et le bouton doit redevenir cliquable, sinon l'écran paraît bloqué.
    expect(find.text('Appliquer le code'), findsOneWidget);
  });

  testWidgets('un panier vide le dit aussi', (tester) async {
    final depot = await _poser(
      tester,
      reponse: const PromoCodePreview(valid: false, reason: _refus),
      panier: const [],
    );

    await _saisirEtAppliquer(tester, 'BIENVENUE');

    expect(depot.appels, 0);
    expect(find.textContaining('panier est vide'), findsOneWidget);
  });
}
