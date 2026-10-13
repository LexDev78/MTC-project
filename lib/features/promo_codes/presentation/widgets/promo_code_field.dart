import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../providers/applied_promo_code_provider.dart';

/// La saisie d'un code promo, au paiement.
///
/// Un refus n'est pas une erreur : un code faux, expiré, déjà utilisé ou
/// sans effet sur ce panier est une réponse normale, et le motif vient du
/// serveur. On l'affiche tel quel plutôt que d'en inventer un — « ce code
/// n'améliore pas les remises déjà en cours » évite de chercher une panne
/// là où il n'y en a pas.
class PromoCodeField extends ConsumerStatefulWidget {
  const PromoCodeField({super.key});

  @override
  ConsumerState<PromoCodeField> createState() => _PromoCodeFieldState();
}

class _PromoCodeFieldState extends ConsumerState<PromoCodeField> {
  final _controller = TextEditingController();
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => _checking = true);
    ref.read(typedPromoCodeProvider.notifier).state = _controller.text;
    await ref.read(appliedPromoCodeProvider.notifier).apply(_controller.text);
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final applied = ref.watch(appliedPromoCodeProvider);

    // Un code accepté laisse place à son résultat : le champ n'a plus de
    // raison d'être, et le garder inviterait à en empiler un second.
    if (applied != null && applied.valid) {
      return Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.local_activity_rounded, color: scheme.onPrimaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Code ${applied.code} appliqué',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      '-${CurrencyFormatter.formatFcfa(applied.discountFcfa)}',
                      style: TextStyle(color: scheme.onPrimaryContainer),
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
        ),
      );
    }

    // Le bouton sous le champ, pleine largeur, et non à côté : le thème
    // donne à tout `OutlinedButton` une largeur minimale infinie
    // (`Size.fromHeight(56)`), donc un bouton posé en voisin d'un `Expanded`
    // réclame une largeur infinie et la disposition échoue. Vu en parcours
    // visuel — l'écran de paiement jetait une assertion de rendu.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MtcTextField(controller: _controller, label: 'Code promo'),
        if (applied != null && !applied.valid && applied.reason != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              applied.reason!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.error,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: _checking ? null : _apply,
          child: _checking
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Appliquer le code'),
        ),
      ],
    );
  }
}
