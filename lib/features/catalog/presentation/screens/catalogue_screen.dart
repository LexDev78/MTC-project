import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';

import '../../domain/entities/product_category.dart';
import '../widgets/product_card.dart' show ProductCategoryIcon, ProductCategoryImage;

/// Bottom-nav "Catalogue" tab — browse-by-nature entry point, distinct from
/// "Accueil" (the varied/promoted product feed): every [ProductCategory] is
/// shown as a tappable photo tile rather than a dropdown, landing on
/// `CategoryProductsScreen` for that one category (both supplier types
/// combined, with its own sort/price filter).
class CatalogueScreen extends StatelessWidget {
  const CatalogueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Catalogue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push(AppRoutes.clientSearch),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.1,
        ),
        itemCount: ProductCategory.values.length,
        itemBuilder: (context, index) =>
            _CategoryTile(category: ProductCategory.values[index]),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final ProductCategory category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageAsset = category.imageAsset;

    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.catalogueCategory(category.name)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageAsset != null)
              Image.asset(imageAsset, fit: BoxFit.cover)
            else
              Container(
                color: scheme.primaryContainer,
                child: Icon(category.icon, size: 48, color: scheme.primary),
              ),
            // Bottom gradient so the label stays legible over any photo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                  stops: [0.5, 1],
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Row(
                children: [
                  Icon(category.icon, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      category.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
