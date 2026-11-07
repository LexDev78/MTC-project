import 'package:flutter/material.dart';

import '../shop_tokens.dart';

/// Une rubrique de feuille d'information (maquette « Product details » du
/// kit) : un titre, puis son texte en gris, aux marges de 32.
class DetailSection extends StatelessWidget {
  const DetailSection({super.key, required this.title, required this.child});

  final String title;

  /// Un texte, une [BulletList], des lignes « Clé : valeur ».
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShopSizes.screenMargin,
        vertical: ShopSizes.padding * 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: ShopSizes.padding / 2),
          DefaultTextStyle.merge(
            style: const TextStyle(height: 1.4),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Les rubriques d'une feuille, séparées par un trait aux mêmes marges.
class DetailSections extends StatelessWidget {
  const DetailSections({super.key, required this.sections});

  final List<DetailSection> sections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              indent: ShopSizes.screenMargin,
              endIndent: ShopSizes.screenMargin,
            ),
          sections[i],
        ],
      ],
    );
  }
}

/// Une liste à puces, en retrait de la rubrique.
class BulletList extends StatelessWidget {
  const BulletList(this.items, {super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final puce = DefaultTextStyle.of(context).style.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 21,
                height: 20,
                child: Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: puce,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Expanded(child: Text(item)),
            ],
          ),
      ],
    );
  }
}
