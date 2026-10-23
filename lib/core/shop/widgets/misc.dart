import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../shop_icons.dart';
import '../shop_text_styles.dart';
import '../shop_tokens.dart';

/// Le nom de l'app en tête de l'accueil, à la place du « Shoplon » du kit.
class ShopLogo extends StatelessWidget {
  const ShopLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MTC — Mali Trade Connect',
      excludeSemantics: true,
      child: Text(
        'MTC',
        style: ShopTextStyles.display(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Une icône du kit avec son compteur : panier, notifications non lues.
class ShopBadgeIcon extends StatelessWidget {
  const ShopBadgeIcon(this.icon, {super.key, required this.count, this.color});

  final String icon;
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      backgroundColor: ShopColors.error,
      label: Text(count > 99 ? '99+' : '$count'),
      child: ShopIcon(icon, color: color),
    );
  }
}

/// Le bouton en pointillés des maquettes (« Ajouter une adresse »).
class DashedButton extends StatelessWidget {
  const DashedButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;

  /// Une icône du kit.
  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ShopSizes.radius),
      child: CustomPaint(
        painter: _Pointilles(scheme.onSurface.withValues(alpha: 0.12)),
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShopIcon(icon),
              const SizedBox(width: ShopSizes.padding / 2),
              // Sur un écran étroit ou en grands caractères, le libellé
              // s'abrège au lieu de déborder du cadre.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pointilles extends CustomPainter {
  _Pointilles(this.couleur);

  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final pinceau = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final contour = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(ShopSizes.radius),
        ),
      );
    for (final mesure in contour.computeMetrics()) {
      var distance = 0.0;
      while (distance < mesure.length) {
        canvas.drawPath(mesure.extractPath(distance, distance + 6), pinceau);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_Pointilles old) => old.couleur != couleur;
}

/// La coche ronde du kit, sur une couleur ou une adresse choisie.
class CheckMark extends StatelessWidget {
  const CheckMark({
    super.key,
    this.radius = 8,
    this.color = ShopColors.primary,
  });

  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ShopIcon(
          ShopIcons.singlecheck,
          size: radius * 1.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Une icône du kit en tête de champ de saisie (`prefixIcon`), grisée comme
/// celles des formulaires du kit.
class ShopFieldIcon extends StatelessWidget {
  const ShopFieldIcon(this.icon, {super.key});

  final String icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: ShopIcon(
      icon,
      size: 20,
      color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.3),
    ),
  );
}

/// Un compte en pastille colorée, avant un chevron : l'historique des
/// commandes (maquette « Orders »), les messages non lus du profil.
class CountPill extends StatelessWidget {
  const CountPill({
    super.key,
    required this.count,
    this.color = ShopColors.primary,
  });

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ShopSizes.radius),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

/// Un état en pastille colorée, texte blanc : l'état d'une commande, une
/// boutique ouverte ou vérifiée. Se lit sans lire.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ShopSizes.padding / 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ShopSizes.radius),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// L'en-tête du profil (`ProfileCard` du kit) : avatar, « Bonjour, … »,
/// une ligne grise, chevron.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.name,
    required this.subtitle,
    this.avatarPath,
    this.onTap,
    this.greet = true,
    this.showChevron = true,
    this.contentPadding,
  });

  final String name;
  final String subtitle;

  /// La photo du compte, s'il en a une : voir [ShopAvatar].
  final String? avatarPath;
  final VoidCallback? onTap;
  final bool greet;
  final bool showChevron;

  /// `EdgeInsets.zero` dans une page déjà bordée de sa marge (la fiche
  /// « Profile » du kit), sinon la marge d'une ligne de menu.
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: contentPadding,
      leading: ShopAvatar(name: name, imagePath: avatarPath),
      title: Text(
        greet ? 'Bonjour, $name' : name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      // Gris comme l'e-mail du kit : le nom se lit d'abord.
      subtitle: Text(subtitle, style: theme.textTheme.bodyMedium),
      trailing: showChevron
          ? ShopIcon(
              ShopIcons.miniRight,
              color: theme.iconTheme.color?.withValues(alpha: 0.4),
            )
          : null,
    );
  }

  /// « Awa Traoré » → « AT » : ce qu'affiche un compte sans photo.
  static String initiales(String nom) {
    final mots = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
    if (mots.isEmpty) return '?';
    return mots.take(2).map((m) => m.characters.first.toUpperCase()).join();
  }
}

/// L'adresse signée d'une photo de profil, une par chemin.
///
/// Le bucket `avatars` est privé (`0121`) : chaque affichage passe par une
/// URL signée. La redemander à chaque reconstruction changerait l'URL, donc
/// l'entrée du cache d'images, et la photo se rechargerait sans cesse. Gardée
/// tant qu'un écran la montre.
final avatarUrlProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  path,
) {
  return ref
      .watch(supabaseClientProvider)
      .storage
      .from('avatars')
      .createSignedUrl(path, 3600);
});

