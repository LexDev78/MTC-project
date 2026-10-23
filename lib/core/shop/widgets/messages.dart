import 'package:flutter/material.dart';

import '../shop_illustrations.dart';
import '../shop_tokens.dart';

/// L'écran illustré du kit : un dessin, un titre, une phrase — pour un
/// vide, une recherche sans résultat, une commande passée, une erreur.
///
/// Le sous-titre dit quoi faire ensuite, ou pourquoi c'est vide : une
/// liste vide sans explication se lit comme une panne.
class IllustratedMessage extends StatelessWidget {
  const IllustratedMessage({
    super.key,
    required this.illustration,
    required this.title,
    this.message,
    this.action,
    this.footer,
    this.alignStart = false,
    this.compact = false,
  });

  final ShopIllustration illustration;
  final String title;
  final String? message;

  /// Un bouton sous le message (« Réessayer »).
  final Widget? action;

  /// Les boutons d'une feuille de confirmation (« Continuer mes achats »,
  /// « Commander »), plus bas que le texte : la mise en page de
  /// `AddedToCartMessageScreen` du kit.
  final Widget? footer;

  /// Titre et texte alignés à gauche (« Merci pour votre commande »).
  final bool alignStart;

  /// À l'intérieur d'une page qui défile : pas de `Spacer`, des marges.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignement = alignStart ? TextAlign.start : TextAlign.center;
    final hauteur = MediaQuery.sizeOf(context).height * (compact ? 0.22 : 0.3);
    final textes = Column(
      crossAxisAlignment: alignStart
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: alignement,
          style: theme.textTheme.headlineSmall,
        ),
        if (message != null) ...[
          const SizedBox(height: ShopSizes.padding / 2),
          Text(
            message!,
            textAlign: alignement,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodyMedium?.color,
              height: 1.4,
            ),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: ShopSizes.padding * 1.5),
          action!,
        ],
      ],
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(ShopSizes.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShopIllustrationImage(illustration, height: hauteur),
            const SizedBox(height: ShopSizes.padding * 2),
            textes,
          ],
        ),
      );
    }
    if (footer != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: ShopSizes.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            ShopIllustrationImage(illustration, height: hauteur),
            const Spacer(flex: 2),
            textes,
            const Spacer(flex: 2),
            footer!,
            const Spacer(),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShopSizes.screenMargin),
      child: Column(
        children: [
          const Spacer(),
          ShopIllustrationImage(illustration, height: hauteur),
          const Spacer(),
          textes,
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
