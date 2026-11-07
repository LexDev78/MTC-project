import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/search_text.dart';
import 'package:mtc_app/features/recommendations/domain/entities/recent_search.dart';
import 'package:mtc_app/features/recommendations/domain/repositories/recommendation_repository.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';

import '../../domain/entities/product.dart';
import '../../domain/product_list_filters.dart';
import '../providers/catalog_providers.dart';
import '../widgets/product_filter_sheet.dart';
import '../widgets/shop_product_grid.dart';

/// La recherche, d'après les maquettes « Search » du kit : le logo et la
/// croix, le champ avec son filtre, puis selon ce qui est tapé —
///
///  * rien : les recherches récentes, « Tout voir » menant à l'historique ;
///  * un début de mot : les suggestions (recherches passées et articles qui
///    correspondent), la partie trouvée en valeur ;
///  * une recherche validée : les résultats en grille, ou l'écran « aucun
///    résultat ».
///
/// Une recherche est notée quand elle est validée, ou quand le client quitte
/// l'écran avec — pas à chaque pause de frappe, qui enregistrerait « bog »,
/// « bogo », « bogolan » comme trois intentions.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _champ = TextEditingController();
  final _focus = FocusNode();
  Timer? _attente;

  /// Le texte de la dernière recherche validée : les résultats ne
  /// s'affichent que tant que le champ le porte encore.
  String _validee = '';

  /// Lu une fois ici : `dispose` note la dernière recherche, et `ref` n'y
  /// est plus utilisable.
  late final RecommendationRepository _recommandations;
  String _derniereNotee = '';

  @override
  void initState() {
    super.initState();
    _recommandations = ref.read(recommendationRepositoryProvider);
  }

  @override
  void dispose() {
    _noter(_champ.text);
    _attente?.cancel();
    _champ.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _noter(String texte, {VoidCallback? ensuite}) {
    final recherche = texte.trim();
    if (recherche.isEmpty || recherche == _derniereNotee) return;
    _derniereNotee = recherche;
    unawaited(_recommandations.logSearch(recherche).then((_) => ensuite?.call()));
  }

  /// Sans cette attente, chaque lettre lancerait une requête au milieu du
  /// mot. 300 ms absorbent une frappe normale et restent immédiates à
  /// l'arrêt.
  void _surFrappe(String texte) {
    setState(() {});
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(globalSearchQueryProvider.notifier).state = texte.trim();
    });
  }

  void _chercher([String? texte]) {
    if (texte != null) {
      _champ.value = TextEditingValue(
        text: texte,
        selection: TextSelection.collapsed(offset: texte.length),
      );
    }
    final recherche = _champ.text.trim();
    if (recherche.isEmpty) return;
    _attente?.cancel();
    ref.read(globalSearchQueryProvider.notifier).state = recherche;
    setState(() => _validee = recherche);
    _focus.unfocus();
    _noter(
      recherche,
      ensuite: () {
        if (mounted) ref.invalidate(recentSearchesProvider);
      },
    );
  }

  Future<void> _oublier(String recherche) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      await _recommandations.forgetSearches(query: recherche);
      if (_derniereNotee == recherche) _derniereNotee = '';
      ref.invalidate(recentSearchesProvider);
    } catch (erreur) {
      messager.showSnackBar(
        SnackBar(
          content: Text(
            messagePourUtilisateur(
              erreur,
              repli: 'Cette recherche n\'a pas pu être effacée.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _filtrer() async {
    final choix = await showProductFilterSheet(
      context,
      products: ref.read(globalSearchResultsProvider).valueOrNull ?? const [],
      current: ref.read(searchFiltersProvider),
    );
    if (choix != null && mounted) {
      ref.read(searchFiltersProvider.notifier).state = choix;
    }
  }

  Future<void> _historique() async {
    final choisie = await context.push<String>(AppRoutes.clientSearchHistory);
    if (choisie != null && mounted) _chercher(choisie);
    if (mounted) ref.invalidate(recentSearchesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final texte = _champ.text.trim();
    final enResultats = texte.isNotEmpty && texte == _validee;
    final filtres = ref.watch(searchFiltersProvider);
    // Écouté ici, et pas seulement par la liste qui l'affiche : sinon, entre
    // deux affichages (les récentes n'en dépendent pas), le texte cherché
    // n'a plus d'écouteur, et `autoDispose` l'efface aussitôt écrit — toucher
    // une recherche récente donnait « aucun résultat ».
    ref.watch(globalSearchQueryProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ShopSizes.screenMargin,
                ShopSizes.padding,
                ShopSizes.padding,
                0,
              ),
              child: Row(
                children: [
                  const ShopLogo(),
                  const Spacer(),
                  // Chercher par photo : le recours quand le mot manque.
                  IconButton(
                    tooltip: 'Rechercher par photo',
                    onPressed: () => context.push(AppRoutes.clientVisualSearch),
                    icon: const ShopIcon(ShopIcons.cameraAdd),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => context.pop(),
                    icon: const ShopIcon(ShopIcons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ShopSizes.screenMargin,
                ShopSizes.padding,
                ShopSizes.screenMargin,
                ShopSizes.padding,
              ),
              child: ShopSearchField(
                hintText: 'Rechercher un article…',
                controller: _champ,
                focusNode: _focus,
                autofocus: true,
                onChanged: _surFrappe,
                onSubmitted: (_) => _chercher(),
                onFilterTap: _filtrer,
                filterActive: filtres.isActive,
              ),
            ),
            Expanded(
              child: texte.isEmpty
                  ? _Recentes(
                      onChoisir: _chercher,
                      onOublier: _oublier,
                      onToutVoir: _historique,
                    )
                  : enResultats
                  ? _Resultats(
                      recherche: texte,
                      filtres: filtres,
                      onEffacerFiltres: () =>
                          ref.read(searchFiltersProvider.notifier).state =
                              ProductListFilters(sort: filtres.sort),
                    )
                  : _Suggestions(
                      texte: texte,
                      onChoisir: _chercher,
                      onOublier: _oublier,
                      onRechercher: _chercher,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le bouton du bas des listes (« Search » des maquettes), sous les lignes
/// plutôt que collé au bas de l'écran : le clavier le cacherait.
class _BoutonRechercher extends StatelessWidget {
  const _BoutonRechercher({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ShopSizes.padding * 2.5),
      child: ElevatedButton(
        onPressed: onPressed,
        child: const Text('Rechercher'),
      ),
    );
  }
}

/// Le champ vide : les dernières recherches, à relancer d'un toucher.
class _Recentes extends ConsumerWidget {
  const _Recentes({
    required this.onChoisir,
    required this.onOublier,
    required this.onToutVoir,
  });

  final ValueChanged<String> onChoisir;
  final ValueChanged<String> onOublier;
  final VoidCallback onToutVoir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentes = ref.watch(recentSearchesProvider);
    final liste = recentes.valueOrNull ?? const <RecentSearch>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ShopSizes.screenMargin,
        0,
        ShopSizes.screenMargin,
        ShopSizes.padding * 2,
      ),
      children: [
        SectionTitle(
          'Recherches récentes',
          padding: const EdgeInsets.only(bottom: ShopSizes.padding / 4),
          actionLabel: liste.isEmpty ? null : 'Tout voir',
          onAction: onToutVoir,
        ),
        if (recentes.isLoading && liste.isEmpty)
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: ShopSizes.padding),
              child: Skeleton(height: 24),
            )
        else if (liste.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: ShopSizes.padding / 2),
            child: Text(
              recentes.hasError
                  ? 'Vos recherches récentes n\'ont pas pu être chargées.'
                  : 'Vos recherches apparaîtront ici.',
            ),
          )
        else
          for (final (index, r) in liste.take(5).indexed)
            SearchHistoryTile(
              text: r.query,
              onTap: () => onChoisir(r.query),
              onRemove: () => onOublier(r.query),
              showDivider: index < liste.take(5).length - 1,
            ),
        const _BoutonRechercher(onPressed: null),
      ],
    );
  }
}

/// Pendant la frappe : les recherches passées qui contiennent le texte,
/// puis les articles dont le nom y répond.
class _Suggestions extends ConsumerWidget {
  const _Suggestions({
    required this.texte,
    required this.onChoisir,
    required this.onOublier,
    required this.onRechercher,
  });

  final String texte;
  final ValueChanged<String> onChoisir;
  final ValueChanged<String> onOublier;
  final VoidCallback onRechercher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passees = [
      for (final r
          in ref.watch(recentSearchesProvider).valueOrNull ??
              const <RecentSearch>[])
        if (matchesSearch(r.query, texte)) r.query,
    ].take(3).toList();
    final dejaVus = {for (final p in passees) normalizeForSearch(p)};
    final articles = <Product>[
      for (final p
          in ref.watch(globalSearchResultsProvider).valueOrNull ??
              const <Product>[])
        if (matchesSearch(p.name, texte) &&
            dejaVus.add(normalizeForSearch(p.name)))
          p,
    ].take(5).toList();
    final total = passees.length + articles.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ShopSizes.screenMargin,
        0,
        ShopSizes.screenMargin,
        ShopSizes.padding * 2,
      ),
      children: [
        for (final (index, recherche) in passees.indexed)
          SearchHistoryTile(
            text: recherche,
            highlight: texte,
            showClock: false,
            onTap: () => onChoisir(recherche),
            onRemove: () => onOublier(recherche),
            showDivider: index < total - 1,
          ),
        for (final (index, produit) in articles.indexed)
          SearchHistoryTile(
            text: produit.name,
            highlight: texte,
            showClock: false,
            onTap: () => context.push(AppRoutes.productDetail(produit.id)),
            showDivider: passees.length + index < total - 1,
          ),
        _BoutonRechercher(onPressed: onRechercher),
      ],
    );
  }
}

