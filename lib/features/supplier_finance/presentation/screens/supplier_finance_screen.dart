import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/payment.dart';
import 'package:mtc_app/features/orders/presentation/providers/supplier_order_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/core/error/user_message.dart';

import '../../domain/compute_financial_summary.dart';
import '../../domain/entities/payout_request.dart';
import '../../domain/entities/supplier_financial_summary.dart';
import '../controllers/supplier_finance_controller.dart';
import '../providers/supplier_finance_providers.dart';

/// "Finances" tab of `SupplierShell`. A fournisseur tiers sees their own
/// computed summary + payout history + a "Demander un retrait" action; the
/// fournisseur principal sees MTC's direct-sales performance instead
/// (commission always 0 — see `_PrincipalFinance`), plus, admin only, the
/// platform-wide payout queue and commission total.
class SupplierFinanceScreen extends ConsumerWidget {
  const SupplierFinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final supplierId = ref.watch(operatingSupplierIdProvider);

    if (user == null || supplierId == null) {
      return const Scaffold(body: MtcLoadingView());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Finances')),
      body: switch (user) {
        SupplierTiersUser() => _TiersFinance(supplierId: supplierId),
        SupplierPrincipalUser(:final staffRole) => _PrincipalFinance(
          supplierId: supplierId,
          staffRole: staffRole,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _TiersFinance extends ConsumerWidget {
  const _TiersFinance({required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(financialSummaryProvider(supplierId));
    final payoutsAsync = ref.watch(payoutRequestsProvider(supplierId));

    return AsyncValueWidget(
      value: summaryAsync,
      data: (summary) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SummaryCard(summary: summary),
          const SizedBox(height: AppSpacing.md),
          MtcPrimaryButton(
            label: 'Demander un retrait',
            onPressed: summary.availableFcfa <= 0
                ? null
                : () => _showRequestPayoutSheet(context, summary.availableFcfa),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Retraits', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AsyncValueWidget(
            value: payoutsAsync,
            data: (payouts) {
              if (payouts.isEmpty) {
                return Text(
                  'Aucun retrait demandé pour le moment.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                children: [for (final p in payouts) _PayoutTile(payout: p)],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRequestPayoutSheet(BuildContext context, int availableFcfa) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RequestPayoutSheet(availableFcfa: availableFcfa),
    );
  }
}

class _PrincipalFinance extends ConsumerWidget {
  const _PrincipalFinance({required this.supplierId, required this.staffRole});

  final String supplierId;
  final StaffRole staffRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(supplierOrdersProvider(supplierId));

    return AsyncValueWidget(
      value: ordersAsync,
      data: (views) {
        // MTC's own direct sales carry no platform commission — it isn't
        // selling to itself.
        final summary = computeFinancialSummary(
          supplierGroups: [for (final v in views) v.myGroup],
          commissionRatePercent: 0,
          payoutRequests: const [],
        );
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Ventes MTC directes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            _SummaryCard(summary: summary, showAvailable: false),
            if (staffRole == StaffRole.admin) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Administration',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              _PayoutQueueButton(),
              const SizedBox(height: AppSpacing.sm),
              _PlatformCommissionCard(),
            ],
          ],
        );
      },
    );
  }
}

class _PayoutQueueButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = (ref.watch(allPayoutRequestsProvider).valueOrNull ?? const [])
        .where((p) => !p.status.isTerminal)
        .length;
    return OutlinedButton.icon(
      onPressed: () => context.push(
        '${ref.read(supplierRoutePrefixProvider)}/finances/payouts',
      ),
      icon: const Icon(Icons.account_balance_wallet_outlined),
      label: Text(
        pending == 0 ? 'Retraits à valider' : 'Retraits à valider ($pending)',
      ),
    );
  }
}

class _PlatformCommissionCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commissionAsync = ref.watch(platformCommissionSummaryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Commissions plateforme (total)'),
            AsyncValueWidget(
              value: commissionAsync,
              data: (amount) => CurrencyText(
                amount,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, this.showAvailable = true});

  final SupplierFinancialSummary summary;
  final bool showAvailable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget row(String label, int amount, {bool emphasize = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            CurrencyText(
              amount,
              style: emphasize
                  ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    )
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            row('Ventes brutes', summary.grossFcfa),
            row('Commission plateforme', -summary.commissionFcfa),
            const Divider(),
            row('Net', summary.netFcfa),
            row('Déjà retiré', -summary.paidOutFcfa),
            if (showAvailable) ...[
              const Divider(),
              row('Disponible', summary.availableFcfa, emphasize: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout});

  final PayoutRequest payout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (payout.status) {
      PayoutStatus.paid => scheme.primary,
      PayoutStatus.rejected => scheme.error,
      PayoutStatus.processing => scheme.tertiary,
      PayoutStatus.requested => scheme.onSurfaceVariant,
    };

    return Card(
      child: ListTile(
        title: CurrencyText(payout.amountFcfa),
        subtitle: Text(
          '${payout.method.label} · ${payout.payoutDestination}'
          '${payout.rejectionReason != null ? '\n${payout.rejectionReason}' : ''}',
        ),
        isThreeLine: payout.rejectionReason != null,
        trailing: RoleBadge(label: payout.status.label, color: color),
      ),
    );
  }
}

class _RequestPayoutSheet extends ConsumerStatefulWidget {
  const _RequestPayoutSheet({required this.availableFcfa});

  final int availableFcfa;

  @override
  ConsumerState<_RequestPayoutSheet> createState() =>
      _RequestPayoutSheetState();
}

class _RequestPayoutSheetState extends ConsumerState<_RequestPayoutSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: widget.availableFcfa.toString(),
  );
  final _destinationController = TextEditingController();
  MobileMoneyProvider _method = MobileMoneyProvider.orangeMoney;

  @override
  void dispose() {
    _amountController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref
        .read(supplierFinanceControllerProvider.notifier)
        .requestPayout(
          amountFcfa: int.parse(_amountController.text.trim()),
          method: _method,
          payoutDestination: _destinationController.text.trim(),
        );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      final error = ref.read(supplierFinanceControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messagePourUtilisateur(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierFinanceControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Demander un retrait',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Solde disponible : ${widget.availableFcfa} FCFA',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            MtcTextField(
              label: 'Montant (FCFA)',
              controller: _amountController,
              keyboardType: TextInputType.number,
              validator: (value) {
                final amount = int.tryParse((value ?? '').trim());
                if (amount == null || amount <= 0) return 'Montant invalide';
                if (amount > widget.availableFcfa) return 'Solde insuffisant';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<MobileMoneyProvider>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Opérateur'),
              items: [
                for (final method in MobileMoneyProvider.values)
                  DropdownMenuItem(value: method, child: Text(method.label)),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            const SizedBox(height: AppSpacing.md),
            MtcTextField(
              label: 'Numéro de réception',
              controller: _destinationController,
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            MtcPrimaryButton(
              label: 'Envoyer la demande',
              isLoading: state.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
