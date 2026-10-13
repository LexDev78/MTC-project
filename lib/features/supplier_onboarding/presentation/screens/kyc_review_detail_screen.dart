import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/supplier_kyc.dart';
import '../controllers/kyc_review_controller.dart';
import '../widgets/kyc_document_viewer.dart';

/// One dossier's full detail for a staff reviewer, reached from
/// `KycReviewQueueScreen` (which passes the [SupplierKyc] via `extra` — it
/// already holds the full object, no need for a second fetch). Opening the
/// screen marks the dossier `underReview`, then the reviewer approves or
/// rejects it (rejection requires a reason, shown back to the supplier).
class KycReviewDetailScreen extends ConsumerStatefulWidget {
  const KycReviewDetailScreen({super.key, required this.kyc});

  final SupplierKyc kyc;

  @override
  ConsumerState<KycReviewDetailScreen> createState() =>
      _KycReviewDetailScreenState();
}

class _KycReviewDetailScreenState
    extends ConsumerState<KycReviewDetailScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.kyc.status == KycReviewStatus.submitted) {
      // L'agent n'est plus transmis : `start_kyc_review` (`0075`) prend
      // celui de la session, et refuse un dossier qui n'attend pas d'examen.
      Future.microtask(() {
        ref
            .read(kycReviewControllerProvider.notifier)
            .startReview(kycId: widget.kyc.id);
      });
    }
  }

  Future<String?> _promptRejectionReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motif du refus'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Expliquez ce qui doit être corrigé…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Rejeter le dossier'),
          ),
        ],
      ),
    );
  }

  /// L'identifiant de l'agent n'est plus transmis : `review_supplier_kyc`
  /// (`0069`) prend celui de la session, et refuse l'appel s'il ne s'agit
  /// pas du staff.
  Future<void> _approve() async {
    final success = await ref
        .read(kycReviewControllerProvider.notifier)
        .review(
          kycId: widget.kyc.id,
          supplierId: widget.kyc.supplierId,
          approve: true,
        );
    if (success && mounted) context.pop();
  }

  Future<void> _reject() async {
    final reason = await _promptRejectionReason();
    if (reason == null || reason.isEmpty || !mounted) return;
    final success = await ref
        .read(kycReviewControllerProvider.notifier)
        .review(
          kycId: widget.kyc.id,
          supplierId: widget.kyc.supplierId,
          approve: false,
          reason: reason,
        );
    if (success && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final kyc = widget.kyc;
    final reviewState = ref.watch(kycReviewControllerProvider);
    final isCompany = kyc is SupplierKycCompany;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompany ? 'Dossier société' : 'Dossier vendeur individuel'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (kyc is SupplierKycCompany) ..._companyFields(context, kyc),
          Text('Documents', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (kyc.documents.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Aucune pièce transmise.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          for (final document in kyc.documents)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: KycDocumentViewer(document: document),
            ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: reviewState.isLoading ? null : _reject,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Rejeter'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MtcPrimaryButton(
                  label: 'Approuver',
                  icon: Icons.check_rounded,
                  isLoading: reviewState.isLoading,
                  onPressed: _approve,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _companyFields(BuildContext context, SupplierKycCompany kyc) {
    final rows = <(String, String?)>[
      ('Numéro RCCM', kyc.rccmNumber),
      ('NIF', kyc.taxId),
      ('Représentant légal', kyc.legalRepresentativeName),
      ('Adresse du siège', kyc.registeredAddress),
    ];
    return [
      Text('Informations déclarées', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      for (final (label, value) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(child: Text(value?.isNotEmpty == true ? value! : '—')),
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }
}
