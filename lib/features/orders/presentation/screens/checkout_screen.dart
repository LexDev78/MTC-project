import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/features/cart/domain/entities/cart_item.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/shop_product_data.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mtc_app/features/profile/presentation/widgets/address_form_sheet.dart';
import 'package:mtc_app/features/profile/presentation/widgets/default_address.dart';
import 'package:mtc_app/features/promo_codes/presentation/providers/applied_promo_code_provider.dart';
import 'package:mtc_app/features/promo_codes/presentation/widgets/promo_code_field.dart';

import '../../domain/entities/fulfillment.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/payment.dart';
import '../controllers/checkout_controller.dart';
import '../providers/checkout_providers.dart';
import '../widgets/mobile_money_payment_sheet.dart';
import '../widgets/supplier_message_field.dart';

/// Le libellé du mode de paiement choisi, pour la ligne de l'écran.
String libelleDuPaiement(
  PaymentMethod methode,
  MobileMoneyProvider operateur,
) => methode == PaymentMethod.onDelivery ? 'À la livraison' : operateur.label;

/// Le paiement, d'après la maquette « Review » du kit : où recevoir la
/// commande, comment payer, l'option mise en avant (« Commande
/// prioritaire » à la place de l'emballage cadeau), le récapitulatif, puis
/// les articles — et le bouton qui commande.
///
/// MTC y garde ce que la maquette n'a pas : le point de livraison au lieu
/// de l'adresse, le créneau, les numéros à joindre, le message à la
/// boutique, et pour chaque boutique qui livre (elle-même, ou MTC).
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final StateController<CartItem?> _achatImmediat;

  @override
  void initState() {
    super.initState();
    _achatImmediat = ref.read(buyNowItemProvider.notifier);
  }

  @override
  void dispose() {
    // Un achat immédiat ne vaut que pour ce passage au paiement : quitté,
    // commandé ou non, il ne doit pas rester en embuscade — le panier le
    // prendrait sinon pour la commande en cours (code promo compris).
    // Après la fin de l'image en cours (pas d'écriture pendant que l'arbre se
    // démonte), et seulement si le conteneur vit encore : à la
    // déconnexion, il part avec l'écran.
    final achat = _achatImmediat;
    Future.microtask(() {
      if (achat.mounted) achat.state = null;
    });
    super.dispose();
  }

  Future<void> _commander(int total) async {
    final messager = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (ref.read(paymentMethodProvider) == PaymentMethod.now &&
        ref.read(mobileMoneyProviderChoiceProvider) == null) {
      final paye = await showMobileMoneyPaymentSheet(
        context,
        amountFcfa: total,
      );
      if (!paye || !mounted) return;
    }
    final ok = await ref.read(checkoutControllerProvider.notifier).placeOrder();
    if (!mounted) return;
    if (ok) {
      final commande = ref.read(checkoutControllerProvider).valueOrNull;
      if (commande != null) {
        unawaited(router.pushReplacement(AppRoutes.orderSuccess(commande.id)));
      }
      return;
    }
    messager.showSnackBar(
      SnackBar(
        content: Text(
          messagePourUtilisateur(
            ref.read(checkoutControllerProvider).error,
            repli: 'La commande n\'a pas pu être passée.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupes = ref.watch(checkoutGroupsProvider);
    final enCours = ref.watch(checkoutControllerProvider).isLoading;
    final reception = ref.watch(fulfillmentMethodProvider);
    final aDomicile = reception == FulfillmentMethod.homeDelivery;
    final prioritaire = aDomicile && ref.watch(isPriorityOrderProvider);

    final liste = groupes.valueOrNull ?? const [];
    final sousTotal = liste.fold<int>(0, (s, g) => s + g.subtotalFcfa);
    final remise = liste.fold<int>(0, (s, g) => s + g.promoDiscountFcfa);
    var livraison = 0;
    for (final g in liste) {
      final parMtc = aDomicile
          ? _modeDuGroupe(ref, g) == DeliveryMode.mtcDelivery
          // Au point de livraison, c'est MTC qui va chercher le colis.
          : g.allowsMtcDelivery;
      if (parMtc) livraison += g.mtcDeliveryFeeFcfa;
    }
    final fraisPriorite = prioritaire ? priorityOrderFeeFcfa : 0;
    final total = sousTotal + livraison + fraisPriorite;
    final paiementImmediat =
        ref.watch(paymentMethodProvider) == PaymentMethod.now &&
        ref.watch(mobileMoneyProviderChoiceProvider) == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Revue de la commande')),
      body: groupes.when(
        // Un code promo, un mode de livraison changé : les groupes se
        // recalculent. Sans cette option, chacun remplacerait la page par un
        // chargement — on perdrait le défilement pour un seul montant.
        skipLoadingOnReload: true,
        loading: () => ListView(
          padding: const EdgeInsets.all(ShopSizes.screenMargin),
          children: const [
            Skeleton(height: 48),
            SizedBox(height: ShopSizes.padding),
            Skeleton(height: 120),
            SizedBox(height: ShopSizes.padding),
            Skeleton(height: 56),
            SizedBox(height: ShopSizes.padding),
            Skeleton(height: 160),
          ],
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'La commande n\'a pas pu être préparée',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(checkoutGroupsProvider),
            child: const Text('Réessayer'),
          ),
        ),
        data: (groupes) {
          if (groupes.isEmpty) {
            return IllustratedMessage(
              illustration: ShopIllustration.emptyState,
              title: 'Rien à commander',
              message: 'Votre panier est vide.',
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
              ShopSegmentedButtons(
                labels: const ['À domicile', 'Point de livraison'],
                selected: aDomicile ? 0 : 1,
                onChanged: (i) =>
                    ref.read(fulfillmentMethodProvider.notifier).state = i == 0
                    ? FulfillmentMethod.homeDelivery
                    : FulfillmentMethod.pickupPoint,
              ),
              const SizedBox(height: ShopSizes.padding),
              if (aDomicile) const _Adresse() else const _PointsDeLivraison(),
              if (aDomicile) ...[
                const SizedBox(height: ShopSizes.padding * 1.5),
                const _Creneau(),
                const SizedBox(height: ShopSizes.padding),
                const _Contacts(),
                _Livraisons(groupes: groupes),
              ],
              const _LigneDePaiement(),
              if (aDomicile) ...[
                const SizedBox(height: ShopSizes.padding * 1.5),
                ToggleCard(
                  icon: ShopIcons.flashlight,
                  // Court, comme « Make it a Gift » : à côté de la pastille
                  // et de l'interrupteur, « Commande prioritaire » passait
                  // sur deux lignes.
                  title: 'En priorité',
                  subtitle:
                      'Préparée en premier, pour '
                      '${CurrencyFormatter.formatFcfa(priorityOrderFeeFcfa)}',
                  value: prioritaire,
                  onChanged: (v) =>
                      ref.read(isPriorityOrderProvider.notifier).state = v,
                ),
              ],
              // Le champ n'apparaît que si un code peut s'appliquer
              // (`cart_has_promo_code`, `0089`) ; un code déjà accepté le
              // garde, avec son « Retirer ».
              if (codePossible) ...[
                const SizedBox(height: ShopSizes.padding * 1.5),
                const PromoCodeField(),
              ],
              const SizedBox(height: ShopSizes.padding * 1.5),
              OrderSummaryCard(
                title: 'Récapitulatif',
                rows: [
                  // L'ordre d'un calcul qu'on suit du doigt : le sous-total
                  // *avant* remise, la remise, puis le reste. Posée sous un
                  // sous-total qui la contenait déjà, la remise paraissait
                  // n'avoir pas été faite.
                  SummaryRow(
                    label: 'Sous-total',
                    value: CurrencyFormatter.formatFcfa(sousTotal + remise),
                  ),
                  if (remise > 0)
                    SummaryRow(
                      label: 'Code promo',
                      value: '-${CurrencyFormatter.formatFcfa(remise)}',
                      valueColor: ShopColors.success,
                    ),
                  SummaryRow(
                    label: 'Livraison',
                    value: livraison == 0
                        ? 'Gratuite'
                        : CurrencyFormatter.formatFcfa(livraison),
                    valueColor: livraison == 0 ? ShopColors.success : null,
                  ),
                  if (fraisPriorite > 0)
                    SummaryRow(
                      label: 'Commande prioritaire',
                      value: CurrencyFormatter.formatFcfa(fraisPriorite),
                    ),
                ],
                totals: [
                  SummaryRow(
                    label: 'Total',
                    value: CurrencyFormatter.formatFcfa(total),
                    emphasized: true,
                  ),
                ],
              ),
              const SizedBox(height: ShopSizes.padding * 2),
              Text(
                'Vérifier votre commande',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final g in groupes) _ArticlesDuGroupe(groupe: g),
            ],
          );
        },
      ),
      bottomNavigationBar: liste.isEmpty
          ? null
          : BottomActionBar(
              label: paiementImmediat
                  ? 'Payer et commander'
                  : 'Confirmer la commande',
              isLoading: enCours,
              onPressed: () => _commander(total),
            ),
    );
  }
}

/// L'adresse de livraison (carte d'adresse des maquettes), ou de quoi en
/// ajouter une.
class _Adresse extends ConsumerWidget {
  const _Adresse();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adresse = ref.watch(defaultAddressProvider);
    if (adresse == null) {
      return DashedButton(
        label: 'Ajouter une adresse de livraison',
        icon: ShopIcons.address,
        onTap: () => showAddressFormSheet(context),
      );
    }
    // Le ruban ne dit « Par défaut » que si le client l'a choisie : sans
    // choix, le paiement prend la première adresse, sans la proclamer.
    final choisie = ref.watch(chosenDefaultAddressIdProvider) == adresse.id;
    return AddressCard(
      label: adresse.label,
      lines: [adresse.details, adresse.city],
      isDefault: choisie,
      selected: !choisie,
      onTap: () => showAddressPickerSheet(context),
      trailing: TextButton(
        onPressed: () => showAddressPickerSheet(context),
        child: const Text('Changer'),
      ),
    );
  }
}

