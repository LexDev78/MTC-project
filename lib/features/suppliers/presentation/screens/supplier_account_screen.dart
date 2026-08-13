import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/storage/image_upload.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';
import 'package:mtc_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/entities/supplier_profile.dart';
import '../controllers/supplier_account_controller.dart';
import '../providers/supplier_providers.dart';

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
