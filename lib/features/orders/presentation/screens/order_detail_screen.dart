import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/voice_note_player.dart';
import 'package:mtc_app/features/delivery/domain/entities/courier_delivery.dart';
import 'package:mtc_app/features/delivery/presentation/providers/courier_history_providers.dart';
import 'package:mtc_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:mtc_app/features/delivery/presentation/widgets/courier_rating_sheet.dart';
import 'package:mtc_app/features/delivery/presentation/widgets/delivery_code_qr.dart';
import 'package:mtc_app/features/promo_codes/presentation/providers/promo_code_providers.dart';
import 'package:mtc_app/features/ratings/presentation/widgets/review_entry.dart';

import '../../domain/entities/fulfillment.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/payment.dart';
import '../../domain/order_reference.dart';
import '../../domain/order_status_transitions.dart';
import '../providers/order_providers.dart';
import '../widgets/order_cards.dart';

/// Une commande, au style du kit : sa carte de suivi en tête, où elle
/// arrive, comment elle se paie, puis la part de chaque boutique — ses
/// articles, son état, et ce qu'on peut y faire (suivre, montrer le QR au
/// livreur, laisser un avis, noter le livreur, annuler) — et le total.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commande = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          commande.valueOrNull == null
              ? 'Commande'
              : 'Commande ${commande.valueOrNull!.reference}',
        ),
      ),
      body: commande.when(
        skipLoadingOnReload: true,
        loading: () => ListView(
          padding: const EdgeInsets.all(ShopSizes.screenMargin),
          children: const [
            Skeleton(height: 150),
            SizedBox(height: ShopSizes.padding),
            Skeleton(height: 100),
            SizedBox(height: ShopSizes.padding),
            Skeleton(height: 220),
          ],
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'La commande n\'a pas pu être chargée',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(orderDetailProvider(orderId)),
            child: const Text('Réessayer'),
          ),
        ),
        data: (commande) => _Fiche(commande: commande),
      ),
    );
  }
}

class _Fiche extends StatelessWidget {
  const _Fiche({required this.commande});

  final Order commande;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aDomicile =
        commande.fulfillmentMethod == FulfillmentMethod.homeDelivery;
    final livraison = commande.supplierGroups.fold<int>(
      0,
      (s, g) => s + g.deliveryFeeFcfa,
    );
    // Déduit du total facturé plutôt que recalculé : les lignes du
    // récapitulatif tombent ainsi juste, quoi qu'en aient fait les remises.
    final articles = commande.totalFcfa - livraison - commande.priorityFeeFcfa;
    final paye = commande.paymentStatus == PaymentStatus.paid;

    // Annuler une part ne touche pas au total enregistré (`total_fcfa`) :
    // la fiche retire elle-même ce qui ne sera ni livré ni encaissé, pour
    // ne pas annoncer un montant que personne ne réclamera.
    final annulees = [
      for (final g in commande.supplierGroups)
        if (g.status == OrderStatus.cancelled) g,
    ];
    final toutAnnule =
        annulees.isNotEmpty &&
        annulees.length == commande.supplierGroups.length;
    final montantAnnule =
        annulees.fold<int>(
          0,
          (s, g) => s + g.subtotalFcfa + g.deliveryFeeFcfa,
        ) +
        (toutAnnule ? commande.priorityFeeFcfa : 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ShopSizes.screenMargin,
        ShopSizes.padding,
        ShopSizes.screenMargin,
        ShopSizes.screenMargin,
      ),
      children: [
        OrderStatusCard(
          reference: commande.reference,
          placedOn: DateFormatter.formatDayMonthYear(commande.placedAt),
          steps: orderSteps(commande.status),
        ),
        const SizedBox(height: ShopSizes.padding * 2),
        Text(
          aDomicile ? 'Livraison à domicile' : 'Point de livraison',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: ShopSizes.padding),
        AddressCard(
          // Le client voit toujours ses propres coordonnées ; la ville seule
          // ne servirait que si le serveur n'avait rien rendu.
          label: commande.clientContact?.addressLabel ?? commande.deliveryCity,
          lines: [
            commande.clientContact?.addressDetails ?? '',
            commande.deliveryCity,
          ],
          showCheck: false,
        ),
        if (aDomicile) _DetailsDeLivraison(commande: commande),
        InfoRow(
          label: 'Paiement',
          value: switch ((paye, toutAnnule)) {
            (true, _) =>
              'Payé${commande.mobileMoneyProvider == null ? '' : ' · ${commande.mobileMoneyProvider!.label}'}',
            // Rien ne sera livré : il n'y a rien à encaisser à la porte.
            (false, true) => 'Rien à régler',
            (false, false) => commande.paymentStatus.label,
          },
          valueColor: paye ? ShopColors.success : null,
        ),
        for (final groupe in commande.supplierGroups)
          _PartDUneBoutique(commande: commande, groupe: groupe),
        const SizedBox(height: ShopSizes.padding * 2),
        OrderSummaryCard(
          title: 'Récapitulatif',
          rows: [
            SummaryRow(
              label: 'Articles',
              value: CurrencyFormatter.formatFcfa(articles),
            ),
            SummaryRow(
              label: 'Livraison',
              value: livraison == 0
                  ? 'Gratuite'
                  : CurrencyFormatter.formatFcfa(livraison),
              valueColor: livraison == 0 ? ShopColors.success : null,
            ),
            if (commande.isPriority)
              SummaryRow(
                label: 'Commande prioritaire',
                value: CurrencyFormatter.formatFcfa(commande.priorityFeeFcfa),
              ),
            if (montantAnnule > 0)
              SummaryRow(
                label: toutAnnule ? 'Commande annulée' : 'Parts annulées',
                value: '-${CurrencyFormatter.formatFcfa(montantAnnule)}',
                valueColor: ShopColors.error,
              ),
          ],
          totals: [
            SummaryRow(
              label: 'Total',
              value: CurrencyFormatter.formatFcfa(
                commande.totalFcfa - montantAnnule,
              ),
              emphasized: true,
            ),
          ],
        ),
      ],
    );
  }
}

