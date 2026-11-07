import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/supplier_kyc.dart';
import '../providers/supplier_kyc_providers.dart';

/// Staff-only queue of supplier dossiers awaiting a decision — reached from
/// the "Fournisseur principal" dashboard. Only `submitted`/`underReview`
/// dossiers show up here (see `SupplierKycRepository.watchQueue`'s default).
class KycReviewQueueScreen extends ConsumerWidget {
  const KycReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification des fournisseurs')),
      body: AsyncValueWidget(
        value: ref.watch(kycReviewQueueProvider),
        data: (queue) {
          if (queue.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Aucun dossier en attente',
              subtitle: 'Les nouveaux dossiers soumis apparaîtront ici.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: queue.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _QueueTile(kyc: queue[index]),
          );
        },
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({required this.kyc});

  final SupplierKyc kyc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCompany = kyc is SupplierKycCompany;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(
            isCompany ? Icons.apartment_outlined : Icons.badge_outlined,
            color: scheme.onPrimaryContainer,
          ),
        ),
        title: Text(isCompany ? 'Dossier société' : 'Dossier vendeur individuel'),
        subtitle: Text(
          '${kyc.documents.length} document(s) · Soumis ${DateFormatter.relative(kyc.submittedAt ?? kyc.createdAt)}',
        ),
        trailing: RoleBadge(
          label: kyc.status.label,
          color: kyc.status == KycReviewStatus.underReview
              ? scheme.tertiary
              : scheme.primary,
          icon: Icons.hourglass_top_rounded,
        ),
        onTap: () => context.push(
          AppRoutes.supplierPrincipalKycDetail(kyc.id),
          extra: kyc,
        ),
      ),
    );
  }
}
