import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/shop_product_grid.dart';
import 'package:mtc_app/features/chat/presentation/open_shop_conversation.dart';
import 'package:mtc_app/features/ratings/presentation/providers/review_providers.dart';
import 'package:mtc_app/features/ratings/presentation/widgets/review_media.dart';

import '../../domain/entities/supplier_profile.dart';
import '../providers/supplier_providers.dart';

/// La vitrine d'une boutique, vue par le client, avec les fragments du
/// kit : son en-tête et ses états en pastilles, ce qu'il faut savoir pour
/// commander (adresse, horaires, téléphones, zones livrées), « Écrire à la
/// boutique », ses produits en grille et ses derniers avis.
class SupplierProfileScreen extends ConsumerWidget {
  const SupplierProfileScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boutique = ref.watch(supplierDetailProvider(supplierId));

    return Scaffold(
      appBar: AppBar(
        title: Text(boutique.valueOrNull?.businessName ?? 'Boutique'),
      ),
      body: boutique.when(
        skipLoadingOnReload: true,
        loading: () => ListView(
          padding: const EdgeInsets.all(ShopSizes.screenMargin),
          children: const [
            Skeleton(height: 130),
            SizedBox(height: ShopSizes.padding),
            Skeleton(height: 64),
            SizedBox(height: ShopSizes.padding),
            Skeleton(height: 220),
          ],
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'La boutique n\'a pas pu être chargée',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(supplierDetailProvider(supplierId)),
            child: const Text('Réessayer'),
          ),
        ),
        data: (boutique) => _Vitrine(boutique: boutique),
      ),
    );
  }
}

class _Vitrine extends ConsumerWidget {
  const _Vitrine({required this.boutique});

  final SupplierProfile boutique;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final produits = ref.watch(supplierProductsProvider(boutique.id));

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            ShopSizes.screenMargin,
            ShopSizes.padding,
            ShopSizes.screenMargin,
            0,
          ),
          sliver: SliverList.list(
            children: [
              if (boutique.bannerUrl case final banniere?) ...[
                AspectRatio(
                  aspectRatio: 2.4,
                  child: ShopImage(
                    banniere,
                    bucket: 'supplier-branding',
                    cacheWidth: 800,
                  ),
                ),
                const SizedBox(height: ShopSizes.padding * 1.5),
              ],
              _EnTete(boutique: boutique),
              if (boutique.description case final description?
                  when description.trim().isNotEmpty) ...[
                const SizedBox(height: ShopSizes.padding),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: ShopSizes.padding / 2),
              if (boutique.fullAddress case final adresse?)
                _Ligne(icon: ShopIcons.location, text: adresse),
              if (boutique.openingHoursLabel case final horaires?)
                _Ligne(icon: ShopIcons.clock, text: horaires),
              if (boutique.publicPhoneNumbers.isNotEmpty)
                _Ligne(
                  icon: ShopIcons.call,
                  text: boutique.publicPhoneNumbers.join(' · '),
                ),
              if (boutique.deliveryZones.isNotEmpty)
                _Ligne(
                  icon: ShopIcons.delivery,
                  text: 'Livre à ${boutique.deliveryZones.join(', ')}',
                ),
              const SizedBox(height: ShopSizes.padding),
              OutlinedButton.icon(
                onPressed: () => openShopConversation(
                  context,
                  ref,
                  supplierId: boutique.id,
                  supplierName: boutique.businessName,
                ),
                icon: const ShopIcon(ShopIcons.chat, size: 20),
                label: const Text('Écrire à la boutique'),
              ),
              const SizedBox(height: ShopSizes.padding * 1.5),
              Text(
                boutique.listedProductCount == 1
                    ? '1 produit'
                    : '${boutique.listedProductCount} produits',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: ShopSizes.padding / 2),
            ],
          ),
        ),
        ...produits.when(
          skipLoadingOnReload: true,
          loading: () => const [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: ShopSizes.screenMargin),
              sliver: SliverToBoxAdapter(child: Skeleton(height: 220)),
            ),
          ],
          error: (erreur, _) => [
            SliverToBoxAdapter(
              child: IllustratedMessage(
                compact: true,
                illustration: ShopIllustration.serverError,
                title: 'Les produits n\'ont pas pu être chargés',
                message: messagePourUtilisateur(erreur),
              ),
            ),
          ],
          data: (liste) => liste.isEmpty
              ? const [
                  SliverToBoxAdapter(
                    child: IllustratedMessage(
                      compact: true,
                      illustration: ShopIllustration.emptyState,
                      title: 'Aucun produit en vente',
                      message:
                          'Cette boutique n\'a rien en vente pour le moment.',
                    ),
                  ),
                ]
              : [
                  SliverShopProductGrid(
                    products: liste,
                    padding: ShopSizes.screenMargin,
                    top: 0,
                  ),
                ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            ShopSizes.screenMargin,
            ShopSizes.padding * 2,
            ShopSizes.screenMargin,
            ShopSizes.screenMargin,
          ),
          sliver: SliverToBoxAdapter(child: _Avis(boutique: boutique)),
        ),
      ],
    );
  }
}

