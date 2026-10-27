import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/mock_data/malian_locations.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/features/tracking/presentation/screens/location_picker_screen.dart';
import 'package:mtc_app/features/tracking/presentation/widgets/position_to_confirm_banner.dart';

import '../../domain/entities/supplier_profile.dart';
import '../controllers/supplier_account_controller.dart';
import '../providers/supplier_providers.dart';

/// Où la boutique se trouve, et où elle livre.
///
/// Écran à part et non une section de plus sur « Profil » : la carte y prend
/// toute la place, et ces trois champs ne se touchent presque jamais — une
/// adresse ne change pas aussi souvent qu'une description ou des horaires.
/// Les laisser au milieu du formulaire de la vitrine allongeait un écran que
/// le fournisseur traverse chaque fois qu'il veut corriger une ligne.
class SupplierLocationScreen extends ConsumerWidget {
  const SupplierLocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierId = ref.watch(operatingSupplierIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Localisation')),
      body: SafeArea(
        child: supplierId == null
            ? const MtcLoadingView()
            : AsyncValueWidget(
                value: ref.watch(supplierDetailProvider(supplierId)),
                data: (supplier) => AsyncValueWidget(
                  // L'adresse exacte ne vient plus avec la fiche publique
                  // (`0133`) : elle se lit à part, et seulement ici.
                  value: ref.watch(myShopLocationProvider),
                  data: (adresse) => SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _LocationForm(
                      supplier: supplier.copyWith(
                        fullAddress: adresse?.fullAddress,
                        addressLatitude: adresse?.latitude,
                        addressLongitude: adresse?.longitude,
                        positionConfirmedAt: adresse?.positionConfirmedAt,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _LocationForm extends ConsumerStatefulWidget {
  const _LocationForm({required this.supplier});

  final SupplierProfile supplier;

  @override
  ConsumerState<_LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends ConsumerState<_LocationForm> {
  late final _addressController = TextEditingController(
    text: widget.supplier.fullAddress,
  );
  late final _zonesController = TextEditingController(
    text: widget.supplier.deliveryZones.join(', '),
  );

  /// Point de retrait posé sur la carte pendant cette session d'édition.
  /// `null` tant qu'on n'y a pas touché : celui déjà enregistré est conservé.
  LatLng? _pickupPoint;

  @override
  void dispose() {
    _addressController.dispose();
    _zonesController.dispose();
    super.dispose();
  }

  List<String> _splitCsv(String text) {
    return text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(supplierAccountControllerProvider.notifier)
        .updateLocation(
          fullAddress: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          pickupPoint: _pickupPoint,
          deliveryZones: _splitCsv(_zonesController.text),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Localisation mise à jour.' : 'Une erreur est survenue'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierAccountControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MtcTextField(
          label: 'Adresse complète (optionnel)',
          controller: _addressController,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Le texte de l'adresse sert à l'humain, le repère sert au livreur.
        // Les deux sont nécessaires : « Quartier du Fleuve » ne mène nulle
        // part sur une carte, et des coordonnées seules ne se lisent pas.
        PickupPointField(
          supplier: widget.supplier,
          chosen: _pickupPoint,
          onPicked: (point) => setState(() => _pickupPoint = point),
        ),
        const SizedBox(height: AppSpacing.lg),
        MtcTextField(
          label: 'Zones de livraison (séparées par des virgules, optionnel)',
          controller: _zonesController,
        ),
        const SizedBox(height: AppSpacing.lg),
        MtcPrimaryButton(
          label: 'Enregistrer',
          isLoading: state.isLoading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Bouton de choix du point de retrait, avec son état.
///
/// Un fournisseur qui livre par MTC **doit** en avoir un : sans lui, la
/// remise à la livraison est refusée côté serveur
/// (`0050_mtc_delivery_requires_pickup_point.sql`). Le dire ici évite de
/// découvrir le blocage au pire moment, une commande déjà payée en attente.
class PickupPointField extends StatelessWidget {
  const PickupPointField({
    super.key,
    required this.supplier,
    required this.chosen,
    required this.onPicked,
  });

  final SupplierProfile supplier;
  final LatLng? chosen;
  final ValueChanged<LatLng> onPicked;

  /// Ouvre le sélecteur de carte. Partagé par le bouton et par le bandeau :
  /// deux chemins vers le même geste, une seule définition de ce qu'il fait.
  Future<void> _pick(BuildContext context, LatLng? point) async {
    final picked = await pickLocation(
      context,
      initialPoint:
          point ??
          MalianCity.values
              .firstWhere(
                (c) => c.label.toLowerCase() == supplier.city.toLowerCase(),
                orElse: () => MalianCity.bamako,
              )
              .coordinates,
      title: 'Point de retrait',
      subtitle:
          'Placez le repère sur la porte de votre boutique. C\'est là que le '
          'livreur viendra chercher les commandes.',
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final existing =
        supplier.addressLatitude != null && supplier.addressLongitude != null
        ? LatLng(supplier.addressLatitude!, supplier.addressLongitude!)
        : null;
    final point = chosen ?? existing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Une fiche dont le point n'a jamais été pointé porte les
        // coordonnées du centre de sa ville : le livreur s'y rend
        // littéralement. Le bandeau disparaît dès que le repère bouge
        // (`0079`).
        if (supplier.positionConfirmedAt == null && chosen == null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PositionToConfirmBanner(
              message:
                  'Votre point de retrait n\'a jamais été placé sur la carte. '
                  'Tant qu\'il ne l\'est pas, les livreurs se présentent au '
                  'centre de ${supplier.city}.',
              actionLabel: 'Placer mon point de retrait',
              onFix: () => _pick(context, point),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _pick(context, point),
          icon: Icon(
            point == null
                ? Icons.add_location_alt_outlined
                : Icons.check_circle_outline_rounded,
          ),
          label: Text(
            point == null
                ? 'Placer le point de retrait'
                : 'Point de retrait placé — modifier',
          ),
        ),
        if (point == null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Obligatoire pour confier vos commandes à la livraison MTC.',
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
