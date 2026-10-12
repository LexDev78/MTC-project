import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../providers/tracking_providers.dart';
import '../widgets/eta_banner.dart';
import '../widgets/tracking_map.dart';

class LiveTrackingScreen extends ConsumerWidget {
  const LiveTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(trackingParamsProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Suivi de livraison')),
      body: AsyncValueWidget(
        value: params,
        data: (params) {
          // Livraison assurée par le fournisseur lui-même : personne ne
          // transmet de position. Le dire franchement vaut mieux que laisser
          // tourner un chargement qui n'aboutira jamais — et mieux encore
          // qu'animer un livreur imaginaire.
          if (!params.isMtcDelivery) {
            return const MtcEmptyState(
              icon: Icons.storefront_rounded,
              title: 'Suivi indisponible',
              subtitle:
                  'Cette commande est livrée directement par le fournisseur. '
                  'Contactez-le pour connaître le point de situation.',
            );
          }
          return AsyncValueWidget(
            value: ref.watch(trackingStreamProvider(orderId)),
            data: (tracking) => Column(
              children: [
                EtaBanner(tracking: tracking),
                Expanded(child: TrackingMap(tracking: tracking)),
              ],
            ),
          );
        },
      ),
    );
  }
}