/// Téléphones, créneau et message à la boutique : seulement pour une
/// livraison à domicile, la seule qui en porte.
class _DetailsDeLivraison extends StatelessWidget {
  const _DetailsDeLivraison({required this.commande});

  final Order commande;

  @override
  Widget build(BuildContext context) {
    final message = commande.supplierMessageText;
    final vocal = commande.supplierMessageVoicePath;
    return Column(
      children: [
        const SizedBox(height: ShopSizes.padding / 2),
        if (commande.clientContact?.phone case final tel? when tel.isNotEmpty)
          InfoRow(label: 'Téléphone', value: tel),
        if (commande.clientContact?.alternatePhone case final tel?
            when tel.isNotEmpty)
          InfoRow(label: 'Autre numéro', value: tel),
        if (commande.deliveryDate case final date?)
          InfoRow(
            label: 'Créneau',
            value: [
              DateFormatter.formatDayMonth(date),
              ?commande.deliveryTimeSlotLabel,
            ].join(' · '),
          ),
        // Le message en entier : coupé à une ligne, « Appelez-moi en
        // arrivant, le… » ne dit plus rien de ce que la boutique a lu.
        if (commande.supplierMessageType == SupplierMessageType.text &&
            message != null &&
            message.isNotEmpty)
          InfoRow.stacked(label: 'Message pour la boutique', value: message),
        if (commande.supplierMessageType == SupplierMessageType.voice &&
            vocal != null)
          InfoRow.stacked(
            label: 'Message pour la boutique',
            child: VoiceNotePlayer(
              path: vocal,
              durationSeconds: commande.supplierMessageVoiceDurationSeconds,
              compact: true,
              bucket: 'order-messages',
              signed: true,
            ),
          ),
      ],
    );
  }
}

/// La part d'une boutique : son état, ses articles, ses frais, et les gestes
/// qui la concernent.
class _PartDUneBoutique extends StatelessWidget {
  const _PartDUneBoutique({required this.commande, required this.groupe});

