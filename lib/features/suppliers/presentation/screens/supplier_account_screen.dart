import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:latlong2/latlong.dart';

import 'package:mtc_app/core/mock_data/malian_locations.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/features/tracking/presentation/screens/location_picker_screen.dart';
import 'package:mtc_app/features/tracking/presentation/widgets/position_to_confirm_banner.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/storage/image_upload.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/entities/supplier_profile.dart';
import '../controllers/supplier_account_controller.dart';
import '../providers/supplier_providers.dart';

/// Mirrors `order_detail_screen.dart`'s "Annuler cette commande ?" dialog —
/// the only other irreversible-action confirmation in the app. Mentions the
/// two blocking conditions from `deactivate_account()`
/// (`0036_account_deactivation.sql`) up front so a failure isn't a surprise.
Future<void> _confirmAndDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer votre compte ?'),
      content: const Text(
        'Votre boutique et vos produits seront désactivés et vous serez '
        'déconnecté. Impossible si vous avez des commandes ou un retrait en '
        'cours. Cette action est définitive.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Retour'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer mon compte'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final success = await ref.read(authControllerProvider.notifier).deleteAccount();
  if (!success && context.mounted) {
    final error = ref.read(authControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
    );
  }
}

/// "Profil" tab of `SupplierShell` — the editable storefront profile
/// (description, adresse, horaires, zone de livraison, statut
/// ouvert/fermé), shared by both supplier roles via
/// `operatingSupplierIdProvider`. What `SupplierProfileScreen` (public
/// vitrine) shows a client is exactly what gets edited here.
class SupplierAccountScreen extends ConsumerWidget {
  const SupplierAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final supplierId = ref.watch(operatingSupplierIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined),
            tooltip: 'Codes promo',
            onPressed: () => context.push(
              '${ref.read(supplierRoutePrefixProvider)}/account/promo-codes',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.star_outline_rounded),
            tooltip: 'Avis clients',
            onPressed: () => context.push(
              '${ref.read(supplierRoutePrefixProvider)}/account/reviews',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user != null) ...[
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  user.usernameOrPhone,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (supplierId == null)
                const MtcLoadingView()
              else
                AsyncValueWidget(
                  value: ref.watch(supplierDetailProvider(supplierId)),
                  data: (supplier) => _StorefrontForm(supplier: supplier),
                ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Déconnexion'),
              ),
              // Staff (`SupplierPrincipalUser`) share this exact screen with
              // no role branching anywhere else in it — deliberately
              // excluded here, since a staff account is provisioned
              // internally and never self-service (`deactivate_account()`
              // rejects it server-side too, this just keeps the button
              // from ever being shown to begin with).
              if (user is SupplierTiersUser) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _confirmAndDeleteAccount(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(color: Theme.of(context).colorScheme.error),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Supprimer mon compte'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StorefrontForm extends ConsumerStatefulWidget {
  const _StorefrontForm({required this.supplier});

  final SupplierProfile supplier;

  @override
  ConsumerState<_StorefrontForm> createState() => _StorefrontFormState();
}

class _StorefrontFormState extends ConsumerState<_StorefrontForm> {
  late final _descriptionController = TextEditingController(
    text: widget.supplier.description,
  );
  late final _addressController = TextEditingController(
    text: widget.supplier.fullAddress,
  );
  late final _phonesController = TextEditingController(
    text: widget.supplier.publicPhoneNumbers.join(', '),
  );
  late final _zonesController = TextEditingController(
    text: widget.supplier.deliveryZones.join(', '),
  );
  late final _hoursController = TextEditingController(
    text: widget.supplier.openingHoursLabel,
  );
  late String? _bannerPath = widget.supplier.bannerUrl;

  /// Point de retrait posé sur la carte pendant cette session d'édition.
  /// `null` tant qu'on n'y a pas touché : celui déjà enregistré est conservé.
  LatLng? _pickupPoint;
  late bool _isOpen = widget.supplier.isOpen;

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    _phonesController.dispose();
    _zonesController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  List<String> _splitCsv(String text) {
    return text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _pickBanner() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      final supplierId = ref.read(operatingSupplierIdProvider);
      final path = await uploadPickedImage(
        client: ref.read(supabaseClientProvider),
        bucket: 'supplier-branding',
        folder: supplierId!,
        file: file,
      );
      if (mounted) setState(() => _bannerPath = path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Impossible d'ajouter cette bannière. Vérifiez votre connexion et "
            "l'autorisation d'accès à la galerie dans les réglages du téléphone.",
          ),
        ),
      );
    }
  }

  Future<void> _toggleOpen(bool value) async {
    setState(() => _isOpen = value);
    final ok = await ref
        .read(supplierAccountControllerProvider.notifier)
        .setOpen(value);
    if (!ok && mounted) setState(() => _isOpen = !value);
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(supplierAccountControllerProvider.notifier)
        .updateStorefront(
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          bannerUrl: _bannerPath,
          fullAddress: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          pickupPoint: _pickupPoint,
          publicPhoneNumbers: _splitCsv(_phonesController.text),
          deliveryZones: _splitCsv(_zonesController.text),
          openingHoursLabel: _hoursController.text.trim().isEmpty
              ? null
              : _hoursController.text.trim(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Profil de la boutique mis à jour.' : 'Une erreur est survenue',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierAccountControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Vitrine de la boutique', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _BannerPicker(path: _bannerPath, onPick: _pickBanner),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Boutique ouverte'),
          subtitle: Text(
            _isOpen
                ? 'Visible comme "ouverte" pour vos clients'
                : 'Affichée comme "fermée" pour vos clients',
          ),
          value: _isOpen,
          onChanged: _toggleOpen,
        ),
        const SizedBox(height: AppSpacing.md),
        MtcTextField(
          label: 'Description (optionnel)',
          controller: _descriptionController,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        MtcTextField(
          label: 'Adresse complète (optionnel)',
          controller: _addressController,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Le texte de l'adresse sert à l'humain, le repère sert au livreur.
        // Les deux sont nécessaires : « Quartier du Fleuve » ne mène nulle
        // part sur une carte, et des coordonnées seules ne se lisent pas.
        _PickupPointField(
          supplier: widget.supplier,
          chosen: _pickupPoint,
          onPicked: (point) => setState(() => _pickupPoint = point),
        ),
        const SizedBox(height: AppSpacing.md),
        MtcTextField(
          label: 'Téléphones publics (séparés par des virgules, optionnel)',
          controller: _phonesController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        MtcTextField(
          label: 'Zones de livraison (séparées par des virgules, optionnel)',
          controller: _zonesController,
        ),
        const SizedBox(height: AppSpacing.md),
        MtcTextField(
          label: 'Horaires (ex. Lun-Sam 8h-18h, optionnel)',
          controller: _hoursController,
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

class _BannerPicker extends StatelessWidget {
  const _BannerPicker({required this.path, required this.onPick});

  final String? path;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        height: 120,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: path == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: scheme.primary),
                    const SizedBox(height: 4),
                    Text(
                      'Ajouter une bannière',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ResolvedImage(path: path!, bucket: 'supplier-branding'),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.white),
                        onPressed: onPick,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Bouton de choix du point de retrait, avec son état.
///
/// Un fournisseur qui livre par MTC **doit** en avoir un : sans lui, la
/// remise à la livraison est refusée côté serveur
/// (`0050_mtc_delivery_requires_pickup_point.sql`). Le dire ici évite de
/// découvrir le blocage au pire moment, une commande déjà payée en attente.
class _PickupPointField extends StatelessWidget {
  const _PickupPointField({
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
    final existing = supplier.addressLatitude != null &&
            supplier.addressLongitude != null
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
