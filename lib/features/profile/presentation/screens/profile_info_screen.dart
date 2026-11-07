import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Les informations du compte (maquette « Profile » du kit) : l'avatar et
/// le nom en tête, puis une ligne par information, et le mot de passe à
/// changer.
///
/// « Modifier », comme le « Edit » de la maquette, ouvre la photo, le nom,
/// l'e-mail, le téléphone et la date de naissance à la modification.
/// L'identifiant de connexion, lui, ne change pas.
class ProfileInfoScreen extends ConsumerWidget {
  const ProfileInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final email = ref.watch(contactEmailProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes informations'),
        actions: [
          TextButton(
            onPressed: user == null
                ? null
                : () => context.push(AppRoutes.clientProfileInfoEdit),
            child: const Text('Modifier'),
          ),
          const SizedBox(width: ShopSizes.padding / 2),
        ],
      ),
      body: user == null
          ? const Center(
              child: CircularProgressIndicator(color: ShopColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                ShopSizes.screenMargin,
                ShopSizes.padding,
                ShopSizes.screenMargin,
                ShopSizes.screenMargin,
              ),
              children: [
                ProfileCard(
                  name: user.displayName,
                  subtitle: email ?? user.phoneNumber,
                  avatarPath: switch (user) {
                    ClientUser(:final avatarPath) => avatarPath,
                    _ => null,
                  },
                  greet: false,
                  showChevron: false,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: ShopSizes.padding),
                InfoRow(label: 'Nom', value: user.displayName),
                InfoRow(label: 'Téléphone', value: user.phoneNumber),
                // L'identifiant de connexion, quand ce n'est pas déjà le
                // numéro affiché juste au-dessus.
                if (user.usernameOrPhone != user.phoneNumber)
                  InfoRow(label: 'Identifiant', value: user.usernameOrPhone),
                InfoRow(
                  label: 'E-mail',
                  value: email ?? 'Ajouter',
                  valueColor: email == null ? ShopColors.primary : null,
                  onTap: () => context.push(AppRoutes.accountEmail),
                ),
                if (user case ClientUser(:final birthDate))
                  InfoRow(
                    label: 'Date de naissance',
                    value: birthDate == null
                        ? 'Ajouter'
                        : DateFormatter.formatDayMonthYear(birthDate),
                    valueColor: birthDate == null ? ShopColors.primary : null,
                    onTap: birthDate == null
                        ? () => context.push(AppRoutes.clientProfileInfoEdit)
                        : null,
                  ),
                InfoRow(
                  label: 'Client depuis',
                  value: DateFormatter.formatDayMonthYear(user.createdAt),
                ),
                InfoRow(
                  label: 'Mot de passe',
                  value: 'Changer le mot de passe',
                  valueColor: ShopColors.primary,
                  showDivider: false,
                  onTap: () => context.push(AppRoutes.accountPassword),
                ),
              ],
            ),
    );
  }
}
