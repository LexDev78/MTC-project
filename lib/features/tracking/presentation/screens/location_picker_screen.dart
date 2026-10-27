import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/app/theme/app_colors.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../widgets/map_tiles.dart';

/// Choisir un point précis sur la carte.
///
/// Remplace la seule méthode qu'avait l'app pour situer une adresse : lire le
/// nom de la ville et prendre ses coordonnées de centre. Toutes les boutiques
/// de Bamako se retrouvaient ainsi au même endroit, tous les clients aussi —
/// et un livreur envoyé du centre-ville vers le centre-ville.
///
/// Le repère est **fixe au milieu de l'écran** et c'est la carte qui glisse
/// dessous. C'est plus sûr sur un téléphone que de faire glisser un marqueur :
/// le doigt ne cache jamais le point qu'on vise, et le geste reste le même
/// quel que soit le niveau de zoom.
///
/// Aucun service de recherche d'adresse n'intervient : à Bamako beaucoup
/// d'adresses ne sont pas normalisées, et un point posé à la main par la
/// personne qui connaît l'endroit vaut mieux qu'un résultat approximatif
/// renvoyé par un géocodeur.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.initialPoint,
    required this.title,
    this.subtitle,
  });

  /// Point de départ de la carte — le centre de la ville saisie, ou la
  /// position déjà enregistrée s'il y en a une.
  final LatLng initialPoint;

  final String title;
  final String? subtitle;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _controller = MapController();
  late LatLng _point = widget.initialPoint;
  bool _ready = false;

  Future<void> _centerOnMe() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted || !_ready) return;
      final me = LatLng(position.latitude, position.longitude);
      _controller.move(me, 17);
      setState(() => _point = me);
    } catch (_) {
      // Pas de position disponible : la carte reste où elle est, l'utilisateur
      // la déplace à la main. Rien à annoncer, il n'a rien demandé d'autre.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          if (widget.subtitle != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                widget.subtitle!,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: widget.initialPoint,
                    initialZoom: 15,
                    onMapReady: () => _ready = true,
                    // La position retenue est celle du centre de l'écran, mise
                    // à jour en continu pendant que la carte glisse.
                    onPositionChanged: (position, _) =>
                        setState(() => _point = position.center),
                  ),
                  children: [
                    mtcTileLayer(),
                    const RichAttributionWidget(
                      attributions: [TextSourceAttribution('© OpenStreetMap')],
                    ),
                  ],
                ),
                // Décalé d'une demi-hauteur vers le haut pour que la pointe
                // du repère — et non son centre — tombe sur le point visé.
                const IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_on,
                      size: 44,
                      color: AppColors.brandError,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    onPressed: _centerOnMe,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_point.latitude.toStringAsFixed(5)}, '
                    '${_point.longitude.toStringAsFixed(5)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  MtcPrimaryButton(
                    label: 'Confirmer ce point',
                    onPressed: () => Navigator.of(context).pop(_point),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ouvre le sélecteur et rend le point choisi, ou `null` si l'utilisateur
/// revient en arrière.
Future<LatLng?> pickLocation(
  BuildContext context, {
  required LatLng initialPoint,
  required String title,
  String? subtitle,
}) {
  return Navigator.of(context).push<LatLng>(
    MaterialPageRoute(
      builder: (_) => LocationPickerScreen(
        initialPoint: initialPoint,
        title: title,
        subtitle: subtitle,
      ),
    ),
  );
}
