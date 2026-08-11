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
    final trackingAsync = ref.watch(trackingStreamProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Suivi de livraison')),
      body: AsyncValueWidget(
        value: trackingAsync,
        data: (tracking) {
          return Column(
            children: [
              EtaBanner(tracking: tracking),
              Expanded(child: TrackingMap(tracking: tracking)),
            ],
          );
        },
      ),
    );
  }
}
