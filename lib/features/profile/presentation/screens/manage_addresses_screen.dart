import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/mock_data/malian_locations.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../providers/profile_providers.dart';

class ManageAddressesScreen extends ConsumerWidget {
  const ManageAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes adresses')),
      body: AsyncValueWidget(
        value: addressesAsync,
        data: (addresses) {
          if (addresses.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.location_on_outlined,
              title: 'Aucune adresse enregistrée',
              subtitle: 'Ajoutez une adresse pour passer vos commandes.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: addresses.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final address = addresses[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(address.label),
                  subtitle: Text('${address.details}, ${address.city}'),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () {
                      final userId = ref
                          .read(currentUserProvider)
                          .valueOrNull
                          ?.id;
                      if (userId == null) return;
                      ref
                          .read(addressRepositoryProvider)
                          .removeAddress(userId: userId, addressId: address.id);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
    );
  }

  void _showAddAddressSheet(BuildContext context, WidgetRef ref) {
    final labelController = TextEditingController();
    final detailsController = TextEditingController();
    final cityController = TextEditingController(text: MalianCity.bamako.label);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nouvelle adresse',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                MtcTextField(
                  label: 'Libellé (ex. Domicile, Bureau)',
                  controller: labelController,
                  validator: Validators.required,
                ),
                const SizedBox(height: AppSpacing.md),
                MtcTextField(
                  label: 'Ville',
                  controller: cityController,
                  validator: Validators.required,
                ),
                const SizedBox(height: AppSpacing.md),
                MtcTextField(
                  label: 'Détails (quartier, rue, porte)',
                  controller: detailsController,
                  validator: Validators.required,
                ),
                const SizedBox(height: AppSpacing.lg),
                MtcPrimaryButton(
                  label: 'Enregistrer',
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final userId = ref
                        .read(currentUserProvider)
                        .valueOrNull
                        ?.id;
                    if (userId == null) return;
                    final coordinates = MalianCity.values
                        .firstWhere(
                          (c) =>
                              c.label.toLowerCase() ==
                              cityController.text.trim().toLowerCase(),
                          orElse: () => MalianCity.bamako,
                        )
                        .coordinates;
                    ref
                        .read(addressRepositoryProvider)
                        .addAddress(
                          userId: userId,
                          label: labelController.text.trim(),
                          city: cityController.text.trim(),
                          details: detailsController.text.trim(),
                          latitude: coordinates.latitude,
                          longitude: coordinates.longitude,
                        );
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
