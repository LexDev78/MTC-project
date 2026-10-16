import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/storage/image_upload.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/features/tracking/presentation/widgets/position_to_confirm_banner.dart';

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

/// Onglet « Profil » de `SupplierShell`, partagé par les deux rôles
/// fournisseur via `operatingSupplierIdProvider`.
///
/// Organisé en trois sections, parce que la liste à plat qu'il était
/// mélangeait trois choses de nature différente : ce que le client voit, les
/// réglages qu'on ouvre rarement, et deux actions irréversibles posées juste
/// sous un bouton « Enregistrer ».
///
///  * **Gestion de la boutique** — ce que la vitrine montre, et le seul
///    formulaire de cet écran.
///  * **Paramètres supplémentaires** — ce qui a son propre écran :
///    localisation, codes promo, avis.
///  * **Paramètres avancés** — déconnexion et suppression de compte, en bas
///    et séparées du reste.
class SupplierAccountScreen extends ConsumerWidget {
  const SupplierAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final supplierId = ref.watch(operatingSupplierIdProvider);
    final prefix = ref.watch(supplierRoutePrefixProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
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
                  data: (supplier) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Le point de retrait vit désormais sur son propre
                      // écran. L'avertissement, lui, doit rester ici :
                      // c'est précisément le fournisseur qui n'y va jamais
                      // qui ne l'a pas placé, et tant qu'il ne l'est pas les
                      // livreurs se présentent au centre de la ville.
                      if (supplier.positionConfirmedAt == null) ...[
                        PositionToConfirmBanner(
                          message:
                              'Votre point de retrait n\'a jamais été placé '
                              'sur la carte. Tant qu\'il ne l\'est pas, les '
                              'livreurs se présentent au centre de '
                              '${supplier.city}.',
                          actionLabel: 'Placer mon point de retrait',
                          onFix: () => context.push('$prefix/account/location'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      const _SectionTitle('Gestion de la boutique'),
                      const SizedBox(height: AppSpacing.sm),
                      _StorefrontForm(supplier: supplier),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Paramètres supplémentaires'),
              // Chaque entrée demande la permission de ce qu'elle ouvre.
              // Montrer un chemin qu'on sait fermé n'est pas de la prudence,
              // c'est une invitation à se heurter à un refus.
              if (ref.watch(supplierCanProvider('storefront')))
                _NavigationTile(
                  icon: Icons.place_outlined,
                  label: 'Localisation',
                  subtitle: 'Adresse, point de retrait, zones de livraison',
                  onTap: () => context.push('$prefix/account/location'),
                ),
              if (ref.watch(supplierCanProvider('promotions'))) ...[
                _NavigationTile(
                  icon: Icons.sell_outlined,
                  label: 'Remises',
                  subtitle: 'Une remise, posée sur plusieurs produits à la fois',
                  onTap: () => context.push('$prefix/account/promotions'),
                ),
                _NavigationTile(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Codes promo',
                  subtitle: 'Créer des codes et voir où ils ont servi',
                  onTap: () => context.push('$prefix/account/promo-codes'),
                ),
              ],
              // Réservée au propriétaire : un collaborateur fraîchement
              // ajouté n'a pas à en ajouter d'autres, ni à évincer celui
              // qui l'a fait entrer. La base le refuse de toute façon ;
              // masquer l'entrée évite d'y mener pour rien.
              if (ref.watch(isSupplierOwnerProvider))
                _NavigationTile(
                  icon: Icons.group_outlined,
                  label: 'Collaborateurs',
                  subtitle: 'Ajouter quelqu\'un, choisir ce qu\'il peut faire',
                  onTap: () => context.push('$prefix/account/collaborators'),
                ),
              if (ref.watch(supplierCanProvider('reviews')))
                _NavigationTile(
                  icon: Icons.star_outline_rounded,
                  label: 'Avis clients',
                  subtitle: 'Lire et répondre aux avis sur votre boutique',
                  onTap: () => context.push('$prefix/account/reviews'),
                ),

              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Paramètres avancés'),
              _NavigationTile(
                icon: Icons.logout_rounded,
                label: 'Déconnexion',
                navigates: false,
                onTap: () => ref.read(authControllerProvider.notifier).logout(),
              ),
              // Le staff (`SupplierPrincipalUser`) partage cet écran sans
              // aucun autre embranchement de rôle : un compte interne n'est
              // jamais en libre-service, et `deactivate_account()` le refuse
              // déjà côté serveur. On évite simplement d'en montrer le
              // bouton.
              if (user is SupplierTiersUser &&
                  ref.watch(isSupplierOwnerProvider))
                _NavigationTile(
                  icon: Icons.delete_forever_outlined,
                  label: 'Supprimer mon compte',
                  danger: true,
                  navigates: false,
                  onTap: () => _confirmAndDeleteAccount(context, ref),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// Une ligne qui mène ailleurs, ou qui déclenche une action.
///
/// `contentPadding` nul pour que le libellé s'aligne sur les titres de
/// section et sur les champs du formulaire : un `ListTile` apporte sinon sa
/// propre marge, et la colonne part en escalier.
class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
    this.navigates = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  /// Une action irréversible : colorée comme telle, parce qu'elle voisine
  /// des lignes anodines.
  final bool danger;

  /// Faux pour une ligne qui **agit** au lieu de mener ailleurs. Le chevron
  /// est une promesse : « il y a un écran derrière ». Le poser sur une
  /// déconnexion ou une suppression de compte laisse croire qu'on va voir
  /// quelque chose avant que ça n'arrive.
  final bool navigates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: navigates ? const Icon(Icons.chevron_right_rounded) : null,
      onTap: onTap,
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
  late final _nameController = TextEditingController(
    text: widget.supplier.businessName,
  );
  late final _descriptionController = TextEditingController(
    text: widget.supplier.description,
  );
  late final _phonesController = TextEditingController(
    text: widget.supplier.publicPhoneNumbers.join(', '),
  );
  late final _hoursController = TextEditingController(
    text: widget.supplier.openingHoursLabel,
  );
  late String? _bannerPath = widget.supplier.bannerUrl;
  late bool _isOpen = widget.supplier.isOpen;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phonesController.dispose();
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
    // Le nom est le seul champ obligatoire de cet écran : une boutique sans
    // nom disparaît du catalogue, et un champ vidé par mégarde est trop
    // facile à produire pour qu'on l'enregistre en silence.
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom de la boutique est obligatoire.')),
      );
      return;
    }

    final ok = await ref
        .read(supplierAccountControllerProvider.notifier)
        .updateStorefront(
          businessName: name,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          bannerUrl: _bannerPath,
          publicPhoneNumbers: _splitCsv(_phonesController.text),
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
        Text(
          'Vitrine',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _BannerPicker(path: _bannerPath, onPick: _pickBanner),
        const SizedBox(height: AppSpacing.md),
        MtcTextField(
          label: 'Nom de la boutique',
          controller: _nameController,
        ),
        const SizedBox(height: AppSpacing.md),
        MtcTextField(
          label: 'Description (optionnel)',
          controller: _descriptionController,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.sm),
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
        const SizedBox(height: AppSpacing.sm),
        MtcTextField(
          label: 'Téléphones publics (séparés par des virgules, optionnel)',
          controller: _phonesController,
          keyboardType: TextInputType.phone,
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
