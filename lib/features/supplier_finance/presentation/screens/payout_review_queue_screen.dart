import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

import '../../domain/entities/payout_request.dart';
import '../controllers/supplier_finance_controller.dart';
import '../providers/supplier_finance_providers.dart';

/// Staff-only, admin-only queue of every supplier's pending payout
/// requests — reached from the "Finances" tab's admin section (see
/// `_PayoutQueueButton`). No route guard: per the plan, agent/admin
/// permissions are simple `if (staffRole == admin)` checks inside the
/// screens that need them, not a new permissions abstraction — this
/// screen re-checks on its own in case it's ever reached directly.
class PayoutReviewQueueScreen extends ConsumerWidget {
  const PayoutReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = user is SupplierPrincipalUser && user.staffRole == StaffRole.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('Retraits à valider')),
      body: !isAdmin
          ? const MtcEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Réservé aux administrateurs',
            )
          : AsyncValueWidget(
              value: ref.watch(allPayoutRequestsProvider),
              data: (payouts) {
                final pending = payouts.where((p) => !p.status.isTerminal).toList();
                if (pending.isEmpty) {
                  return const MtcEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Aucun retrait en attente',
                    subtitle: 'Les nouvelles demandes apparaîtront ici.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: pending.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _PayoutReviewTile(payout: pending[index]),
                );
              },
            ),
    );
  }
}

class _PayoutReviewTile extends ConsumerWidget {
  const _PayoutReviewTile({required this.payout});

  final PayoutRequest payout;

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rejeter ce retrait ?'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Motif'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    await ref
        .read(supplierFinanceControllerProvider.notifier)
        .reviewPayout(
          payoutId: payout.id,
          status: PayoutStatus.rejected,
          rejectionReason: reason.isEmpty ? 'Non précisé' : reason,
        );
  }

  Future<void> _advance(WidgetRef ref, PayoutStatus next) async {
    await ref
        .read(supplierFinanceControllerProvider.notifier)
        .reviewPayout(payoutId: payout.id, status: next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final supplierAsync = ref.watch(supplierDetailProvider(payout.supplierId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    supplierAsync.valueOrNull?.businessName ?? payout.supplierId,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                RoleBadge(label: payout.status.label, color: scheme.tertiary),
              ],
            ),
            const SizedBox(height: 4),
            CurrencyText(
              payout.amountFcfa,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${payout.method.label} · ${payout.payoutDestination}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text(
              'Demandé ${DateFormatter.relative(payout.requestedAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: AppSpacing.xs,
              children: [
                TextButton(
                  onPressed: () => _reject(context, ref),
                  child: const Text('Rejeter'),
                ),
                FilledButton(
                  onPressed: () => _advance(
                    ref,
                    payout.status == PayoutStatus.requested
                        ? PayoutStatus.processing
                        : PayoutStatus.paid,
                  ),
                  child: Text(
                    payout.status == PayoutStatus.requested
                        ? 'Traiter'
                        : 'Marquer payé',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