  final Order commande;
  final OrderSupplierGroup groupe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rubrique = OrderHistoryCategory.of(groupe.status);
    return Padding(
      padding: const EdgeInsets.only(top: ShopSizes.padding * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  groupe.supplierName,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: ShopSizes.padding / 2),
              // L'état d'une part se lit sans lire : une pastille colorée.
              StatusPill(label: groupe.status.label, color: rubrique.color),
            ],
          ),
          if (groupe.status == OrderStatus.cancelled)
            Padding(
              padding: const EdgeInsets.only(top: ShopSizes.padding / 2),
              child: Text(
                // Un refus n'est pas une impasse muette : qui, et pourquoi.
                [
                  if (groupe.cancelledBy case final par?)
                    'Annulée par ${par.label}',
                  if (groupe.cancellationReason case final motif?
                      when motif.trim().isNotEmpty)
                    motif,
                ].join(' : '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ShopColors.error,
                ),
              ),
            ),
          for (final article in groupe.items)
            Padding(
              padding: const EdgeInsets.only(top: ShopSizes.padding),
              child: OrderItemLine(
                item: article,
                boutique: groupe.supplierName,
              ),
            ),
          const SizedBox(height: ShopSizes.padding / 2),
          _LigneDuCode(orderId: commande.id, groupId: groupe.id),
          SummaryRow(
            label: groupe.deliveryMode == DeliveryMode.mtcDelivery
                ? 'Livraison MTC'
                : 'Livraison par la boutique',
            value: groupe.deliveryFeeFcfa == 0
                ? 'Gratuite'
                : CurrencyFormatter.formatFcfa(groupe.deliveryFeeFcfa),
            valueColor: groupe.deliveryFeeFcfa == 0 ? ShopColors.success : null,
          ),
          if (groupe.status == OrderStatus.inTransit)
            Padding(
              padding: const EdgeInsets.only(top: ShopSizes.padding),
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push(AppRoutes.orderTrack(commande.id)),
                icon: const ShopIcon(ShopIcons.trackorder, size: 20),
                label: const Text('Suivre la livraison'),
              ),
            ),
          if (groupe.deliveryMode == DeliveryMode.mtcDelivery)
            _CodeDeRemise(groupId: groupe.id),
          if (groupe.status == OrderStatus.delivered)
            Padding(
              padding: const EdgeInsets.only(top: ShopSizes.padding),
              child: ReviewEntry(orderId: commande.id, groupId: groupe.id),
            ),
          if (groupe.status == OrderStatus.delivered &&
              groupe.deliveryMode == DeliveryMode.mtcDelivery)
            _NoterLeLivreur(groupId: groupe.id),
          if (canClientCancel(groupe.status))
            Padding(
              padding: const EdgeInsets.only(top: ShopSizes.padding),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ShopColors.error,
                ),
                onPressed: () =>
                    context.push(AppRoutes.orderCancel(commande.id, groupe.id)),
                child: const Text('Annuler la commande'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le code promo appliqué à cette part, sur la commande passée.
///
/// Lu par une RPC et non dans la table des codes : celle-ci est fermée au
/// client — c'est ce qui l'empêche d'énumérer les codes en vigueur — et le
/// libellé vient de l'instantané figé au moment de la commande (`0077`).
class _LigneDuCode extends ConsumerWidget {
  const _LigneDuCode({required this.orderId, required this.groupId});

  final String orderId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codes = ref.watch(orderPromoCodesProvider(orderId)).valueOrNull;
    final applique = codes?[groupId];
    if (applique == null) return const SizedBox.shrink();
    return SummaryRow(
      label: 'Code ${applique.code}',
      value: '-${CurrencyFormatter.formatFcfa(applique.discountFcfa)}',
      valueColor: ShopColors.success,
    );
  }
}

/// QR de remise, présenté au livreur à l'arrivée.
///
/// N'apparaît qu'une fois le colis retiré chez la boutique : avant, le
/// livreur n'est pas en route, et l'afficher plus tôt inviterait à le
/// montrer — ou à le transmettre — hors de la remise elle-même, ce qui est
/// exactement ce que ce code empêche.
class _CodeDeRemise extends ConsumerWidget {
  const _CodeDeRemise({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(deliveryForGroupProvider(groupId)).valueOrNull;
    if (course == null || course.status != DeliveryStatus.pickedUp) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: ShopSizes.padding),
      child: DeliveryCodeQr(
        deliveryId: course.id,
        kind: DeliveryCodeKind.delivery,
        title: 'Code de remise',
        instruction:
            'À montrer au livreur au moment de recevoir votre commande. '
            'Ne le communiquez à personne d\'autre.',
      ),
    );
  }
}

/// Noter le livreur, une fois la commande remise.
///
/// Distinct de « Laisser un avis », qui juge la **boutique** : la
/// marchandise et son acheminement sont deux prestations différentes, et une
/// seule note pour les deux pénaliserait un bon vendeur pour un livreur en
/// retard — ou l'inverse. Seulement pour une livraison MTC : sur une
/// livraison assurée par la boutique, il n'y a aucun livreur à noter.
class _NoterLeLivreur extends ConsumerWidget {
  const _NoterLeLivreur({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(deliveryForGroupProvider(groupId)).valueOrNull;
    // Une part livrée sans course : confiée à MTC et close autrement. Rien
    // à noter.
    if (course == null || course.status != DeliveryStatus.delivered) {
      return const SizedBox.shrink();
    }
    final note = ref.watch(myDeliveryRatingProvider(course.id)).valueOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: ShopSizes.padding / 2),
      child: OutlinedButton.icon(
        onPressed: () => showCourierRatingSheet(context, deliveryId: course.id),
        icon: ShopIcon(
          note == null ? ShopIcons.delivery : ShopIcons.starFilled,
          size: 20,
          tint: note == null,
        ),
        // Rappeler la note déjà donnée évite de la redonner en croyant que
        // la première n'est pas passée.
        label: Text(
          note == null
              ? 'Noter le livreur'
              : 'Livreur noté ${note.stars}/5 — modifier',
        ),
      ),
    );
  }
}