/// La boutique en tête : sa pastille, son nom, sa ville, sa note, et ses
/// états en pastilles colorées.
class _EnTete extends StatelessWidget {
  const _EnTete({required this.boutique});

  final SupplierProfile boutique;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const StoreAvatar(),
            const SizedBox(width: ShopSizes.padding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    boutique.businessName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(boutique.city, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: ShopSizes.padding / 4),
                  StoreRating(
                    rating: boutique.ratingAverage,
                    count: boutique.ratingCount,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: ShopSizes.padding * 0.75),
        StoreBadges(
          isOpen: boutique.isOpen,
          verified: boutique.verificationStatus == VerificationStatus.verified,
          official: boutique.supplierType == SupplierType.principal,
        ),
      ],
    );
  }
}

/// Une information pratique : l'icône du kit, puis le texte.
class _Ligne extends StatelessWidget {
  const _Ligne({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: ShopSizes.padding / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShopIcon(
            icon,
            size: 18,
            color: theme.iconTheme.color?.withValues(alpha: 0.5),
          ),
          const SizedBox(width: ShopSizes.padding / 2),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Les cinq derniers avis, en cartes du kit, avec la réponse de la
/// boutique.
class _Avis extends ConsumerWidget {
  const _Avis({required this.boutique});

  final SupplierProfile boutique;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final avis = ref.watch(supplierReviewsProvider(boutique.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Avis clients', style: theme.textTheme.titleSmall),
        const SizedBox(height: ShopSizes.padding),
        avis.when(
          skipLoadingOnReload: true,
          loading: () => const Skeleton(height: 120),
          error: (erreur, _) => Text(
            messagePourUtilisateur(
              erreur,
              repli: 'Les avis n\'ont pas pu être chargés.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          data: (liste) {
            if (liste.isEmpty) {
              return Text(
                'Aucun avis pour le moment : les clients notent la boutique '
                'une fois leur commande reçue.',
                style: theme.textTheme.bodyMedium,
              );
            }
            return Column(
              children: [
                for (final un in liste.take(5)) ...[
                  ReviewTile(
                    // Un avis ne se laisse qu'après une commande livrée ;
                    // le nom de son auteur n'est pas rendu ici. « Client »,
                    // comme les notes anonymes des livreurs.
                    author: 'Client',
                    timeAgo: DateFormatter.relative(un.createdAt),
                    rating: un.stars.toDouble(),
                    title: un.title,
                    comment: un.comment,
                    footer:
                        un.imagePaths.isEmpty &&
                            un.videoPath == null &&
                            un.supplierReply == null
                        ? null
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MediaStrip(
                                imagePaths: un.imagePaths,
                                videoPath: un.videoPath,
                                thumbnailSize: 64,
                              ),
                              if (un.supplierReply case final reponse?) ...[
                                const SizedBox(height: ShopSizes.padding / 2),
                                SellerReply(text: reponse),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: ShopSizes.padding),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
