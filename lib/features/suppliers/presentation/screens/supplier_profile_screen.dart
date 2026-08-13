import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_grid.dart';
import 'package:mtc_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/favorite_toggle_button.dart';
import 'package:mtc_app/features/ratings/presentation/providers/review_providers.dart';

import '../../domain/entities/supplier_profile.dart';
import '../providers/supplier_providers.dart';

class SupplierProfileScreen extends ConsumerWidget {
  const SupplierProfileScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(supplierDetailProvider(supplierId));

    return Scaffold(
      appBar: AppBar(title: const Text('Fournisseur')),
      body: AsyncValueWidget(
        value: supplierAsync,
        data: (supplier) => _SupplierProfileBody(supplier: supplier),
      ),
    );
  }
}

class _SupplierProfileBody extends ConsumerWidget {
  const _SupplierProfileBody({required this.supplier});

  final SupplierProfile supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(supplierProductsProvider(supplier.id));
    final scheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        if (supplier.bannerUrl != null)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: ResolvedImage(
                path: supplier.bannerUrl!,
                bucket: 'supplier-branding',
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: scheme.surfaceContainerHigh),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        Icons.storefront_rounded,
                        size: 28,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier.businessName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            supplier.city,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    MtcRatingStars(
                      rating: supplier.ratingAverage,
                      ratingCount: supplier.ratingCount,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (supplier.verificationStatus ==
                        VerificationStatus.verified)
                      RoleBadge(
                        label: 'Identité vérifiée',
                        color: scheme.primary,
                        icon: Icons.verified_rounded,
                      ),
                    if (supplier.supplierType == SupplierType.principal)
                      RoleBadge(
                        label: 'MTC officiel',
                        color: scheme.tertiary,
                        icon: Icons.stars_rounded,
                      ),
                    RoleBadge(
                      label: supplier.isOpen ? 'Ouvert' : 'Fermé',
                      color: supplier.isOpen ? scheme.primary : scheme.error,
                      icon: supplier.isOpen
                          ? Icons.check_circle_outline_rounded
                          : Icons.schedule_rounded,
                    ),
                  ],
                ),
                if (supplier.description != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(supplier.description!),
                ],
                if (supplier.fullAddress != null ||
                    supplier.openingHoursLabel != null ||
                    supplier.publicPhoneNumbers.isNotEmpty ||
                    supplier.deliveryZones.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _StorefrontInfo(supplier: supplier),
                ],
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () async {
                    final conversationId = await ref
                        .read(chatControllerProvider.notifier)
                        .startConversationWithSupplier(
                          supplierId: supplier.id,
                          supplierName: supplier.businessName,
                        );
                    if (context.mounted && conversationId != null) {
                      unawaited(
                        context.push(AppRoutes.chatThread(conversationId)),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Contacter le fournisseur'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Produits (${supplier.productCount})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AsyncValueWidget(
            value: productsAsync,
            data: (products) => ProductGrid(
              products: products,
              shrinkWrap: true,
              cardOverlayBuilder: (product) => FavoriteToggleButton(
                productId: product.id,
                size: 20,
                inactiveColor: Colors.white,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: _SupplierReviews(supplierId: supplier.id),
          ),
        ),
      ],
    );
  }
}

/// Address/hours/phones/delivery-zones block — only rendered when at least
/// one of those is set (see the caller's guard), so an unfinished
/// storefront profile doesn't show a wall of empty rows.
class _StorefrontInfo extends StatelessWidget {
  const _StorefrontInfo({required this.supplier});

  final SupplierProfile supplier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    Widget row(IconData icon, String text) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(text, style: textStyle)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (supplier.fullAddress != null)
          row(Icons.location_on_outlined, supplier.fullAddress!),
        if (supplier.openingHoursLabel != null)
          row(Icons.schedule_rounded, supplier.openingHoursLabel!),
        if (supplier.publicPhoneNumbers.isNotEmpty)
          row(Icons.phone_outlined, supplier.publicPhoneNumbers.join(', ')),
        if (supplier.deliveryZones.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final zone in supplier.deliveryZones)
                RoleBadge(
                  label: zone,
                  color: scheme.secondary,
                  icon: Icons.local_shipping_outlined,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SupplierReviews extends ConsumerWidget {
  const _SupplierReviews({required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(supplierReviewsProvider(supplierId));
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Avis clients', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AsyncValueWidget(
          value: reviewsAsync,
          data: (reviews) {
            if (reviews.isEmpty) {
              return Text(
                'Aucun avis pour le moment.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              );
            }
            return Column(
              children: [
                for (final review in reviews.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MtcRatingStars(
                              rating: review.stars.toDouble(),
                              showValue: false,
                            ),
                            const SizedBox(height: 4),
                            Text(review.comment),
                            if (review.supplierReply != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Réponse du fournisseur',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(review.supplierReply!),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
