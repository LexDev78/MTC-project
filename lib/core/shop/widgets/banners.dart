import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../shop_icons.dart';
import '../shop_text_styles.dart';
import '../shop_tokens.dart';
import 'shop_image.dart';

/// Les trois proportions de bannière du kit (`Banner/L`, `M`, `S`).
enum ShopBannerSize {
  large(1.1),
  medium(1.87),
  small(2.56);

  const ShopBannerSize(this.aspectRatio);

  final double aspectRatio;
}

/// Le cadre commun : une photo, un voile noir, le contenu par-dessus.
///
/// Le voile rend le texte blanc lisible quelle que soit la photo, et dans
/// les deux thèmes : le fond est toujours sombre.
class ShopBanner extends StatelessWidget {
  const ShopBanner({
    super.key,
    required this.image,
    this.bucket = 'product-images',
    this.size = ShopBannerSize.medium,
    this.aspectRatio,
    this.onTap,
    required this.children,
  });

  final String? image;
  final String bucket;
  final ShopBannerSize size;

  /// Une proportion hors des trois du kit (la bande de vente flash).
  final double? aspectRatio;
  final VoidCallback? onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio ?? size.aspectRatio,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ShopImage(image, bucket: bucket, radius: 0, cacheWidth: 800),
            const ColoredBox(color: Colors.black45),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Le grand titre d'une bannière, en capitales.
class BannerHeadline extends StatelessWidget {
  const BannerHeadline(
    this.text, {
    super.key,
    this.fontSize = 28,
    this.textAlign = TextAlign.start,
    this.maxLines = 2,
  });

  final String text;
  final double fontSize;
  final TextAlign textAlign;

  /// La bannière a une hauteur fixe : un libellé de promotion trop long
  /// s'arrête plutôt que de déborder.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final texte = text.toUpperCase();
    return LayoutBuilder(
      builder: (context, contraintes) {
        // Un mot plus large que la bannière serait coupé en son milieu
        // (« FOURNISSEUR / S ») : la taille baisse jusqu'à ce que le plus
        // long tienne sur une ligne, sans descendre sous 18.
        var taille = fontSize;
        if (contraintes.hasBoundedWidth) {
          final plusLong = texte.split(RegExp(r'\s+')).fold<double>(0, (
            largeur,
            mot,
          ) {
            final peintre = TextPainter(
              text: TextSpan(
                text: mot,
                style: ShopTextStyles.display(fontSize: fontSize),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout();
            return peintre.width > largeur ? peintre.width : largeur;
          });
          if (plusLong > contraintes.maxWidth) {
            taille = (fontSize * contraintes.maxWidth / plusLong).clamp(
              18,
              fontSize,
            );
          }
        }
        return Text(
          texte,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: ShopTextStyles.display(fontSize: taille),
        );
      },
    );
  }
}

/// L'étiquette claire posée sur une bannière (« OFFRE SPÉCIALE »).
class BannerChip extends StatelessWidget {
  const BannerChip(this.text, {super.key, this.fontSize = 12});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ShopSizes.padding / 2,
        vertical: ShopSizes.padding / 8,
      ),
      color: Colors.white70,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

/// Le bouton rond blanc à flèche, à droite des bannières.
class BannerArrowButton extends StatelessWidget {
  const BannerArrowButton({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Center(
            child: ShopIcon(ShopIcons.arrowRight, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

/// « Découvrir », souligné d'un trait — l'appel du style 1.
class BannerCallToAction extends StatelessWidget {
  const BannerCallToAction(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(
          width: 64,
          child: Divider(color: Colors.white, thickness: 2, height: 8),
        ),
      ],
    );
  }
}

/// L'étiquette dentelée « 50 % » qui pend du haut des bannières.
class BannerDiscountTag extends StatelessWidget {
  const BannerDiscountTag(
    this.percent, {
    super.key,
    this.width = 36,
    this.height = 60,
  });

  final int percent;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: ShopIcon(
              ShopIcons.discountTag,
              color: Colors.white70,
              size: height,
            ),
          ),
          // « 50%\noff » dans le kit ; « -50% » tient dans la même
          // étiquette de 36 points, en une ligne.
          Text(
            '-$percent%',
            textAlign: TextAlign.center,
            style: ShopTextStyles.display(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// La mise en page commune des styles 2 à 5 : les textes à gauche, un
/// bouton à droite, centrés verticalement.
class _BannerRow extends StatelessWidget {
  const _BannerRow({required this.texts, required this.trailing});

  final List<Widget> texts;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ShopSizes.padding),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: texts,
            ),
          ),
          const SizedBox(width: ShopSizes.padding),
          trailing,
        ],
      ),
    );
  }
}

