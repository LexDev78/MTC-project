import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/courier_delivery.dart';
import '../providers/delivery_providers.dart';
import '../widgets/courier_navigation_map.dart';
import 'delivery_scan_screen.dart';

/// Feuille de route d'une course : la marchandise, où la retirer, où la
/// remettre, qui appeler.
///
/// L'ordre des blocs suit celui du trajet — retrait, puis remise — et non
/// celui des tables d'où viennent les données. Les scans de QR (accusé de
/// retrait chez le fournisseur, accusé de remise chez le client) viendront
/// se placer au bas de chaque bloc à l'étape 2.
class CourierDeliveryScreen extends ConsumerWidget {
  const CourierDeliveryScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(courierDeliveriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Course')),
      body: AsyncValueWidget(
        value: deliveries,
        data: (list) {
          final delivery = list.where((d) => d.id == deliveryId).firstOrNull;
          if (delivery == null) {
            return const MtcEmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Course introuvable',
              subtitle: 'Elle a peut-être été reprise par un autre livreur.',
            );
          }
          return _Body(delivery: delivery);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.delivery});

  final CourierDelivery delivery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            // « En cours de livraison » et le montant ne tiennent pas
            // toujours côte à côte (petit écran, grands caractères) : le
            // statut se tronque, le montant reste entier.
            Flexible(
              child: Chip(
                label: Text(
                  delivery.status.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Spacer(),
            Text(
              CurrencyFormatter.formatFcfa(delivery.deliveryFeeFcfa),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // En tête, avant les adresses : une fois en route, c'est la carte
        // qu'il regarde, pas les coordonnées en chiffres.
        CourierNavigationMap(delivery: delivery),

        _Section(
          icon: Icons.storefront_rounded,
          title: '1. Retrait',
          children: [
            _Line(label: 'Fournisseur', value: delivery.supplierName),
            if (delivery.supplierAddress != null)
              _Line(label: 'Adresse', value: delivery.supplierAddress!),
            _Line(label: 'Ville', value: delivery.supplierCity),
            for (final phone in delivery.supplierPhones)
              _Line(label: 'Téléphone', value: phone),
            if (delivery.supplierLatitude != null &&
                delivery.supplierLongitude != null)
              _Line(
                label: 'Coordonnées',
                value:
                    '${delivery.supplierLatitude!.toStringAsFixed(5)}, '
                    '${delivery.supplierLongitude!.toStringAsFixed(5)}',
              ),
          ],
        ),

        if (delivery.status == DeliveryStatus.accepted)
          _ScanButton(
            deliveryId: delivery.id,
            kind: DeliveryCodeKind.pickup,
            label: 'Scanner le code de retrait',
          ),

        _Section(
          icon: Icons.inventory_2_rounded,
          title: 'Marchandise',
          children: [
            for (final item in delivery.items)
              _Line(
                label: '${item.quantity} ×',
                value: item.variantName == null
                    ? item.productName
                    : '${item.productName} — ${item.variantName}',
              ),
            if (delivery.collectOnDelivery)
              _Line(
                label: 'À encaisser',
                value: CurrencyFormatter.formatFcfa(
                  delivery.subtotalFcfa + delivery.deliveryFeeFcfa,
                ),
                emphasis: true,
              ),
          ],
        ),

        _Section(
          icon: Icons.person_pin_circle_rounded,
          title: '2. Remise',
          children: [
            _Line(label: 'Client', value: delivery.clientName),
            if (delivery.clientPhone case final tel?)
              _Line(label: 'Téléphone', value: tel),
            if (delivery.clientAlternatePhone case final tel?
                when tel.isNotEmpty)
              _Line(label: 'Autre numéro', value: tel),
            if (delivery.deliveryAddressLabel case final adresse?)
              _Line(label: 'Adresse', value: adresse),
            _Line(label: 'Ville', value: delivery.deliveryCity),
            if (delivery.deliveryDetails case final indications?
                when indications.isNotEmpty)
              _Line(label: 'Indications', value: indications),
            if ((delivery.deliveryLatitude, delivery.deliveryLongitude)
                case (final lat?, final lng?))
              _Line(
                label: 'Coordonnées',
                value: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
              ),
            // Ce qui manque est retiré par le serveur (`0120`) : le dire,
            // sinon une ligne absente passe pour une panne.
            if (_retrait(delivery) case final note?)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  note,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),

        if (delivery.status == DeliveryStatus.pickedUp)
          _ScanButton(
            deliveryId: delivery.id,
            kind: DeliveryCodeKind.delivery,
            label: 'Scanner le code de remise',
          ),

        if (delivery.status == DeliveryStatus.delivered)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(child: Text('Livraison accusée. Course terminée.')),
              ],
            ),
          ),
      ],
    );
  }
}

/// Pourquoi une coordonnée du client manque, quand elle manque.
String? _retrait(CourierDelivery delivery) => switch (delivery.status) {
  DeliveryStatus.offered when delivery.clientPhone == null =>
    'Le numéro du client s\'affichera quand vous aurez accepté la course.',
  DeliveryStatus.delivered || DeliveryStatus.cancelled =>
    'Course terminée : le numéro et l\'adresse du client ne sont plus '
        'affichés.',
  _ => null,
};

/// Ouvre la caméra pour l'étape attendue.
///
/// Le libellé annonce l'étape, mais c'est le serveur qui la détermine : si la
/// course a changé entre-temps, c'est lui qui refuse, pas ce bouton.
class _ScanButton extends ConsumerWidget {
  const _ScanButton({
    required this.deliveryId,
    required this.kind,
    required this.label,
  });

  final String deliveryId;
  final DeliveryCodeKind kind;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: MtcPrimaryButton(
        label: label,
        icon: Icons.qr_code_scanner_rounded,
        onPressed: () async {
          final status = await Navigator.of(context).push<DeliveryStatus>(
            MaterialPageRoute(
              builder: (_) => DeliveryScanScreen(
                deliveryId: deliveryId,
                expected: kind,
              ),
            ),
          );
          if (status == null || !context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == DeliveryStatus.pickedUp
                    ? 'Retrait accusé. En route vers le client.'
                    : 'Livraison accusée. Course terminée.',
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
                color: emphasis ? scheme.tertiary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
