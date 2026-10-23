import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';

import '../providers/applied_promo_code_provider.dart';

/// La saisie d'un code promo (« Your Coupon code » du kit) : un champ au
/// ticket, « Appliquer » au bout.
///
/// Un refus n'est pas une erreur : un code faux, expiré, déjà utilisé ou
/// sans effet sur ce panier est une réponse normale, et le motif vient du
/// serveur. On l'affiche tel quel plutôt que d'en inventer un — « ce code
/// n'améliore pas les remises déjà en cours » évite de chercher une panne
/// là où il n'y en a pas.
class PromoCodeField extends ConsumerStatefulWidget {
  const PromoCodeField({super.key, this.onBeforeApply});

  /// Juste avant la vérification : le panier y écarte un achat immédiat
  /// resté en attente, pour que le code porte bien sur le panier.
  final VoidCallback? onBeforeApply;

  @override
  ConsumerState<PromoCodeField> createState() => _PromoCodeFieldState();
}

class _PromoCodeFieldState extends ConsumerState<PromoCodeField> {
  late final _controller = TextEditingController(
    text: ref.read(typedPromoCodeProvider),
  );
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// `finally` et non une simple ligne après l'`await` : si la vérification
  /// échoue, le bouton doit redevenir cliquable. Sans cela il resterait figé
  /// sur son indicateur de chargement, et le client n'aurait plus aucun
  /// moyen de réessayer — l'écran paraîtrait bloqué.
  Future<void> _apply() async {
    widget.onBeforeApply?.call();
    setState(() => _checking = true);
    ref.read(typedPromoCodeProvider.notifier).state = _controller.text;
    try {
      await ref.read(appliedPromoCodeProvider.notifier).apply(_controller.text);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final applied = ref.watch(appliedPromoCodeProvider);

    // Un code accepté laisse place à son résultat : le champ n'a plus de
    // raison d'être, et le garder inviterait à en empiler un second.
    if (applied != null && applied.valid) {
      return Container(
        padding: const EdgeInsets.fromLTRB(
          ShopSizes.padding,
          ShopSizes.padding / 2,
          ShopSizes.padding / 2,
          ShopSizes.padding / 2,
        ),
        decoration: BoxDecoration(
          color: ShopColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(ShopSizes.radius),
        ),
        child: Row(
          children: [
            const ShopIcon(ShopIcons.coupon, color: ShopColors.success),
            const SizedBox(width: ShopSizes.padding * 0.75),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Code ${applied.code} appliqué',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    '-${CurrencyFormatter.formatFcfa(applied.discountFcfa)}',
                    style: const TextStyle(
                      color: ShopColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                _controller.clear();
                ref.read(appliedPromoCodeProvider.notifier).clear();
              },
              child: const Text('Retirer'),
            ),
          ],
        ),
      );
    }

    final refus = applied != null && !applied.valid ? applied.reason : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _checking ? null : _apply(),
          decoration: InputDecoration(
            hintText: 'Saisissez un code promo',
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ShopIcon(
                ShopIcons.coupon,
                color: theme.iconTheme.color?.withValues(alpha: 0.3),
              ),
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: ShopSizes.padding / 4),
              child: _checking
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: _apply,
                      child: const Text('Appliquer'),
                    ),
            ),
          ),
        ),
        if (refus != null)
          Padding(
            padding: const EdgeInsets.only(
              top: ShopSizes.padding / 2,
              left: ShopSizes.padding / 4,
            ),
            child: Text(
              refus,
              style: theme.textTheme.labelMedium?.copyWith(
                color: ShopColors.error,
              ),
            ),
          ),
      ],
    );
  }
}
