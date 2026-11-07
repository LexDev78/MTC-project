import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';

/// La coquille du client, d'après l'`EntryPoint` du kit FlutterShop.
///
/// En haut, une barre commune à tous les onglets : le nom de l'app, la
/// recherche, les notifications. En bas, cinq onglets au trait dont seul
/// l'actif porte son libellé, en violet. Chaque onglet est une
/// `StatefulShellBranch` (`app_router.dart`) : en changer garde la pile et
/// le défilement de chacun.
class ClientShell extends ConsumerStatefulWidget {
  const ClientShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends ConsumerState<ClientShell> {
  @override
  void initState() {
    super.initState();
    // La coquille reste montée toute la session, et les notifications ne
    // sont pas suivies en temps réel : sans cette relecture à l'ouverture,
    // le compteur de la cloche resterait celui du tout premier affichage.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(currentUserProvider).valueOrNull?.id;
      if (userId != null) ref.invalidate(notificationsProvider(userId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;
    final userId = ref.watch(
      currentUserProvider.select((u) => u.valueOrNull?.id),
    );
    final nonLues = userId == null
        ? 0
        : ref.watch(unreadNotificationCountProvider(userId));
    final articles = ref.watch(cartItemCountProvider);

    // Au repos, les icônes prennent la couleur du texte — atténuée en
    // sombre, pour que la barre ne soit pas la zone la plus vive.
    final repos = theme.iconTheme.color!.withValues(alpha: sombre ? 0.3 : 1);
    BottomNavigationBarItem onglet(String icone, String libelle) =>
        BottomNavigationBarItem(
          icon: ShopIcon(icone, color: repos),
          activeIcon: ShopIcon(icone, color: ShopColors.primary),
          label: libelle,
          tooltip: libelle,
        );

    return Scaffold(
      appBar: AppBar(
        leading: const SizedBox(),
        leadingWidth: 0,
        centerTitle: false,
        titleSpacing: ShopSizes.padding,
        title: const ShopLogo(),
        actions: [
          IconButton(
            tooltip: 'Rechercher',
            onPressed: () => context.push(AppRoutes.clientSearch),
            icon: const ShopIcon(ShopIcons.search),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push(AppRoutes.clientNotifications),
            icon: ShopBadgeIcon(ShopIcons.notification, count: nonLues),
          ),
          const SizedBox(width: ShopSizes.padding / 2),
        ],
      ),
      body: shell,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(top: ShopSizes.padding / 2),
        color: theme.bottomNavigationBarTheme.backgroundColor,
        child: BottomNavigationBar(
          currentIndex: shell.currentIndex,
          onTap: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          items: [
            onglet(ShopIcons.shop, 'Accueil'),
            onglet(ShopIcons.category, 'Découvrir'),
            onglet(ShopIcons.bookmark, 'Favoris'),
            BottomNavigationBarItem(
              icon: _Sac(articles: articles, color: repos),
              activeIcon: _Sac(articles: articles, color: ShopColors.primary),
              label: 'Panier',
              // L'infobulle reste « Panier » : c'est le nom de l'onglet. Le
              // nombre d'articles est dit par le sac lui-même (`_Sac`).
              tooltip: 'Panier',
            ),
            onglet(ShopIcons.profile, 'Profil'),
          ],
        ),
      ),
    );
  }
}

/// Le sac du panier (`ShoppingBag` du kit) : vide, il est au trait ;
/// garni, il est plein et porte le nombre d'articles en son centre.
class _Sac extends StatelessWidget {
  const _Sac({required this.articles, required this.color});

  final int articles;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (articles == 0) return ShopIcon(ShopIcons.bag, color: color);
    // Le chiffre se lit sur le sac plein : clair sur un sac sombre, sombre
    // sur un sac clair.
    final surSacClair = color.computeLuminance() > 0.5;
    final stack = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        ShopIcon(ShopIcons.bagFull, color: color),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            articles > 9 ? '9+' : '$articles',
            style: ShopTextStyles.display(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: surSacClair ? ShopColors.black : Colors.white,
            ),
          ),
        ),
      ],
    );
    // Le chiffre dessiné sur le sac, dit aussi aux lecteurs d'écran.
    return Semantics(
      label: articles == 1 ? '1 article' : '$articles articles',
      child: ExcludeSemantics(child: stack),
    );
  }
}
