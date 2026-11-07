import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/search_text.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart'
    show VerificationStatus;
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart'
    show SupplierType;

import '../../domain/entities/supplier_profile.dart';
import '../providers/supplier_providers.dart';

/// « Boutiques du Mali » : les boutiques que le client peut visiter —
/// identité vérifiée, ou MTC Officiel —, à chercher par nom ou par ville.
/// Une boutique s'ouvre sur sa vitrine (`SupplierProfileScreen`) : ses
/// informations, ses produits, ses avis, et de quoi lui écrire.
///
/// Le kit n'a pas de liste de boutiques : l'écran compose ses fragments —
/// le champ de recherche et les pastilles de la découverte, et des cartes
/// bordées comme les cartes produit.
class ShopsScreen extends ConsumerStatefulWidget {
  const ShopsScreen({super.key});

  @override
  ConsumerState<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends ConsumerState<ShopsScreen> {
  final _recherche = TextEditingController();

  /// La ville choisie dans les pastilles ; `null` = toutes.
  String? _ville;

  @override
  void initState() {
    super.initState();
    _recherche.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  void _toutAfficher() {
    _recherche.clear();
    setState(() => _ville = null);
  }

  @override
  Widget build(BuildContext context) {
    final boutiques = ref.watch(listedShopsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Boutiques du Mali')),
      body: boutiques.when(
        skipLoadingOnReload: true,
        loading: () => ListView(
          padding: const EdgeInsets.all(ShopSizes.padding),
          children: [
            const Skeleton(height: 50),
            for (var i = 0; i < 4; i++) ...[
              const SizedBox(height: ShopSizes.padding),
              const Skeleton(height: 132),
            ],
          ],
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'Les boutiques n\'ont pas pu être chargées',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(listedShopsProvider),
            child: const Text('Réessayer'),
          ),
        ),
        data: (liste) => liste.isEmpty
            ? const IllustratedMessage(
                illustration: ShopIllustration.emptyState,
                title: 'Aucune boutique pour le moment',
                message:
                    'Les boutiques apparaîtront ici dès que MTC aura vérifié '
                    'leur identité.',
              )
            : _Liste(
                boutiques: liste,
                recherche: _recherche,
                ville: _ville,
                onVille: (ville) => setState(() => _ville = ville),
                onToutAfficher: _toutAfficher,
              ),
      ),
    );
  }
}

class _Liste extends ConsumerWidget {
  const _Liste({
    required this.boutiques,
    required this.recherche,
    required this.ville,
    required this.onVille,
    required this.onToutAfficher,
  });

  final List<SupplierProfile> boutiques;
  final TextEditingController recherche;
  final String? ville;
  final ValueChanged<String?> onVille;
  final VoidCallback onToutAfficher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Les villes où il y a des boutiques, et rien d'autre : une pastille qui
    // mènerait à une liste vide n'a rien à faire là.
    final villes = {for (final b in boutiques) b.city}.toList()..sort();
    final trouvees = [
      for (final b in boutiques)
        if ((ville == null || b.city == ville) &&
            matchesAnySearch([b.businessName, b.city], recherche.text))
          b,
    ];

    return RefreshIndicator(
      onRefresh: () => ref.refresh(listedShopsProvider.future),
      child: CustomScrollView(
        // Tirer pour rafraîchir doit marcher même quand la liste est courte.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(ShopSizes.padding),
              child: ShopSearchField(
                hintText: 'Une boutique, une ville…',
                controller: recherche,
              ),
            ),
          ),
          if (villes.length > 1)
            SliverToBoxAdapter(
              child: ShopPillRow(
                children: [
                  ShopPill(
                    label: 'Toutes',
                    active: ville == null,
                    onTap: () => onVille(null),
                  ),
                  for (final v in villes)
                    ShopPill(
                      label: v,
                      active: ville == v,
                      onTap: () => onVille(ville == v ? null : v),
                    ),
                ],
              ),
            ),
          if (trouvees.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: IllustratedMessage(
                illustration: ShopIllustration.noResult,
                title: 'Aucune boutique ne correspond',
                message: 'Essayez un autre nom, ou une autre ville.',
                action: OutlinedButton(
                  onPressed: onToutAfficher,
                  child: const Text('Voir toutes les boutiques'),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                ShopSizes.padding,
                ShopSizes.padding,
                ShopSizes.padding,
                ShopSizes.padding / 2,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  trouvees.length == 1
                      ? '1 boutique'
                      : '${trouvees.length} boutiques',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                ShopSizes.padding,
                0,
                ShopSizes.padding,
                ShopSizes.padding * 2,
              ),
              sliver: SliverList.separated(
                itemCount: trouvees.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: ShopSizes.padding),
                itemBuilder: (context, index) {
                  final b = trouvees[index];
                  return ShopStoreCard(
                    name: b.businessName,
                    city: b.city,
                    rating: b.ratingAverage,
                    ratingCount: b.ratingCount,
                    productCount: b.listedProductCount,
                    bannerPath: b.bannerUrl,
                    isOpen: b.isOpen,
                    verified:
                        b.verificationStatus == VerificationStatus.verified,
                    official: b.supplierType == SupplierType.principal,
                    onTap: () => context.push(AppRoutes.supplierProfile(b.id)),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