/// Les points de livraison MTC, à choisir d'un toucher.
class _PointsDeLivraison extends ConsumerWidget {
  const _PointsDeLivraison();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pickupPointsProvider);
    final choisi = ref.watch(selectedPickupPointProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choisissez un point de retrait',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final point in points) ...[
          const SizedBox(height: ShopSizes.padding),
          AddressCard(
            label: point.name,
            lines: [point.address, point.city],
            selected: point == choisi,
            showCheck: point == choisi,
            onTap: () =>
                ref.read(selectedPickupPointProvider.notifier).state = point,
          ),
        ],
      ],
    );
  }
}

/// Le jour et la tranche horaire de la livraison à domicile.
class _Creneau extends ConsumerWidget {
  const _Creneau();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jours = ref.watch(deliveryDateOptionsProvider);
    final jour = ref.watch(selectedDeliveryDateProvider);
    final tranche = ref.watch(selectedDeliveryTimeSlotProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Créneau de livraison',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: ShopSizes.padding),
        Wrap(
          spacing: ShopSizes.padding / 2,
          runSpacing: ShopSizes.padding / 2,
          children: [
            for (final date in jours)
              ShopPill(
                // « jeu. 22 » : sur trois jours, le mois n'apprend rien et
                // faisait passer les pastilles sur deux lignes.
                label: '${DateFormatter.weekdayShort(date)} ${date.day}',
                active: DateUtils.isSameDay(date, jour),
                onTap: () =>
                    ref.read(selectedDeliveryDateProvider.notifier).state =
                        date,
              ),
          ],
        ),
        const SizedBox(height: ShopSizes.padding / 2),
        Wrap(
          spacing: ShopSizes.padding / 2,
          runSpacing: ShopSizes.padding / 2,
          children: [
            for (final creneau in deliveryTimeSlotOptions)
              ShopPill(
                label: creneau,
                active: creneau == tranche,
                onTap: () =>
                    ref.read(selectedDeliveryTimeSlotProvider.notifier).state =
                        creneau,
              ),
          ],
        ),
      ],
    );
  }
}

