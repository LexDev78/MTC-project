import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_colors.dart';

import '../../domain/entities/delivery_tracking.dart';
import 'map_canvas.dart';

/// Suivi côté client : la boutique, son domicile, et le livreur qui avance
/// entre les deux.
///
/// Toute la mécanique de carte — tuiles, attribution, animation du véhicule,
/// recentrage — vit dans [MapCanvas], partagée avec la carte du livreur. Ce
/// widget ne décide plus que de ce qu'il y a à montrer.
class TrackingMap extends StatelessWidget {
  const TrackingMap({super.key, required this.tracking});

  final DeliveryTracking tracking;

  @override
  Widget build(BuildContext context) {
    return MapCanvas(
      follow: tracking.current,
      route: tracking.route,
      vehicle: tracking.current,
      initialZoom: 13,
      waypoints: [
        (
          point: tracking.origin,
          icon: Icons.storefront_rounded,
          color: AppColors.brandPrimary,
        ),
        (
          point: tracking.destination,
          icon: Icons.home_rounded,
          color: AppColors.brandError,
        ),
      ],
    );
  }
}
