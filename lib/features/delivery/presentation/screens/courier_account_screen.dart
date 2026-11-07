import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../providers/delivery_providers.dart';

/// Le compte du livreur : son dossier, son adresse e-mail, son mot de passe.
///
/// Le livreur n'avait aucun écran de compte — la route `/livreur/profil`
/// était déclarée sans être branchée, et sa barre n'offrait que « Mon
/// activité » et « Déconnexion ». Changer son mot de passe lui était donc
/// impossible. Cet écran reprend le menu partagé des autres comptes
/// (`MtcMenuSection`), pour que les trois rôles se ressemblent.
class CourierAccountScreen extends ConsumerWidget {
  const CourierAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courier = ref.watch(currentCourierProvider);
    final adresseEmail = ref.watch(contactEmailProvider).valueOrNull;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (courier != null) ...[
            Text(
              courier.displayName,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              courier.phoneNumber,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          MtcMenuSection(
            title: 'Mon activité',
            children: [
              MtcMenuTile(
                icon: Icons.badge_outlined,
                title: 'Mon dossier',
                subtitle: 'Pièces d\'identité et moyen de transport',
                onTap: () => context.push(AppRoutes.courierDossier),
              ),
              MtcMenuTile(
                icon: Icons.history_rounded,
                title: 'Historique',
                subtitle: 'Courses terminées et notes reçues',
                onTap: () => context.push(AppRoutes.courierHistory),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          MtcMenuSection(
            title: 'Mon compte',
            children: [
              MtcMenuTile(
                icon: Icons.mail_outline_rounded,
                title: 'Adresse e-mail',
                subtitle: adresseEmail ?? 'Ajouter une adresse e-mail',
                onTap: () => context.push(AppRoutes.accountEmail),
              ),
              MtcMenuTile(
                icon: Icons.lock_outline_rounded,
                title: 'Mot de passe',
                subtitle: 'Changer votre mot de passe',
                onTap: () => context.push(AppRoutes.accountPassword),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