/// Une recherche validée : le compte et la grille, ou pourquoi il n'y a
/// rien.
class _Resultats extends ConsumerWidget {
  const _Resultats({
    required this.recherche,
    required this.filtres,
    required this.onEffacerFiltres,
  });

  final String recherche;
  final ProductListFilters filtres;
  final VoidCallback onEffacerFiltres;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tous = ref.watch(globalSearchResultsProvider);
    final resultats = ref.watch(searchResultsProvider);
    final theme = Theme.of(context);

    return resultats.when(
      // Les résultats d'avant restent affichés pendant que les nouveaux
      // arrivent : une grille qui clignote à chaque recherche se lit mal.
      skipLoadingOnReload: true,
      loading: () => GridView.count(
        padding: const EdgeInsets.all(ShopSizes.screenMargin),
        crossAxisCount: 2,
        mainAxisSpacing: ShopSizes.padding,
        crossAxisSpacing: ShopSizes.padding,
        childAspectRatio: 0.66,
        children: List.generate(4, (_) => const ProductCardSkeleton()),
      ),
      error: (erreur, _) => IllustratedMessage(
        illustration: ShopIllustration.serverError,
        title: 'La recherche n\'a pas abouti',
        message: messagePourUtilisateur(erreur),
        action: OutlinedButton(
          onPressed: () => ref.invalidate(globalSearchResultsProvider),
          child: const Text('Réessayer'),
        ),
      ),
      data: (liste) {
        if (liste.isEmpty) {
          final parFiltres =
              filtres.hasFilter && (tous.valueOrNull?.isNotEmpty ?? false);
          return IllustratedMessage(
            illustration: ShopIllustration.noResult,
            title: parFiltres
                ? 'Aucun article pour ces filtres'
                : 'Aucun résultat',
            message: parFiltres
                ? '« $recherche » donne des articles, mais aucun ne passe '
                      'les filtres choisis.'
                : 'Rien ne répond à « $recherche ». Vérifiez l\'orthographe, '
                      'essayez un mot plus court, ou cherchez par photo.',
            action: parFiltres
                ? OutlinedButton(
                    onPressed: onEffacerFiltres,
                    child: const Text('Effacer les filtres'),
                  )
                : OutlinedButton(
                    onPressed: () =>
                        context.push(AppRoutes.clientVisualSearch),
                    child: const Text('Rechercher par photo'),
                  ),
          );
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: ShopSizes.screenMargin,
              ),
              sliver: SliverToBoxAdapter(
                child: Text.rich(
                  TextSpan(
                    text: 'Résultats ',
                    style: theme.textTheme.titleSmall,
                    children: [
                      TextSpan(
                        text: liste.length == 1
                            ? '(1 article)'
                            : '(${liste.length} articles)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverShopProductGrid(
              products: liste,
              padding: ShopSizes.screenMargin,
              top: ShopSizes.padding * 1.5,
            ),
          ],
        );
      },
    );
  }
}
