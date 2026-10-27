import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';

import '../../domain/entities/payment.dart';
import '../providers/checkout_providers.dart';

/// Ouvre la feuille de paiement Mobile Money pour [amountFcfa]. Rend `true`
/// une fois un opérateur choisi et le paiement simulé abouti (l'opérateur
/// est alors noté dans [mobileMoneyProviderChoiceProvider] pour
/// `CheckoutController`), `false` si la feuille est fermée sans payer.
///
/// Aucune passerelle réelle derrière : c'est la place qu'occupera Orange
/// Money ou Moov Money. Le statut « payé » d'une commande n'est de toute
/// façon posé que par MTC (`mark_order_paid`), jamais par l'app.
Future<bool> showMobileMoneyPaymentSheet(
  BuildContext context, {
  required int amountFcfa,
}) async {
  final result = await showShopSheet<bool>(
    context,
    heightFactor: 0.62,
    child: _MobileMoneyPaymentSheet(amountFcfa: amountFcfa),
  );
  return result ?? false;
}

enum _Step { pickProvider, processing, success }

class _MobileMoneyPaymentSheet extends ConsumerStatefulWidget {
  const _MobileMoneyPaymentSheet({required this.amountFcfa});

  final int amountFcfa;

  @override
  ConsumerState<_MobileMoneyPaymentSheet> createState() =>
      _MobileMoneyPaymentSheetState();
}

class _MobileMoneyPaymentSheetState
    extends ConsumerState<_MobileMoneyPaymentSheet> {
  _Step _step = _Step.pickProvider;

  /// L'opérateur choisi dans « Mode de paiement », déjà coché.
  late MobileMoneyProvider _selected = ref.read(preferredMobileMoneyProvider);

  Future<void> _pay() async {
    setState(() => _step = _Step.processing);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    ref.read(mobileMoneyProviderChoiceProvider.notifier).state = _selected;
    ref.read(preferredMobileMoneyProvider.notifier).state = _selected;
    setState(() => _step = _Step.success);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final montant = CurrencyFormatter.formatFcfa(widget.amountFcfa);
    return PopScope(
      canPop: _step != _Step.processing,
      child: Scaffold(
        body: switch (_step) {
          _Step.pickProvider => Column(
            children: [
              const SheetHeader(title: 'Mobile Money'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ShopSizes.screenMargin,
                  ),
                  children: [
                    Text('Montant', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: ShopSizes.padding / 4),
                    Text(montant, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: ShopSizes.padding * 1.5),
                    for (final operateur in MobileMoneyProvider.values) ...[
                      _Operateur(
                        operateur: operateur,
                        choisi: operateur == _selected,
                        onTap: () => setState(() => _selected = operateur),
                      ),
                      const SizedBox(height: ShopSizes.padding),
                    ],
                  ],
                ),
              ),
            ],
          ),
          _Step.processing => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: ShopColors.primary),
                const SizedBox(height: ShopSizes.padding * 1.5),
                Text('Paiement en cours…', style: theme.textTheme.titleSmall),
              ],
            ),
          ),
          _Step.success => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CheckMark(radius: 32),
                const SizedBox(height: ShopSizes.padding * 1.5),
                Text('Paiement effectué', style: theme.textTheme.headlineSmall),
                const SizedBox(height: ShopSizes.padding / 2),
                Text('$montant · ${_selected.label}'),
              ],
            ),
          ),
        },
        bottomNavigationBar: switch (_step) {
          _Step.pickProvider => BottomActionBar(
            label: 'Payer maintenant',
            onPressed: _pay,
          ),
          _Step.processing => null,
          _Step.success => BottomActionBar(
            label: 'Continuer',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        },
      ),
    );
  }
}

/// Un opérateur, cerclé de sa couleur quand il est choisi.
class _Operateur extends StatelessWidget {
  const _Operateur({
    required this.operateur,
    required this.choisi,
    required this.onTap,
  });

  final MobileMoneyProvider operateur;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleur = operateur == MobileMoneyProvider.orangeMoney
        ? const Color(0xFFFF6600)
        : const Color(0xFF0072CE);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ShopSizes.radius),
        child: Ink(
          padding: const EdgeInsets.all(ShopSizes.padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ShopSizes.radius),
            border: Border.all(
              color: choisi
                  ? couleur
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: choisi ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: couleur,
                child: const ShopIcon(
                  ShopIcons.payonline,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: ShopSizes.padding * 0.75),
              Expanded(
                child: Text(operateur.label, style: theme.textTheme.titleSmall),
              ),
              if (choisi)
                CheckMark(radius: 11, color: couleur)
              else
                const SizedBox.square(dimension: 22),
            ],
          ),
        ),
      ),
    );
  }
}
