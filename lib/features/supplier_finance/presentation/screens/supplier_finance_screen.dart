import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/payment.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/core/error/user_message.dart';

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
      // Le grand livre se relit à chaque commande ou retrait qui bouge : on
      // garde le chiffre affiché pendant ce temps plutôt que de vider la page.
      skipLoadingOnReload: true,
      data: (summary) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SummaryCard(summary: summary),
          const SizedBox(height: AppSpacing.sm),
          // La règle, dite une fois : sans elle, « encaissé par vous » qui
          // ne s'ajoute pas au disponible ressemble à une erreur de calcul.
          Text(
            'Seul l\'argent reçu par MTC se retire : un paiement en ligne '
            'confirmé, ou un paiement à la livraison encaissé par un livreur '
            'MTC. Ce que vous encaissez vous-même en livrant reste chez vous ; '
            'sa commission est déduite ici.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
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
    // Le grand livre de la boutique MTC : le serveur n'y prend aucune
    // commission — MTC ne se vend pas à lui-même.
    final summaryAsync = ref.watch(financialSummaryProvider(supplierId));

    return AsyncValueWidget(
      value: summaryAsync,
      skipLoadingOnReload: true,
      data: (summary) {
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // `detail` : une ligne qui décompose celle du dessus, en retrait et en
    // plus discret — elle explique le chiffre, elle ne s'y ajoute pas.
    Widget row(
      String label,
      int amount, {
      bool emphasize = false,
      bool detail = false,
      Color? color,
    }) {
      final style = emphasize
          ? theme.textTheme.titleMedium?.copyWith(
              color: color ?? scheme.primary,
              fontWeight: FontWeight.w700,
            )
          : detail
          ? theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)
          : theme.textTheme.bodyMedium;
      return Padding(
        padding: EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
          left: detail ? AppSpacing.md : 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(label, style: detail ? style : null)),
            const SizedBox(width: AppSpacing.sm),
            CurrencyText(amount, style: style),
          ],
        ),
      );
    }

    final taux = summary.commissionRatePercent;
    final libelleTaux = taux == taux.roundToDouble()
        ? taux.toStringAsFixed(0)
        : taux.toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row('Ventes brutes', summary.grossFcfa),
            row('Encaissé par MTC', summary.collectedByMtcFcfa, detail: true),
            if (summary.collectedBySupplierFcfa > 0)
              row(
                'Encaissé par vous',
                summary.collectedBySupplierFcfa,
                detail: true,
              ),
            if (summary.awaitingPaymentFcfa > 0)
              row(
                'Paiement en ligne à confirmer',
                summary.awaitingPaymentFcfa,
                detail: true,
              ),
            // MTC ne se prend rien sur ses propres ventes : la ligne n'a
            // alors rien à dire.
            if (taux > 0)
              row('Commission MTC ($libelleTaux %)', -summary.commissionFcfa),
            if (showAvailable) ...[
              const Divider(),
              row('Dû par MTC', summary.netFcfa),
              row('Déjà retiré', -summary.paidOutFcfa),
              const Divider(),
              // Un solde négatif n'est pas un « disponible » de −2 500 : c'est
              // une commission que la boutique doit encore.
              if (summary.owedToMtcFcfa > 0)
                row(
                  'Commission à régler à MTC',
                  summary.owedToMtcFcfa,
                  emphasize: true,
                  color: scheme.error,
                )
              else
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
