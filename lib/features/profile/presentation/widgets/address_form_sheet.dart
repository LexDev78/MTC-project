import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/mock_data/malian_locations.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/tracking/presentation/screens/location_picker_screen.dart';

import '../providers/profile_providers.dart';

/// Ouvre la feuille « Nouvelle adresse ».
Future<void> showAddressFormSheet(BuildContext context) => showShopSheet<void>(
  context,
  heightFactor: 0.8,
  child: const AddressFormSheet(),
);

/// Une adresse à enregistrer : son nom, sa ville, ses repères, et surtout
/// le point posé sur la carte.
///
/// Tant que le point n'est pas posé, l'adresse ne s'enregistre pas : sans
/// lui on retomberait sur le centre de la ville, c'est-à-dire au même
/// endroit que tout le monde, et le livreur n'aurait aucune chance de
/// trouver la porte.
class AddressFormSheet extends ConsumerStatefulWidget {
  const AddressFormSheet({super.key});

  @override
  ConsumerState<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<AddressFormSheet> {
  final _formulaire = GlobalKey<FormState>();
  final _libelle = TextEditingController();
  final _ville = TextEditingController(text: MalianCity.bamako.label);
  final _details = TextEditingController();
  LatLng? _point;
  bool _envoi = false;

  @override
  void dispose() {
    _libelle.dispose();
    _ville.dispose();
    _details.dispose();
    super.dispose();
  }

  /// Point de départ de la carte : le centre de la ville saisie. C'est un
  /// point de **départ** pour viser, jamais la valeur enregistrée.
  LatLng _centreDeLaVille() => MalianCity.values
      .firstWhere(
        (c) => c.label.toLowerCase() == _ville.text.trim().toLowerCase(),
        orElse: () => MalianCity.bamako,
      )
      .coordinates;

  Future<void> _placer() async {
    final choisi = await pickLocation(
      context,
      initialPoint: _point ?? _centreDeLaVille(),
      title: 'Situer l\'adresse',
      subtitle:
          'Déplacez la carte pour placer le repère sur votre porte. C\'est '
          'ce point que le livreur suivra.',
    );
    if (choisi != null && mounted) setState(() => _point = choisi);
  }

  Future<void> _enregistrer() async {
    if (!_formulaire.currentState!.validate()) return;
    final messager = ScaffoldMessenger.of(context);
    final point = _point;
    if (point == null) {
      messager.showSnackBar(
        const SnackBar(
          content: Text('Placez d\'abord le repère sur la carte.'),
        ),
      );
      return;
    }
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;

    setState(() => _envoi = true);
    try {
      await ref
          .read(addressRepositoryProvider)
          .addAddress(
            userId: userId,
            label: _libelle.text.trim(),
            city: _ville.text.trim(),
            details: _details.text.trim(),
            latitude: point.latitude,
            longitude: point.longitude,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messager.showSnackBar(
        SnackBar(content: Text('Adresse « ${_libelle.text.trim()} » ajoutée.')),
      );
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _envoi = false);
      messager.showSnackBar(
        SnackBar(
          content: Text(
            messagePourUtilisateur(
              erreur,
              repli: 'L\'adresse n\'a pas pu être enregistrée.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = _point != null;
    return Scaffold(
      body: Column(
        children: [
          const SheetHeader(title: 'Nouvelle adresse'),
          Expanded(
            child: Form(
              key: _formulaire,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  ShopSizes.screenMargin,
                  ShopSizes.padding / 2,
                  ShopSizes.screenMargin,
                  ShopSizes.padding,
                ),
                children: [
                  TextFormField(
                    controller: _libelle,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    validator: Validators.required,
                    decoration: const InputDecoration(
                      labelText: 'Nom (ex. Maison, Bureau)',
                      prefixIcon: ShopFieldIcon(ShopIcons.address),
                    ),
                  ),
                  const SizedBox(height: ShopSizes.padding),
                  TextFormField(
                    controller: _ville,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: Validators.required,
                    decoration: const InputDecoration(
                      labelText: 'Ville',
                      prefixIcon: ShopFieldIcon(ShopIcons.location),
                    ),
                  ),
                  const SizedBox(height: ShopSizes.padding),
                  TextFormField(
                    controller: _details,
                    textCapitalization: TextCapitalization.sentences,
                    validator: Validators.required,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Détails (quartier, rue, porte)',
                      prefixIcon: ShopFieldIcon(ShopIcons.info),
                    ),
                  ),
                  const SizedBox(height: ShopSizes.padding * 1.5),
                  OutlinedButton.icon(
                    onPressed: _envoi ? null : _placer,
                    icon: ShopIcon(
                      place ? ShopIcons.singlecheck : ShopIcons.mylocation,
                      size: 20,
                      color: place ? ShopColors.success : null,
                    ),
                    label: Text(
                      place
                          ? 'Point enregistré — modifier'
                          : 'Placer sur la carte',
                    ),
                  ),
                  const SizedBox(height: ShopSizes.padding / 2),
                  Text(
                    'C\'est ce point, et non le centre de la ville, que le '
                    'livreur suivra jusqu\'à votre porte.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        label: 'Enregistrer',
        isLoading: _envoi,
        onPressed: _envoi ? null : _enregistrer,
      ),
    );
  }
}
