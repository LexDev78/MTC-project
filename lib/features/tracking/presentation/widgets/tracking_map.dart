import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/app/theme/app_colors.dart';

import '../../domain/entities/delivery_tracking.dart';

/// OSM map showing the full route (static polyline + origin/destination
/// pins) plus a marker that glides — via an [AnimationController], not a
/// jump — to each new position the tracking stream emits (~every 2s).
class TrackingMap extends StatefulWidget {
  const TrackingMap({super.key, required this.tracking});

  final DeliveryTracking tracking;

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _animationController;
  late LatLng _segmentStart;
  late LatLng _segmentEnd;

  @override
  void initState() {
    super.initState();
    _segmentStart = widget.tracking.current;
    _segmentEnd = widget.tracking.current;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didUpdateWidget(covariant TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracking.current != widget.tracking.current) {
      _segmentStart = _animatedPosition;
      _segmentEnd = widget.tracking.current;
      _animationController
        ..reset()
        ..forward();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(_segmentEnd, _mapController.camera.zoom);
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  LatLng get _animatedPosition {
    final t = Curves.easeInOut.transform(_animationController.value);
    return LatLng(
      _segmentStart.latitude +
          (_segmentEnd.latitude - _segmentStart.latitude) * t,
      _segmentStart.longitude +
          (_segmentEnd.longitude - _segmentStart.longitude) * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracking = widget.tracking;

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, _) {
            return FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _animatedPosition,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mtc.mali_trade_connect',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: tracking.route,
                      strokeWidth: 4,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: tracking.origin,
                      width: 36,
                      height: 36,
                      child: const _PinIcon(
                        icon: Icons.storefront_rounded,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    Marker(
                      point: tracking.destination,
                      width: 36,
                      height: 36,
                      child: const _PinIcon(
                        icon: Icons.home_rounded,
                        color: AppColors.brandError,
                      ),
                    ),
                    Marker(
                      point: _animatedPosition,
                      width: 40,
                      height: 40,
                      child: const _PinIcon(
                        icon: Icons.local_shipping_rounded,
                        color: AppColors.mapVehicleAccent,
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            onPressed: () => _mapController.move(_animatedPosition, 13),
            child: const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    );
  }
}

class _PinIcon extends StatelessWidget {
  const _PinIcon({
    required this.icon,
    required this.color,
    this.filled = false,
  });

  final IconData icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: filled ? color : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      padding: const EdgeInsets.all(6),
      child: Icon(icon, size: 16, color: filled ? Colors.white : color),
    );
  }
}
