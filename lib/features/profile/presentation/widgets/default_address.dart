import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/address.dart';
import '../providers/profile_providers.dart';
import 'address_form_sheet.dart';

/// Fait de [adresse] l'adresse par défaut, relit le compte pour que chaque
/// écran le voie (ruban « Par défaut », adresse du paiement), et le dit.
/// Rend `true` si c'est fait.
Future<bool> makeDefaultAddress(
  BuildContext context,
  WidgetRef ref,
  Address adresse,
) async {
  final messager = ScaffoldMessenger.of(context);
  try {
    await ref.read(addressRepositoryProvider).setDefaultAddress(adresse.id);
    await ref.read(authRepositoryProvider).reloadCurrentUser();
    messager.showSnackBar(
      SnackBar(
        content: Text('« ${adresse.label} » est votre adresse par défaut.'),
      ),
    );
    return true;
  } catch (erreur) {
    messager.showSnackBar(
      SnackBar(
        content: Text(
          messagePourUtilisateur(
            erreur,
            repli: 'L\'adresse par défaut n\'a pas pu être changée.',
          ),
        ),
      ),
    );
    return false;
  }
}

/// Choisir l'adresse de livraison au paiement : la toucher en fait
/// l'adresse par défaut, que le paiement propose.
Future<void> showAddressPickerSheet(BuildContext context) =>
    showShopSheet<void>(
      context,
      heightFactor: 0.75,
      child: const AddressPickerSheet(),
    );

class AddressPickerSheet extends ConsumerWidget {
  const AddressPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adresses = ref.watch(addressesProvider).valueOrNull ?? const [];
    final choisie = ref.watch(defaultAddressProvider);

    return Scaffold(
      body: Column(
        children: [
          const SheetHeader(title: 'Adresse de livraison'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                ShopSizes.screenMargin,
                0,
                ShopSizes.screenMargin,
                ShopSizes.screenMargin,
              ),
              children: [
                Text(
                  'L\'adresse choisie devient votre adresse par défaut : vos '
                  'prochaines commandes la proposeront.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: ShopSizes.padding),
                for (final adresse in adresses) ...[
                  AddressCard(
                    label: adresse.label,
                    lines: [adresse.details, adresse.city],
                    selected: adresse.id == choisie?.id,
                    showCheck: adresse.id == choisie?.id,
                    onTap: () async {
                      final navigateur = Navigator.of(context);
                      if (adresse.id == choisie?.id ||
                          await makeDefaultAddress(context, ref, adresse)) {
                        navigateur.pop();
                      }
                    },
                  ),
                  const SizedBox(height: ShopSizes.padding),
                ],
                DashedButton(
                  icon: ShopIcons.address,
                  label: 'Ajouter une adresse',
                  onTap: () => showAddressFormSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
