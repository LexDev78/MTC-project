import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';

import '../../domain/entities/user_role.dart';

/// First step of sign-up: MTC staff accounts (`UserRole.supplierPrincipal`)
/// are provisioned internally, so only Client and Fournisseur tiers are
/// offered here.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Je suis...', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            _RoleCard(
              icon: Icons.shopping_bag_outlined,
              title: 'Client',
              subtitle:
                  'Je veux acheter des produits et suivre mes livraisons.',
              onTap: () => context.push(
                AppRoutes.signUpDetails,
                extra: (role: UserRole.client, legalType: null),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _RoleCard(
              icon: Icons.storefront_outlined,
              title: 'Fournisseur tiers',
              subtitle: 'Je veux vendre mes produits sur la plateforme.',
              onTap: () => context.push(AppRoutes.signUpSupplierLegalType),
            ),
            const SizedBox(height: AppSpacing.md),
            _RoleCard(
              icon: Icons.delivery_dining_outlined,
              title: 'Livreur',
              subtitle:
                  'Je veux livrer les commandes. Mon inscription sera '
                  'validée par MTC avant ma première course.',
              onTap: () => context.push(
                AppRoutes.signUpDetails,
                extra: (role: UserRole.livreur, legalType: null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
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