/// L'avatar d'un compte : sa photo quand il en a une, ses initiales sinon —
/// et aussi le temps que la photo arrive, ou si elle n'arrive pas.
///
/// [preview] montre une photo choisie mais pas encore envoyée.
class ShopAvatar extends ConsumerWidget {
  const ShopAvatar({
    super.key,
    required this.name,
    this.imagePath,
    this.preview,
    this.radius = 28,
  });

  final String name;

  /// Le chemin dans le bucket `avatars`.
  final String? imagePath;
  final ImageProvider? preview;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chemin = imagePath;
    final url = chemin == null
        ? null
        : ref.watch(avatarUrlProvider(chemin)).valueOrNull;
    final image = preview ?? (url == null ? null : NetworkImage(url));

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundImage: image,
      // Une photo qui ne se charge pas laisse voir les initiales dessous.
      onForegroundImageError: image == null ? null : (_, _) {},
      child: Text(
        ProfileCard.initiales(name),
        style:
            (radius >= 40
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.titleSmall)
                ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
      ),
    );
  }
}

/// Une notification du kit : pastille de couleur avec son icône, point
/// orange tant qu'elle n'est pas lue, texte, ancienneté.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.timeAgo,
    required this.unread,
    this.body,
    this.onTap,
    this.unreadKey,
  });

  /// Une icône du kit, blanche sur [color].
  final String icon;
  final Color color;
  final String title;

  /// Le détail sous le titre (« Votre commande chez … est en route ») : le
  /// kit n'a qu'un texte, une notification MTC en a deux.
  final String? body;
  final String timeAgo;
  final bool unread;
  final VoidCallback? onTap;

  /// Clé du point « non lue », pour les tests.
  final Key? unreadKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ShopSizes.padding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: color,
                        child: ShopIcon(icon, color: Colors.white),
                      ),
                      if (unread)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Semantics(
                            label: 'Non lue',
                            child: Container(
                              key: unreadKey,
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B3D),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: ShopSizes.padding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: unread
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                      if (body case final detail? when detail.isNotEmpty) ...[
                        const SizedBox(height: ShopSizes.padding / 4),
                        Text(
                          detail,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: ShopSizes.padding / 4),
                      Text(timeAgo, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Une adresse en carte (maquette « Address ») : pastille d'icône cochée,
/// nom, adresse et téléphone en gris ; cerclée de violet si c'est celle
/// par défaut, avec son ruban.
class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.label,
    required this.lines,
    this.isDefault = false,
    this.selected = false,
    this.showCheck = true,
    this.onTap,
    this.trailing,
    this.footer,
  });

  final String label;
  final List<String> lines;

  /// Sous l'adresse : un avertissement, une précision.
  final Widget? footer;

  /// Le ruban « Par défaut », et l'accent violet.
  final bool isDefault;

  /// Choisie dans une liste (un point de livraison) : l'accent violet, sans
  /// ruban.
  final bool selected;

  /// La coche sur l'icône : celle d'une adresse enregistrée. Dans une liste
  /// de choix, elle ne marque que l'élément choisi.
  final bool showCheck;
  final VoidCallback? onTap;

  /// Un menu ou un bouton, en haut à droite.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enAvant = isDefault || selected;
    final accent = enAvant ? ShopColors.primary : ShopColors.success;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShopSizes.radius),
        side: BorderSide(
          color: enAvant ? ShopColors.primary : scheme.outline,
          width: enAvant ? 2 : 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(ShopSizes.padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox.square(
                        dimension: 32,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: accent, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: ShopIcon(
                                ShopIcons.address,
                                size: 16,
                                color: accent,
                              ),
                            ),
                            if (showCheck)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: CheckMark(radius: 7, color: accent),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: ShopSizes.padding / 2 + 4),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: enAvant
                                ? ShopColors.primary
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      if (trailing != null)
                        trailing!
                      else if (isDefault)
                        const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: ShopSizes.padding / 2 + 4),
                  for (final ligne in lines)
                    Text(ligne, style: theme.textTheme.bodyMedium),
                  if (footer != null) ...[
                    const SizedBox(height: ShopSizes.padding / 2),
                    footer!,
                  ],
                ],
              ),
            ),
            if (isDefault)
              Positioned(
                top: 0,
                right: 0,
                child: ClipRect(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 12,
                          right: -28,
                          child: Transform.rotate(
                            angle: 0.785398,
                            child: Container(
                              width: 112,
                              color: ShopColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              alignment: Alignment.center,
                              child: const Text(
                                'Par défaut',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
