import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mtc_app/features/promo_codes/presentation/providers/applied_promo_code_provider.dart';
import 'package:mtc_app/features/promo_codes/presentation/widgets/promo_code_field.dart';

import '../controllers/cart_controller.dart';
import '../providers/cart_providers.dart';
import '../widgets/cart_line_item.dart';

/// Le panier, d'après la maquette « Cart » du kit : les articles à
/// vérifier, le code promo, le récapitulatif, et « Commander ».
///
/// MTC y garde l'adresse de livraison en tête : les frais de livraison
/// dépendent de la distance, donc de l'adresse, et la voir avant de payer
/// évite de découvrir à l'étape suivante qu'on commandait vers son ancien
/// domicile.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  Future<void> _vider(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le panier ?'),
        content: const Text('Tous les articles seront retirés du panier.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ShopColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messager = ScaffoldMessenger.of(context);
    try {
      await ref.read(cartControllerProvider.notifier).clearCart();
    } catch (erreur) {
      messager.showSnackBar(
        SnackBar(
          content: Text(
            messagePourUtilisateur(
              erreur,
              repli: 'Le panier n\'a pas pu être vidé.',
            ),
          ),
        ),
      );
    }
  }

  /// Le panier entier part au paiement : un achat immédiat resté en attente
  /// ne doit pas prendre sa place.
  void _ecarterAchatImmediat(WidgetRef ref) =>
      ref.read(buyNowItemProvider.notifier).state = null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articles = ref.watch(cartItemsProvider);
    final aDesArticles = articles.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      body: articles.when(
        skipLoadingOnReload: true,
        loading: () => ListView(
          padding: const EdgeInsets.all(ShopSizes.screenMargin),
          children: [
            for (var i = 0; i < 3; i++) ...[
              const Skeleton(height: 71),
              const SizedBox(height: ShopSizes.padding * 1.5),
            ],
          ],
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'Le panier n\'a pas pu être chargé',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(cartItemsProvider),
            child: const Text('Réessayer'),
          ),
        ),
        data: (liste) {
          if (liste.isEmpty) {
            return IllustratedMessage(
              illustration: ShopIllustration.emptyState,
              title: 'Votre panier est vide',
              message: 'Parcourez le catalogue pour y ajouter des articles.',
              action: OutlinedButton(
                onPressed: () => context.go(AppRoutes.clientCatalogue),
                child: const Text('Découvrir le catalogue'),
              ),
            );
          }
          final codePossible =
              ref.watch(checkoutHasPromoCodeProvider).valueOrNull == true ||
              ref.watch(appliedPromoCodeProvider)?.valid == true;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.screenMargin,
              ShopSizes.padding / 2,
              ShopSizes.screenMargin,
              ShopSizes.screenMargin,
            ),
            children: [
              const _Adresse(),
              const SizedBox(height: ShopSizes.padding),
              SectionTitle(
                'Vérifier votre commande',
                padding: EdgeInsets.zero,
                actionLabel: 'Vider',
                onAction: () => _vider(context, ref),
              ),
              const SizedBox(height: ShopSizes.padding),
              for (final (index, article) in liste.indexed) ...[
                CartLineItem(item: article),
                if (index < liste.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: ShopSizes.padding,
                    ),
                    child: Divider(height: 1),
                  ),
              ],
              // Le champ n'apparaît que si un code peut s'appliquer à ce
              // panier (`cart_has_promo_code`, `0089`) : un champ qui ne
              // peut rien donner fait croire qu'on rate quelque chose. Un
              // code déjà accepté le garde, avec son « Retirer ».
              if (codePossible) ...[
                const SizedBox(height: ShopSizes.padding * 2),
                Text(
                  'Votre code promo',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: ShopSizes.padding),
                PromoCodeField(onBeforeApply: () => _ecarterAchatImmediat(ref)),
              ],
              const SizedBox(height: ShopSizes.padding * 1.5),
              const _Recapitulatif(),
            ],
          );
        },
      ),
      bottomNavigationBar: aDesArticles
          ? BottomActionBar(
              label: 'Commander',
              onPressed: () {
                _ecarterAchatImmediat(ref);
                context.push(AppRoutes.clientCheckout);
              },
            )
          : null,
    );
  }
}

/// « Livraison à … », la ligne de l'adresse par défaut.
class _Adresse extends ConsumerWidget {
  const _Adresse();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adresse = ref.watch(defaultAddressProvider);
    return ChevronListTile(
      icon: ShopIcons.address,
      contentPadding: EdgeInsets.zero,
      showDivider: false,
      title: adresse == null
          ? 'Ajouter une adresse de livraison'
          : 'Livraison à ${adresse.label} · ${adresse.details}, '
                '${adresse.city}',
      onTap: () => context.push(AppRoutes.clientProfileEdit),
    );
  }
}

/// Le récapitulatif du panier (« Order Summary » du kit). Les frais de
/// livraison ne sont connus qu'au paiement, une fois le mode et le lieu
/// choisis : le total d'ici les laisse de côté, et le dit.
class _Recapitulatif extends ConsumerWidget {
  const _Recapitulatif();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sousTotal = ref.watch(cartTotalFcfaProvider);
    final code = ref.watch(appliedPromoCodeProvider);
    final remise = code != null && code.valid
        ? code.discountFcfa.clamp(0, sousTotal)
        : 0;
    return OrderSummaryCard(
      title: 'Récapitulatif',
      rows: [
        SummaryRow(
          label: 'Sous-total',
          value: CurrencyFormatter.formatFcfa(sousTotal),
        ),
        if (remise > 0)
          SummaryRow(
            label: 'Code promo',
            value: '-${CurrencyFormatter.formatFcfa(remise)}',
            valueColor: ShopColors.success,
          ),
        SummaryRow(
          label: 'Livraison',
          value: 'À l\'étape suivante',
          valueColor: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ],
      totals: [
        SummaryRow(
          label: 'Total hors livraison',
          value: CurrencyFormatter.formatFcfa(sousTotal - remise),
          emphasized: true,
        ),
      ],
    );
  }
}
