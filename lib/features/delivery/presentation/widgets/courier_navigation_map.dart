import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/app/theme/app_colors.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/features/tracking/data/datasources/osrm_route_datasource.dart';
import 'package:mtc_app/features/tracking/presentation/widgets/map_canvas.dart';

import '../../domain/entities/courier_delivery.dart';
import '../providers/courier_position_provider.dart';
import '../providers/navigation_providers.dart';

/// La carte du livreur : où il est, où il va **maintenant**, et par où.
///
/// « Maintenant » est la clé : avant le retrait, sa destination est le
/// fournisseur ; après, c'est le client. Afficher le trajet complet des deux
/// étapes d'un coup lui donnerait un tracé qu'il ne doit pas suivre encore.
///
/// L'itinéraire se refait tout seul s'il quitte la route — c'est
/// `RouteFollower` qui le décide, à partir de sa distance au **tracé** et non
/// au point de départ (voir `navigationRouteProvider`).
class CourierNavigationMap extends ConsumerWidget {
  const CourierNavigationMap({super.key, required this.delivery});

  final CourierDelivery delivery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final leg = delivery.currentLeg;
    if (leg == null) return const SizedBox.shrink();

    final position = ref.watch(courierPositionProvider).valueOrNull;
    final me = position == null
        ? null
        : LatLng(position.latitude, position.longitude);
    final route = ref.watch(navigationRouteProvider(delivery.id)).valueOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                leg.isPickup
                    ? Icons.storefront_rounded
                    : Icons.person_pin_circle_rounded,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  leg.isPickup
                      ? 'Direction : ${delivery.supplierName}'
                      : 'Direction : ${delivery.clientName}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (route != null)
                Text(
                  '${(route.duration.inSeconds / 60).ceil()} min · '
                  '${route.distanceKm.toStringAsFixed(1)} km',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: SizedBox(
              height: 260,
              child: me == null
                  // Sans position, une carte n'aurait rien à centrer et
                  // afficherait le monde entier. On dit pourquoi.
                  ? ColoredBox(
                      color: scheme.surfaceContainerHigh,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            'Activez votre position pour voir l\'itinéraire.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    )
                  : GestureDetector(
                      // Aperçu figé dans la fiche, interactif en grand : voir
                      // `MapCanvas.interactive`.
                      onTap: () => _ouvrirEnGrand(context, me, leg, route),
                      child: MapCanvas(
                        interactive: false,
                        follow: me,
                        route: route?.points ?? [me, leg.target],
                        waypoints: [
                        (
                          point: leg.target,
                          icon: leg.isPickup
                              ? Icons.storefront_rounded
                              : Icons.home_rounded,
                          color: leg.isPickup
                              ? AppColors.brandPrimary
                              : AppColors.brandError,
                        ),
                        ],
                        vehicle: me,
                      ),
                    ),
            ),
          ),
          if (me != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _ouvrirEnGrand(context, me, leg, route),
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: const Text('Ouvrir la carte'),
              ),
            ),
        ],
      ),
    );
  }

  void _ouvrirEnGrand(
    BuildContext context,
    LatLng me,
    DeliveryLeg leg,
    RoadRoute? route,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              leg.isPickup
                  ? 'Vers ${delivery.supplierName}'
                  : 'Vers ${delivery.clientName}',
            ),
          ),
          body: MapCanvas(
            follow: me,
            route: route?.points ?? [me, leg.target],
            vehicle: me,
            waypoints: [
              (
                point: leg.target,
                icon: leg.isPickup
                    ? Icons.storefront_rounded
                    : Icons.home_rounded,
                color: leg.isPickup
                    ? AppColors.brandPrimary
                    : AppColors.brandError,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