/// Les numéros où joindre le client, et son message à la boutique.
class _Contacts extends ConsumerWidget {
  const _Contacts();

  Future<String?> _saisir(
    BuildContext context, {
    required String titre,
    required String depart,
  }) {
    final champ = TextEditingController(text: depart);
    final formulaire = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titre),
        content: Form(
          key: formulaire,
          child: TextFormField(
            controller: champ,
            autofocus: true,
            keyboardType: TextInputType.phone,
            validator: Validators.phone,
            decoration: const InputDecoration(hintText: '+223 …'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (formulaire.currentState?.validate() ?? true) {
                Navigator.of(context).pop(champ.text.trim());
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telephone = ref.watch(courierPhoneProvider);
    final autre = ref.watch(alternatePhoneProvider);
    return Column(
      children: [
        ChevronListTile(
          icon: ShopIcons.call,
          title: telephone.isEmpty ? 'Téléphone pour le livreur' : telephone,
          fontSize: 16,
          contentPadding: EdgeInsets.zero,
          dividerAbove: true,
          onTap: () async {
            final saisi = await _saisir(
              context,
              titre: 'Téléphone pour le livreur',
              depart: telephone,
            );
            if (saisi != null) {
              ref.read(courierPhoneProvider.notifier).state = saisi;
            }
          },
        ),
        ChevronListTile(
          icon: ShopIcons.call,
          title: autre ?? 'Ajouter un autre numéro',
          fontSize: 16,
          contentPadding: EdgeInsets.zero,
          showChevron: autre == null,
          trailing: autre == null
              ? null
              : IconButton(
                  tooltip: 'Retirer ce numéro',
                  onPressed: () =>
                      ref.read(alternatePhoneProvider.notifier).state = null,
                  icon: const ShopIcon(ShopIcons.close, size: 18),
                ),
          onTap: () async {
            final saisi = await _saisir(
              context,
              titre: 'Autre numéro de téléphone',
              depart: autre ?? '',
            );
            if (saisi != null) {
              ref.read(alternatePhoneProvider.notifier).state = saisi;
            }
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: ShopSizes.padding / 4),
          child: SupplierMessageField(),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Qui livre ce que vend chaque boutique : une ligne par boutique, comme
/// « Mode de paiement », qui ouvre le choix quand elle accepte les deux.
class _Livraisons extends ConsumerWidget {
  const _Livraisons({required this.groupes});

  final List<CheckoutGroupView> groupes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: ShopSizes.padding * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Livraison', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: ShopSizes.padding / 2),
          for (final groupe in groupes)
            ChevronListTile(
              icon: ShopIcons.delivery,
              title: groupe.supplierName,
              fontSize: 16,
              contentPadding: EdgeInsets.zero,
              showChevron:
                  groupe.allowsSelfDelivery && groupe.allowsMtcDelivery,
              trailingText:
                  _modeDuGroupe(ref, groupe) == DeliveryMode.selfDelivery
                  ? 'Par la boutique'
                  : CurrencyFormatter.formatFcfa(groupe.mtcDeliveryFeeFcfa),
              onTap: groupe.allowsSelfDelivery && groupe.allowsMtcDelivery
                  ? () => showShopSheet<void>(
                      context,
                      heightFactor: 0.7,
                      child: _ChoixDuLivreur(groupe: groupe),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Le mode retenu pour un groupe : le choix du client, sinon la livraison
/// par la boutique quand elle la propose — la moins chère.
DeliveryMode _modeDuGroupe(WidgetRef ref, CheckoutGroupView groupe) =>
    ref.watch(deliveryModeChoiceProvider(groupe.supplierId)) ??
    (groupe.allowsSelfDelivery
        ? DeliveryMode.selfDelivery
        : DeliveryMode.mtcDelivery);

/// Le choix du livreur d'une boutique, avec les cartes « Shipping methods »
/// du kit : la carte retenue est mise en avant.
class _ChoixDuLivreur extends ConsumerWidget {
  const _ChoixDuLivreur({required this.groupe});

  final CheckoutGroupView groupe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choisi = _modeDuGroupe(ref, groupe);
    void choisir(DeliveryMode mode) {
      ref.read(deliveryModeChoiceProvider(groupe.supplierId).notifier).state =
          mode;
      Navigator.of(context).pop();
    }

    final options = [
      (
        mode: DeliveryMode.selfDelivery,
        carte: (bool enAvant) => ShippingMethodCard(
          accent: enAvant ? ShippingAccent.primary : ShippingAccent.none,
          icon: ShopIcons.stores,
          title: 'Par la boutique',
          subtitle: 'La boutique vous contacte pour convenir de la livraison.',
          price: 'Gratuit',
          footer: 'Aucun frais de livraison MTC',
        ),
      ),
      (
        mode: DeliveryMode.mtcDelivery,
        carte: (bool enAvant) => ShippingMethodCard(
          accent: enAvant ? ShippingAccent.primary : ShippingAccent.none,
          icon: ShopIcons.standard,
          title: 'Livraison MTC',
          subtitle: 'Un livreur MTC, suivi en direct jusqu\'à votre porte.',
          price: CurrencyFormatter.formatFcfa(groupe.mtcDeliveryFeeFcfa),
          footer: 'Selon la distance et le poids',
        ),
      ),
    ];

    return Column(
      children: [
        SheetHeader(title: groupe.supplierName),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.screenMargin,
              ShopSizes.padding / 2,
              ShopSizes.screenMargin,
              ShopSizes.screenMargin,
            ),
            children: [
              for (final option in options) ...[
                Semantics(
                  button: true,
                  selected: option.mode == choisi,
                  child: GestureDetector(
                    onTap: () => choisir(option.mode),
                    child: option.carte(option.mode == choisi),
                  ),
                ),
                const SizedBox(height: ShopSizes.padding),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// « Mode de paiement » (la ligne de la maquette), qui ouvre son écran.
class _LigneDePaiement extends ConsumerWidget {
  const _LigneDePaiement();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methode = ref.watch(paymentMethodProvider);
    final paye = ref.watch(mobileMoneyProviderChoiceProvider);
    final operateur = ref.watch(preferredMobileMoneyProvider);
    return Padding(
      padding: const EdgeInsets.only(top: ShopSizes.padding),
      child: ChevronListTile(
        icon: ShopIcons.card,
        title: 'Mode de paiement',
        fontSize: 16,
        contentPadding: EdgeInsets.zero,
        dividerAbove: true,
        trailingText: paye != null
            ? 'Payé · ${paye.label}'
            : libelleDuPaiement(methode, operateur),
        onTap: () => context.push(AppRoutes.clientCheckoutPayment),
      ),
    );
  }
}

/// Les articles d'une boutique, en lignes du kit.
class _ArticlesDuGroupe extends ConsumerWidget {
  const _ArticlesDuGroupe({required this.groupe});

  final CheckoutGroupView groupe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final article in groupe.items)
          Padding(
            padding: const EdgeInsets.only(top: ShopSizes.padding),
            child: _Article(article: article, boutique: groupe.supplierName),
          ),
      ],
    );
  }
}

class _Article extends ConsumerWidget {
  const _Article({required this.article, required this.boutique});

  final CartItem article;
  final String boutique;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final produit = ref
        .watch(productDetailProvider(article.productId))
        .valueOrNull;
    final variante = produit?.variants.firstWhereOrNull(
      (v) => v.id == article.variantId,
    );
    // Le prix courant, remise de quantité comprise — celui que
    // `place_order` facturera — et non celui figé à la mise au panier.
    final prix = produit?.unitPricing(
      basePriceFcfa: variante?.priceFcfa,
      quantity: article.quantity,
    );
    return ShopProductListItem(
      data: ShopProductData(
        imagePath:
            variante?.imageUrls.firstOrNull ?? produit?.imageUrls.firstOrNull,
        brand: boutique,
        title: article.productNameSnapshot,
        priceFcfa: prix?.priceFcfa ?? article.unitPriceFcfaSnapshot,
        compareAtFcfa: prix?.compareAtFcfa,
      ),
      footer: Text(
        [
          if (article.variantNameSnapshot case final nom?) nom,
          'Quantité : ${article.quantity}',
        ].join(' · '),
      ),
    );
  }
}
