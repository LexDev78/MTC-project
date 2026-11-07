import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';

import '../../domain/entities/user_role.dart';

/// Second step of the "Fournisseur tiers" sign-up path, between
/// `RoleSelectionScreen` and `SignUpDetailsScreen`. The choice made here
/// drives which identity documents `supplier_onboarding` will later ask
/// for — a company registration (RCCM, statuts, NIF...) or a personal ID +
/// selfie + APDP data-processing consent for an individual seller.
class SupplierLegalTypeScreen extends StatelessWidget {
  const SupplierLegalTypeScreen({super.key});

  void _selectAndContinue(BuildContext context, SupplierLegalType legalType) {
    context.push(
      AppRoutes.signUpDetails,
      extra: (role: UserRole.supplierTiers, legalType: legalType),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Type de fournisseur')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Comment souhaitez-vous vous inscrire ?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Le type choisi détermine les documents à fournir pour la vérification de votre compte.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: AppSpacing.lg),
            _LegalTypeCard(
              icon: Icons.apartment_outlined,
              title: 'Société / Entreprise',
              subtitle:
                  'Registre du Commerce (RCCM), NIF et pièce d\'identité du gérant.',
              onTap: () =>
                  _selectAndContinue(context, SupplierLegalType.company),
            ),
            const SizedBox(height: AppSpacing.md),
            _LegalTypeCard(
              icon: Icons.badge_outlined,
              title: 'Vendeur individuel',
              subtitle:
                  "Pièce d'identité (carte NINA), selfie et consentement de traitement des données personnelles.",
              onTap: () =>
                  _selectAndContinue(context, SupplierLegalType.individual),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalTypeCard extends StatelessWidget {
  const _LegalTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
