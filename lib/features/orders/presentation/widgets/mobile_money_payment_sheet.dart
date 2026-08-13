import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/payment.dart';
import '../providers/checkout_providers.dart';

/// Opens the mocked Mobile Money payment sheet for [amountFcfa]. Resolves
/// to `true` once the client picks a provider and the simulated payment
/// completes (and records the provider in [mobileMoneyProviderChoiceProvider]
/// for [CheckoutController] to read), or `false`/`null` if dismissed
/// without paying — there's no real payment gateway behind this, it's a UI
/// stand-in for Orange Money / Moov Money.
Future<bool> showMobileMoneyPaymentSheet(
  BuildContext context, {
  required int amountFcfa,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
    ),
    builder: (context) => _MobileMoneyPaymentSheet(amountFcfa: amountFcfa),
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
  MobileMoneyProvider? _selected;

  Future<void> _pay() async {
    if (_selected == null) return;
    setState(() => _step = _Step.processing);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    ref.read(mobileMoneyProviderChoiceProvider.notifier).state = _selected;
    setState(() => _step = _Step.success);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step != _Step.processing,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: switch (_step) {
            _Step.pickProvider => _pickProviderContent(),
            _Step.processing => _processingContent(),
            _Step.success => _successContent(),
          },
        ),
      ),
    );
  }

  List<Widget> _pickProviderContent() {
    return [
      Text('Payer avec Mobile Money', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.xs),
      CurrencyText(
        widget.amountFcfa,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: AppSpacing.lg),
      for (final provider in MobileMoneyProvider.values)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _ProviderTile(
            provider: provider,
            selected: _selected == provider,
            onTap: () => setState(() => _selected = provider),
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      MtcPrimaryButton(
        label: 'Payer maintenant',
        onPressed: _selected == null ? null : _pay,
      ),
    ];
  }

  List<Widget> _processingContent() {
    return [
      const SizedBox(height: AppSpacing.xl),
      const Center(child: CircularProgressIndicator()),
      const SizedBox(height: AppSpacing.lg),
      Text(
        'Traitement du paiement...',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppSpacing.xl),
    ];
  }

  List<Widget> _successContent() {
    final scheme = Theme.of(context).colorScheme;
    return [
      const SizedBox(height: AppSpacing.md),
      Icon(Icons.check_circle_rounded, color: scheme.primary, size: 64),
      const SizedBox(height: AppSpacing.md),
      Text(
        'Paiement effectué',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: AppSpacing.xs),
      CurrencyText(
        widget.amountFcfa,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppSpacing.lg),
      MtcPrimaryButton(
        label: 'Continuer',
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ];
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final MobileMoneyProvider provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brandColor = provider == MobileMoneyProvider.orangeMoney
        ? const Color(0xFFFF6600)
        : const Color(0xFF0072CE);

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? brandColor : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: brandColor,
              child: const Icon(
                Icons.phone_iphone_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                provider.label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? brandColor : scheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}
