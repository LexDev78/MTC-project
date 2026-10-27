import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/app/theme/app_colors.dart';

import 'map_tiles.dart';

/// Un point fixe à montrer sur la carte : boutique, domicile, point de
/// retrait.
typedef MapWaypoint = ({LatLng point, IconData icon, Color color});

/// La carte, une seule fois pour toute l'app : les tuiles, **leur
/// attribution**, le tracé, les repères et le recentrage.
///
/// Écrite pour être partagée entre le suivi côté client et la navigation côté
/// livreur. Deux cartes construites séparément finiraient par diverger sur
/// ce qui compte le moins visiblement : la licence. Les tuiles
/// d'OpenStreetMap imposent de citer leurs contributeurs, et c'est le genre
/// d'exigence qu'on oublie dans la deuxième copie.
class MapCanvas extends StatefulWidget {
  const MapCanvas({
    super.key,
    required this.follow,
    required this.route,
    required this.waypoints,
    this.vehicle,
    this.initialZoom = 14,
    this.interactive = true,
  });

  /// Le point que la carte suit quand il bouge.
  final LatLng follow;

  final List<LatLng> route;
  final List<MapWaypoint> waypoints;

  /// Position mobile (le livreur), animée d'un point au suivant.
  final LatLng? vehicle;

  final double initialZoom;

  /// Une carte **posée dans une page qui défile** doit se taire : sinon le
  /// doigt qui veut faire défiler la fiche déplace la carte à la place, et
  /// l'utilisateur se retrouve perdu à l'autre bout de la ville sans avoir
  /// rien demandé. Dans ce cas elle sert d'aperçu, et c'est un appui qui
  /// l'ouvre en grand, là où elle occupe tout l'écran et peut répondre aux
  /// gestes sans ambiguïté.
  final bool interactive;

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas>
    with SingleTickerProviderStateMixin {
  final MapController _controller = MapController();
  late final AnimationController _animation;
  late LatLng _from;
  late LatLng _to;

  /// Vrai une fois la carte réellement montée. `MapController.move` lancé
  /// avant cela lève une exception : le contrôleur n'est rattaché à rien.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _from = widget.vehicle ?? widget.follow;
    _to = _from;
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(covariant MapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.vehicle ?? widget.follow;
    if (next != _to) {
      // On repart de la position *affichée*, pas de la précédente reçue :
      // sinon une position qui arrive pendant l'animation la ferait sauter
      // en arrière avant de repartir.
      _from = _animated;
      _to = next;
      _animation
        ..reset()
        ..forward();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ready) {
          _controller.move(_to, _controller.camera.zoom);
        }
      });
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  LatLng get _animated {
    final t = Curves.easeInOut.transform(_animation.value);
    return LatLng(
      _from.latitude + (_to.latitude - _from.latitude) * t,
      _from.longitude + (_to.longitude - _from.longitude) * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) => FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _animated,
              initialZoom: widget.initialZoom,
              onMapReady: () => _ready = true,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none,
              ),
            ),
            children: [
              mtcTileLayer(),
              if (widget.route.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.route,
                      strokeWidth: 5,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final waypoint in widget.waypoints)
                    Marker(
                      point: waypoint.point,
                      width: 36,
                      height: 36,
                      child: MapPin(
                        icon: waypoint.icon,
                        color: waypoint.color,
                      ),
                    ),
                  if (widget.vehicle != null)
                    Marker(
                      point: _animated,
                      width: 40,
                      height: 40,
                      child: const MapPin(
                        icon: Icons.local_shipping_rounded,
                        color: AppColors.mapVehicleAccent,
                        filled: true,
                      ),
                    ),
                ],
              ),
              // Exigée par la licence des tuiles OpenStreetMap. Elle manquait
              // sur la carte de suivi : une carte sans attribution n'est pas
              // seulement impolie, elle est hors des conditions d'usage.
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap'),
                ],
              ),
            ],
          ),
        ),
        if (widget.interactive)
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
            heroTag: null,
              onPressed: () => _ready
                  ? _controller.move(_animated, widget.initialZoom)
                  : null,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
      ],
    );
  }
}

/// Repère circulaire, creux pour un point fixe, plein pour le véhicule.
class MapPin extends StatelessWidget {
  const MapPin({
    super.key,
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
