import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/search_text.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/tracking/presentation/screens/location_picker_screen.dart';

import '../../domain/entities/address.dart';
import '../providers/profile_providers.dart';
import '../widgets/address_form_sheet.dart';
import '../widgets/default_address.dart';

/// Les adresses du client, d'après la maquette « Address » du kit : une
/// recherche, « Ajouter une adresse » en pointillés, puis une carte par
/// adresse. Toucher une carte ouvre ce qu'on peut en faire.
class ManageAddressesScreen extends ConsumerStatefulWidget {
  const ManageAddressesScreen({super.key});

  @override
  ConsumerState<ManageAddressesScreen> createState() =>
      _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends ConsumerState<ManageAddressesScreen> {
  final _champ = TextEditingController();

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adresses = ref.watch(addressesProvider);
    final parDefaut = switch (ref.watch(currentUserProvider).valueOrNull) {
      ClientUser(:final defaultAddressId) => defaultAddressId,
      _ => null,
    };
    final texte = _champ.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Mes adresses')),
      body: adresses.when(
        skipLoadingOnReload: true,
        loading: () => ListView(
          padding: const EdgeInsets.all(ShopSizes.screenMargin),
          children: const [
            Skeleton(height: 56),
            SizedBox(height: ShopSizes.padding * 1.5),
            Skeleton(height: 56),
            SizedBox(height: ShopSizes.padding * 1.5),
            Skeleton(height: 130),
          ],
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'Vos adresses n\'ont pas pu être chargées',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(addressesProvider),
            child: const Text('Réessayer'),
          ),
        ),
        data: (liste) {
          final visibles = [
            for (final a in liste)
              if (matchesAnySearch([a.label, a.city, a.details], texte)) a,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              ShopSizes.screenMargin,
              ShopSizes.padding,
              ShopSizes.screenMargin,
              ShopSizes.screenMargin,
            ),
            children: [
              ShopSearchField(
                hintText: 'Trouver une adresse…',
                controller: _champ,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: ShopSizes.padding * 1.5),
              DashedButton(
                icon: ShopIcons.address,
                label: 'Ajouter une adresse',
                onTap: () => showAddressFormSheet(context),
              ),
              const SizedBox(height: ShopSizes.padding * 1.5),
              if (liste.isEmpty)
                const IllustratedMessage(
                  compact: true,
                  illustration: ShopIllustration.emptyState,
                  title: 'Aucune adresse enregistrée',
                  message:
                      'Ajoutez l\'adresse où vous faire livrer : le livreur '
                      'suivra le point que vous placerez sur la carte.',
                )
              else if (visibles.isEmpty)
                IllustratedMessage(
                  compact: true,
                  illustration: ShopIllustration.noResult,
                  title: 'Aucune adresse trouvée',
                  message:
                      'Rien ne répond à « $texte ». Cherchez un nom, une '
                      'ville ou un quartier.',
                )
              else
                for (final adresse in visibles) ...[
                  _Carte(adresse: adresse, parDefaut: adresse.id == parDefaut),
                  const SizedBox(height: ShopSizes.padding),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// Une adresse en carte du kit, avec l'avertissement d'un point jamais
/// placé.
class _Carte extends ConsumerWidget {
  const _Carte({required this.adresse, required this.parDefaut});

  final Address adresse;
  final bool parDefaut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Une adresse dont le point n'a jamais été posé porte les coordonnées
    // du centre de sa ville : le livreur s'y rend littéralement. On le dit
    // sur la carte, avec de quoi corriger (`0079`).
    final aVerifier = adresse.positionConfirmedAt == null;
    return AddressCard(
      label: adresse.label,
      lines: [adresse.details, adresse.city],
      isDefault: parDefaut,
      onTap: () => _actions(context, ref),
      footer: aVerifier
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShopIcon(
                  ShopIcons.dangerCircle,
                  size: 18,
                  color: ShopColors.warning,
                ),
                const SizedBox(width: ShopSizes.padding / 2),
                Expanded(
                  child: Text(
                    'Point jamais placé : les livreurs iront au centre de '
                    '${adresse.city}. Touchez pour le placer.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  /// Ce qu'on peut faire d'une adresse, dans une feuille du kit.
  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final choix = await showShopSheet<_Action>(
      context,
      heightFactor: parDefaut ? 0.35 : 0.45,
      child: Scaffold(
        body: Column(
          children: [
            SheetHeader(title: adresse.label),
            Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ShopSizes.padding,
                ),
                child: Column(
                  children: [
                    if (!parDefaut)
                      ChevronListTile(
                        icon: ShopIcons.singlecheck,
                        title: 'Utiliser par défaut',
                        onTap: () =>
                            Navigator.of(context).pop(_Action.parDefaut),
                      ),
                    ChevronListTile(
                      icon: ShopIcons.mylocation,
                      title: adresse.positionConfirmedAt == null
                          ? 'Placer sur la carte'
                          : 'Replacer sur la carte',
                      onTap: () => Navigator.of(context).pop(_Action.replacer),
                    ),
                    ChevronListTile(
                      icon: ShopIcons.delete,
                      title: 'Supprimer l\'adresse',
                      danger: true,
                      showDivider: false,
                      onTap: () => Navigator.of(context).pop(_Action.supprimer),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choix) {
      case _Action.parDefaut:
        await makeDefaultAddress(context, ref, adresse);
      case _Action.replacer:
        await _replacer(context, ref);
      case _Action.supprimer:
        await _supprimer(context, ref);
      case null:
        break;
    }
  }

  /// Repose le point d'une adresse existante.
  ///
  /// Le seul chemin de correction était de supprimer puis recréer l'adresse,
  /// ce que personne ne fait — les positions héritées restaient donc en
  /// place indéfiniment.
  Future<void> _replacer(BuildContext context, WidgetRef ref) async {
    final messager = ScaffoldMessenger.of(context);
    final choisi = await pickLocation(
      context,
      initialPoint: LatLng(adresse.latitude, adresse.longitude),
      title: adresse.label,
      subtitle:
          'Placez le repère sur votre porte. C\'est là que le livreur '
          'viendra.',
    );
    if (choisi == null) return;
    try {
      await ref
          .read(addressRepositoryProvider)
          .updatePosition(
            addressId: adresse.id,
            latitude: choisi.latitude,
            longitude: choisi.longitude,
          );
      messager.showSnackBar(
        SnackBar(content: Text('Le point de « ${adresse.label} » est placé.')),
      );
    } catch (erreur) {
      messager.showSnackBar(
        SnackBar(
          content: Text(
            messagePourUtilisateur(
              erreur,
              repli: 'Le point n\'a pas pu être enregistré.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final messager = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette adresse ?'),
        content: Text(
          '« ${adresse.label} » ne sera plus proposée au moment de commander. '
          'Les commandes déjà passées gardent leur adresse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ShopColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;
    try {
      await ref
          .read(addressRepositoryProvider)
          .removeAddress(userId: userId, addressId: adresse.id);
      messager.showSnackBar(
        SnackBar(content: Text('Adresse « ${adresse.label} » supprimée.')),
      );
    } catch (erreur) {
      messager.showSnackBar(
        SnackBar(
          content: Text(
            messagePourUtilisateur(
              erreur,
              repli: 'L\'adresse n\'a pas pu être supprimée.',
            ),
          ),
        ),
      );
    }
  }
}

enum _Action { parDefaut, replacer, supprimer }
