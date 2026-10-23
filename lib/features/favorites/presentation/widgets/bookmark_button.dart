import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';

import '../controllers/favorite_controller.dart';
import '../providers/favorite_providers.dart';

/// Le signet du kit, en haut de la fiche produit : met l'article dans les
/// favoris, ou l'en retire. Plein et violet quand il y est.
class BookmarkButton extends ConsumerWidget {
  const BookmarkButton({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enregistre = ref.watch(isFavoriteProvider(productId));

    return IconButton(
      tooltip: enregistre ? 'Retirer des favoris' : 'Ajouter aux favoris',
      onPressed: () async {
        await ref.read(favoriteControllerProvider.notifier).toggle(productId);
        final erreur = ref.read(favoriteControllerProvider).error;
        if (erreur == null || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              messagePourUtilisateur(
                erreur,
                repli: 'Les favoris n\'ont pas pu être mis à jour.',
              ),
            ),
          ),
        );
      },
      icon: ShopIcon(
        enregistre ? ShopIcons.bookmarkFilled : ShopIcons.bookmark,
        color: enregistre ? ShopColors.primary : null,
      ),
    );
  }
}
