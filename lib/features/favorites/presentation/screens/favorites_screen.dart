import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_buy_sheet.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/shop_product_data.dart';

import '../controllers/favorite_controller.dart';
import '../providers/favorite_providers.dart';

/// Les favoris, d'après le `BookmarkScreen` du kit : les articles mis de
/// côté, en grille de cartes.
///
/// Ce que MTC y ajoute : « Choisir » passe en sélection (toucher une carte
/// la coche au lieu de l'ouvrir), et la barre du bas retire les articles
/// choisis ou les met au panier d'un coup.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  bool _selection = false;
  final Set<String> _choisis = {};
  bool _enCours = false;

  void _quitterLaSelection() => setState(() {
    _selection = false;
    _choisis.clear();
  });

  void _basculer(String id) => setState(() {
    if (!_choisis.remove(id)) _choisis.add(id);
  });

  void _signaler(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  /// Retire les favoris [ids] ; rend ceux dont le retrait a échoué.
  Future<List<String>> _retirerOuRemettre(Iterable<String> ids) async {
    final controleur = ref.read(favoriteControllerProvider.notifier);
    final echecs = <String>[];
    for (final id in ids) {
      await controleur.toggle(id);
      if (ref.read(favoriteControllerProvider).hasError) echecs.add(id);
    }
    return echecs;
  }

  Future<void> _retirer() async {
    final ids = _choisis.toList();
    setState(() => _enCours = true);
    final echecs = await _retirerOuRemettre(ids);
    if (!mounted) return;
    setState(() => _enCours = false);
    _quitterLaSelection();
    if (echecs.isNotEmpty) {
      _signaler(
        messagePourUtilisateur(
          ref.read(favoriteControllerProvider).error,
          repli: echecs.length == 1
              ? 'Un article n\'a pas pu être retiré.'
              : '${echecs.length} articles n\'ont pas pu être retirés.',
        ),
      );
      return;
    }
    final retires = ids.length;
    _signaler(
      retires == 1
          ? 'Retiré des favoris.'
          : '$retires articles retirés des favoris.',
      action: SnackBarAction(
        label: 'Annuler',
        onPressed: () => unawaited(_retirerOuRemettre(ids)),
      ),
    );
  }

  /// Met les articles choisis au panier, une unité chacun, variante par
  /// défaut pour ceux qui en ont — comme l'ajout rapide du catalogue. La
  /// quantité et la variante se règlent ensuite dans le panier.
  Future<void> _ajouterAuPanier(List<Product> produits) async {
    final choisis = [
      for (final p in produits)
        if (_choisis.contains(p.id)) p,
    ];
    setState(() => _enCours = true);
    final depot = ref.read(productRepositoryProvider);
    final panier = ref.read(cartControllerProvider.notifier);
    var echecs = 0;
    Object? derniereErreur;
    for (final produit in choisis) {
      try {
        // La grille ne charge pas les variantes : sans elles, l'ajout ne
        // saurait pas quelle variante par défaut prendre.
        final complet = produit.hasVariants
            ? await depot.getById(produit.id)
            : produit;
        await panier.addProduct(complet);
        final etat = ref.read(cartControllerProvider);
        if (etat.hasError) {
          echecs++;
          derniereErreur = etat.error;
        }
      } catch (erreur) {
        echecs++;
        derniereErreur = erreur;
      }
    }
    if (!mounted) return;
    setState(() => _enCours = false);
    if (echecs == choisis.length) {
      _signaler(
        messagePourUtilisateur(
          derniereErreur,
          repli: 'Les articles n\'ont pas pu être ajoutés au panier.',
        ),
      );
      return;
    }
    _quitterLaSelection();
    if (echecs > 0) {
      _signaler(
        echecs == 1
            ? 'Un article n\'a pas pu être ajouté au panier.'
            : '$echecs articles n\'ont pas pu être ajoutés au panier.',
      );
    }
    unawaited(
      showShopSheet<void>(
        context,
        isDismissible: false,
        child: const AddedToCartSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoris = ref.watch(favoriteProductsProvider);
    final produits = favoris.valueOrNull ?? const <Product>[];

    return Scaffold(
      body: favoris.when(
        skipLoadingOnReload: true,
        loading: () => _Grille(
          enTete: null,
          enfants: List.generate(6, (_) => const ProductCardSkeleton()),
        ),
        error: (erreur, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'Vos favoris n\'ont pas pu être chargés',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(favoriteProductsProvider),
            child: const Text('Réessayer'),
          ),
        ),
        data: (liste) {
          if (liste.isEmpty) {
            return const IllustratedMessage(
              illustration: ShopIllustration.emptyState,
              title: 'Aucun favori',
              message:
                  'Touchez le signet d\'un article pour le retrouver ici.',
            );
          }
          return _Grille(
            enTete: _EnTete(
              nombre: liste.length,
              selection: _selection,
              choisis: _choisis.length,
              onChoisir: () => setState(() => _selection = true),
              onToutChoisir: () => setState(() {
                if (_choisis.length == liste.length) {
                  _choisis.clear();
                } else {
                  _choisis.addAll(liste.map((p) => p.id));
                }
              }),
              onAnnuler: _quitterLaSelection,
            ),
            enfants: [
              for (final produit in liste)
                _Carte(
                  produit: produit,
                  selection: _selection,
                  choisi: _choisis.contains(produit.id),
                  onTap: _selection
                      ? () => _basculer(produit.id)
                      : () => context.push(AppRoutes.productDetail(produit.id)),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: _selection && _choisis.isNotEmpty
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ShopSizes.padding,
                  ShopSizes.padding / 2,
                  ShopSizes.padding,
                  ShopSizes.padding,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ShopColors.error,
                        ),
                        onPressed: _enCours ? null : _retirer,
                        child: const Text('Retirer'),
                      ),
                    ),
                    const SizedBox(width: ShopSizes.padding),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _enCours
                            ? null
                            : () => _ajouterAuPanier(produits),
                        child: _enCours
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Au panier'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

/// La grille du kit : cartes de 200 au plus, espacées de 16, marges de 16.
class _Grille extends StatelessWidget {
  const _Grille({required this.enTete, required this.enfants});

  final Widget? enTete;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (enTete != null) SliverToBoxAdapter(child: enTete),
        SliverPadding(
          padding: const EdgeInsets.all(ShopSizes.padding),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: ShopSizes.padding,
              crossAxisSpacing: ShopSizes.padding,
              childAspectRatio: 0.66,
            ),
            delegate: SliverChildListDelegate(enfants),
          ),
        ),
      ],
    );
  }
}

/// Le nombre d'articles et l'entrée en sélection ; en sélection, le compte
/// des choisis, « Tout » et « Annuler ».
class _EnTete extends StatelessWidget {
  const _EnTete({
    required this.nombre,
    required this.selection,
    required this.choisis,
    required this.onChoisir,
    required this.onToutChoisir,
    required this.onAnnuler,
  });

  final int nombre;
  final bool selection;
  final int choisis;
  final VoidCallback onChoisir;
  final VoidCallback onToutChoisir;
  final VoidCallback onAnnuler;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titre = selection
        ? (choisis == 0
              ? 'Touchez les articles à choisir'
              : choisis == 1
              ? '1 article choisi'
              : '$choisis articles choisis')
        : (nombre == 1 ? '1 article' : '$nombre articles');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ShopSizes.padding,
        ShopSizes.padding / 2,
        ShopSizes.padding / 2,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (selection) ...[
            TextButton(
              onPressed: onToutChoisir,
              child: Text(choisis == nombre ? 'Aucun' : 'Tout'),
            ),
            TextButton(onPressed: onAnnuler, child: const Text('Annuler')),
          ] else
            TextButton(onPressed: onChoisir, child: const Text('Choisir')),
        ],
      ),
    );
  }
}

/// Une carte du kit ; en sélection, une coche ronde en haut à gauche.
class _Carte extends StatelessWidget {
  const _Carte({
    required this.produit,
    required this.selection,
    required this.choisi,
    required this.onTap,
  });

  final Product produit;
  final bool selection;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final carte = ShopProductCard(
      width: null,
      height: null,
      data: produit.shopData(),
      onTap: onTap,
    );
    if (!selection) return carte;
    return Semantics(
      selected: choisi,
      child: Stack(
        children: [
          AnimatedOpacity(
            duration: ShopSizes.duration,
            opacity: choisi ? 1 : 0.6,
            child: carte,
          ),
          Positioned(
            top: ShopSizes.padding,
            left: ShopSizes.padding,
            child: IgnorePointer(
              child: choisi
                  ? const CheckMark(radius: 11)
                  : Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.8),
                        border: Border.all(color: ShopColors.black20),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