/// Style 1 : une phrase d'accroche et « Découvrir ».
class OfferBannerStyle1 extends StatelessWidget {
  const OfferBannerStyle1({
    super.key,
    required this.image,
    required this.text,
    this.callToAction = 'Découvrir',
    this.onTap,
  });

  final String? image;
  final String text;
  final String callToAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ShopBanner(
      image: image,
      onTap: onTap,
      children: [
        Padding(
          padding: const EdgeInsets.all(ShopSizes.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.75,
                child: Text(
                  text,
                  style: ShopTextStyles.display(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              BannerCallToAction(callToAction),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ],
    );
  }
}

/// Style 2 : titre et sous-titre, étiquette de remise en haut.
class OfferBannerStyle2 extends StatelessWidget {
  const OfferBannerStyle2({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    required this.discountPercent,
    this.size = ShopBannerSize.medium,
    this.onTap,
  });

  final String? image;
  final String title;
  final String? subtitle;
  final int discountPercent;
  final ShopBannerSize size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ShopBanner(
      image: image,
      size: size,
      onTap: onTap,
      children: [
        _BannerRow(
          texts: [
            BannerHeadline(title),
            const SizedBox(height: ShopSizes.padding / 4),
            if (subtitle != null)
              Text(
                subtitle!.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
          ],
          trailing: BannerArrowButton(onTap: onTap),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: BannerDiscountTag(
            discountPercent,
            height: size == ShopBannerSize.small ? 56 : 60,
          ),
        ),
      ],
    );
  }
}

/// Style 3 : l'étiquette « -50 % » au-dessus du titre.
class OfferBannerStyle3 extends StatelessWidget {
  const OfferBannerStyle3({
    super.key,
    required this.image,
    required this.title,
    required this.discountPercent,
    this.onTap,
  });

  final String? image;
  final String title;
  final int discountPercent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ShopBanner(
      image: image,
      onTap: onTap,
      children: [
        _BannerRow(
          texts: [
            BannerChip('-$discountPercent %'),
            const SizedBox(height: ShopSizes.padding / 2),
            BannerHeadline(title),
          ],
          trailing: BannerArrowButton(onTap: onTap),
        ),
      ],
    );
  }
}

/// Style 4 : étiquette, titre, et « JUSQU'À -80 % ».
class OfferBannerStyle4 extends StatelessWidget {
  const OfferBannerStyle4({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    required this.discountPercent,
    this.onTap,
  });

  final String? image;
  final String title;
  final String? subtitle;
  final int discountPercent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ShopBanner(
      image: image,
      onTap: onTap,
      children: [
        _BannerRow(
          texts: [
            if (subtitle != null) BannerChip(subtitle!),
            const SizedBox(height: ShopSizes.padding / 2),
            BannerHeadline(title),
            Text(
              'JUSQU\'À -$discountPercent %',
              style: ShopTextStyles.display(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          trailing: BannerArrowButton(onTap: onTap),
        ),
      ],
    );
  }
}

/// Style 5, petite bannière : étiquette, titre, mention, chevron blanc.
class OfferBannerStyle5 extends StatelessWidget {
  const OfferBannerStyle5({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    this.bottomText,
    this.onTap,
  });

  final String? image;
  final String title;
  final String? subtitle;
  final String? bottomText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ShopBanner(
      image: image,
      size: ShopBannerSize.small,
      onTap: onTap,
      children: [
        _BannerRow(
          texts: [
            if (subtitle != null) BannerChip(subtitle!),
            const SizedBox(height: ShopSizes.padding / 2),
            BannerHeadline(title),
            if (bottomText != null)
              Text(
                bottomText!,
                style: ShopTextStyles.display(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
          trailing: const ShopIcon(
            ShopIcons.miniRight,
            size: 28,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// La vente flash : une accroche et le temps qui reste, en cases floutées.
class CountdownBanner extends StatelessWidget {
  const CountdownBanner({
    super.key,
    required this.image,
    required this.text,
    required this.endsAt,
    this.onTap,
  });

  final String? image;
  final String text;
  final DateTime endsAt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ShopBanner(
      image: image,
      onTap: onTap,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: ShopTextStyles.display(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
            const SizedBox(height: ShopSizes.padding),
            CountdownBoxes(endsAt: endsAt),
          ],
        ),
      ],
    );
  }
}

/// La grande bannière (`BannerLStyle1` du kit) : le pourcentage en
/// relief, l'étiquette, le titre, « Découvrir ».
class OfferBannerLarge extends StatelessWidget {
  const OfferBannerLarge({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    required this.discountPercent,
    this.callToAction = 'Découvrir',
    this.onTap,
  });

  final String? image;
  final String title;
  final String? subtitle;
  final int discountPercent;
  final String callToAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final contour = ShopTextStyles.display(fontSize: 60, height: 1.2).copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white38,
      color: null,
    );
    return ShopBanner(
      image: image,
      size: ShopBannerSize.large,
      onTap: onTap,
      children: [
        Padding(
          padding: const EdgeInsets.all(ShopSizes.padding),
          child: Column(
            children: [
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Le chiffre plein décalé sur son propre contour : le
                  // relief du kit.
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text('$discountPercent', style: contour),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Text(
                          '$discountPercent',
                          style: ShopTextStyles.display(
                            fontSize: 60,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: ShopSizes.padding / 4),
                  Text('%', style: contour),
                ],
              ),
              if (subtitle != null) BannerChip(subtitle!, fontSize: 16),
              const SizedBox(height: ShopSizes.padding),
              BannerHeadline(title, fontSize: 31, textAlign: TextAlign.center),
              const Spacer(),
              Text(
                '${callToAction.toUpperCase()}  >',
                style: ShopTextStyles.display(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Les deux présentations du temps restant : cases floutées sur une
/// bannière, cases rouges cerclées à côté d'un titre de section.
enum CountdownStyle { blurred, outlined }

/// Heures, minutes, secondes jusqu'à [endsAt], rafraîchies chaque seconde.
class CountdownBoxes extends StatefulWidget {
  const CountdownBoxes({
    super.key,
    required this.endsAt,
    this.style = CountdownStyle.blurred,
  });

  final DateTime endsAt;
  final CountdownStyle style;

  @override
  State<CountdownBoxes> createState() => _CountdownBoxesState();
}

class _CountdownBoxesState extends State<CountdownBoxes> {
  Timer? _timer;

  Duration get _restant {
    final reste = widget.endsAt.difference(DateTime.now());
    return reste.isNegative ? Duration.zero : reste;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_restant == Duration.zero) _timer?.cancel();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reste = _restant;
    String deux(int n) => n.toString().padLeft(2, '0');
    final cases = [
      deux(reste.inHours),
      deux(reste.inMinutes.remainder(60)),
      deux(reste.inSeconds.remainder(60)),
    ];
    final floute = widget.style == CountdownStyle.blurred;
    return Semantics(
      label:
          'Se termine dans ${reste.inHours} h ${reste.inMinutes.remainder(60)} min',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < cases.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ShopSizes.padding / 4,
                ),
                child: floute
                    ? const ShopIcon(
                        ShopIcons.dot,
                        size: 8,
                        color: Colors.white,
                      )
                    : const Text(
                        ':',
                        style: TextStyle(color: ShopColors.error),
                      ),
              ),
            floute ? _CaseFloutee(cases[i]) : _CaseCerclee(cases[i]),
          ],
        ],
      ),
    );
  }
}

class _CaseFloutee extends StatelessWidget {
  const _CaseFloutee(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ShopSizes.radius / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 40,
          width: 40,
          color: Colors.white12,
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CaseCerclee extends StatelessWidget {
  const _CaseCerclee(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ShopColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(ShopSizes.radius / 2),
        border: Border.all(color: ShopColors.error.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: ShopColors.error),
      ),
    );
  }
}

/// Les points du carrousel : une barre plus haute pour la page courante.
class DotIndicator extends StatelessWidget {
  const DotIndicator({
    super.key,
    this.isActive = false,
    this.activeColor = ShopColors.primary,
    this.inactiveColor,
  });

  final bool isActive;
  final Color activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: ShopSizes.duration,
      height: isActive ? 12 : 4,
      width: 4,
      decoration: BoxDecoration(
        color: isActive
            ? activeColor
            : inactiveColor ?? ShopColors.primarySwatch.shade100,
        borderRadius: const BorderRadius.all(
          Radius.circular(ShopSizes.padding),
        ),
      ),
    );
  }
}

/// Le carrousel d'offres de l'accueil : défile seul toutes les 4 s.
class OffersCarousel extends StatefulWidget {
  const OffersCarousel({super.key, required this.banners});

  final List<Widget> banners;

  @override
  State<OffersCarousel> createState() => _OffersCarouselState();
}

class _OffersCarouselState extends State<OffersCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (widget.banners.length < 2 || !_controller.hasClients) return;
      final suivante = (_page + 1) % widget.banners.length;
      _controller.animateToPage(
        suivante,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: ShopBannerSize.medium.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) => widget.banners[index],
          ),
          if (widget.banners.length > 1)
            Padding(
              padding: const EdgeInsets.all(ShopSizes.padding),
              child: SizedBox(
                height: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.banners.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: ShopSizes.padding / 4,
                        ),
                        child: DotIndicator(
                          isActive: i == _page,
                          activeColor: Colors.white70,
                          inactiveColor: Colors.white54,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
