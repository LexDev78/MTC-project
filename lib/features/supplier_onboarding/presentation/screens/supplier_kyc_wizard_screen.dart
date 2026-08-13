import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/validators.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/supplier_kyc.dart';
import '../controllers/supplier_kyc_controller.dart';
import '../providers/supplier_kyc_providers.dart';
import '../widgets/document_upload_tile.dart';

/// KYC wizard reached at `/supplier-tiers/onboarding` — the form differs
/// entirely by `SupplierLegalType` (see `_CompanyKycForm`/
/// `_IndividualKycForm`), but the legal type itself was already chosen at
/// sign-up (`SupplierLegalTypeScreen`), so this screen only ever renders the
/// one form that matches the signed-in supplier's account.
class SupplierKycWizardScreen extends ConsumerStatefulWidget {
  const SupplierKycWizardScreen({super.key});

  @override
  ConsumerState<SupplierKycWizardScreen> createState() =>
      _SupplierKycWizardScreenState();
}

class _SupplierKycWizardScreenState
    extends ConsumerState<SupplierKycWizardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user is! SupplierTiersUser) return;
      ref
          .read(supplierKycControllerProvider.notifier)
          .ensureDraftStarted(supplierId: user.id, legalType: user.legalType);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Vérification de votre compte')),
      body: user is! SupplierTiersUser
          ? const MtcLoadingView()
          : AsyncValueWidget(
              value: ref.watch(myKycProvider(user.id)),
              data: (kyc) => kyc == null
                  ? const MtcLoadingView()
                  : _WizardBody(supplierId: user.id, kyc: kyc),
            ),
    );
  }
}

class _WizardBody extends StatelessWidget {
  const _WizardBody({required this.supplierId, required this.kyc});

  final String supplierId;
  final SupplierKyc kyc;

  bool get _isLocked =>
      kyc.status == KycReviewStatus.submitted ||
      kyc.status == KycReviewStatus.underReview ||
      kyc.status == KycReviewStatus.approved;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusBanner(kyc: kyc),
          const SizedBox(height: AppSpacing.lg),
          if (_isLocked)
            _ReadOnlySummary(kyc: kyc)
          else
            switch (kyc) {
              SupplierKycCompany() => _CompanyKycForm(
                supplierId: supplierId,
                kyc: kyc as SupplierKycCompany,
              ),
              SupplierKycIndividual() => _IndividualKycForm(
                supplierId: supplierId,
                kyc: kyc as SupplierKycIndividual,
              ),
            },
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.kyc});

  final SupplierKyc kyc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color color, IconData icon, String text) = switch (kyc.status) {
      KycReviewStatus.draft => (
        scheme.onSurfaceVariant,
        Icons.edit_note_rounded,
        'Complétez votre dossier puis soumettez-le pour vérification.',
      ),
      KycReviewStatus.submitted || KycReviewStatus.underReview => (
        scheme.tertiary,
        Icons.hourglass_top_rounded,
        'Votre dossier est en cours de vérification par notre équipe.',
      ),
      KycReviewStatus.approved => (
        scheme.primary,
        Icons.verified_rounded,
        'Votre dossier est approuvé — votre compte est vérifié.',
      ),
      KycReviewStatus.rejected => (
        scheme.error,
        Icons.error_outline_rounded,
        kyc.rejectionReason == null
            ? 'Votre dossier a été refusé. Corrigez-le puis soumettez-le à nouveau.'
            : 'Dossier refusé : ${kyc.rejectionReason}',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlySummary extends StatelessWidget {
  const _ReadOnlySummary({required this.kyc});

  final SupplierKyc kyc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final document in kyc.documents)
          DocumentUploadTile(
            type: document.type,
            existing: document,
            onPicked: (_) {},
            onRemove: null,
          ),
      ],
    );
  }
}

class _CompanyKycForm extends ConsumerStatefulWidget {
  const _CompanyKycForm({required this.supplierId, required this.kyc});

  final String supplierId;
  final SupplierKycCompany kyc;

  @override
  ConsumerState<_CompanyKycForm> createState() => _CompanyKycFormState();
}

class _CompanyKycFormState extends ConsumerState<_CompanyKycForm> {
  final _formKey = GlobalKey<FormState>();
  late final _rccmController = TextEditingController(
    text: widget.kyc.rccmNumber,
  );
  late final _taxIdController = TextEditingController(text: widget.kyc.taxId);
  late final _repNameController = TextEditingController(
    text: widget.kyc.legalRepresentativeName,
  );
  late final _addressController = TextEditingController(
    text: widget.kyc.registeredAddress,
  );
  late SupplierDocumentType _proofType = widget.kyc.documents.any(
        (d) => d.type == SupplierDocumentType.entreprenantDeclaration,
      )
      ? SupplierDocumentType.entreprenantDeclaration
      : SupplierDocumentType.rccmCertificate;

  @override
  void dispose() {
    _rccmController.dispose();
    _taxIdController.dispose();
    _repNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  SupplierDocument? _documentOf(SupplierDocumentType type) {
    for (final document in widget.kyc.documents) {
      if (document.type == type) return document;
    }
    return null;
  }

  Future<void> _addDocument(SupplierDocumentType type, XFile file) async {
    await ref
        .read(supplierKycControllerProvider.notifier)
        .addDocument(supplierId: widget.supplierId, type: type, file: file);
  }

  Future<void> _removeDocument(String documentId) async {
    await ref
        .read(supplierKycControllerProvider.notifier)
        .removeDocument(supplierId: widget.supplierId, documentId: documentId);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(supplierKycControllerProvider.notifier);

    await controller.saveCompanyInfo(
      supplierId: widget.supplierId,
      rccmNumber: _rccmController.text.trim(),
      taxId: _taxIdController.text.trim(),
      legalRepresentativeName: _repNameController.text.trim(),
      registeredAddress: _addressController.text.trim(),
    );

    final success = await controller.submit(supplierId: widget.supplierId);
    if (!success && mounted) {
      final error = ref.read(supplierKycControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycState = ref.watch(supplierKycControllerProvider);
    final proofDocument = _documentOf(_proofType);
    final managerIdDocument = _documentOf(SupplierDocumentType.managerIdCard);
    final articlesDocument = _documentOf(
      SupplierDocumentType.articlesOfAssociation,
    );
    final addressDocument = _documentOf(SupplierDocumentType.proofOfAddress);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Informations de l'entreprise",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          MtcTextField(
            label: 'Numéro NIF (Identification Fiscale)',
            controller: _taxIdController,
            validator: Validators.required,
          ),
          const SizedBox(height: AppSpacing.md),
          MtcTextField(
            label: 'Nom du gérant / représentant légal',
            controller: _repNameController,
            validator: Validators.required,
          ),
          const SizedBox(height: AppSpacing.md),
          MtcTextField(
            label: 'Adresse du siège',
            controller: _addressController,
            validator: Validators.required,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Justificatif d\'immatriculation',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Un extrait RCCM classique, ou une déclaration de statut Entreprenant pour les petits opérateurs.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<SupplierDocumentType>(
            segments: const [
              ButtonSegment(
                value: SupplierDocumentType.rccmCertificate,
                label: Text('RCCM'),
              ),
              ButtonSegment(
                value: SupplierDocumentType.entreprenantDeclaration,
                label: Text('Entreprenant'),
              ),
            ],
            selected: {_proofType},
            onSelectionChanged: (selection) =>
                setState(() => _proofType = selection.first),
          ),
          if (_proofType == SupplierDocumentType.rccmCertificate)
            MtcTextField(
              label: 'Numéro RCCM',
              controller: _rccmController,
              validator: Validators.required,
            ),
          const SizedBox(height: AppSpacing.sm),
          DocumentUploadTile(
            key: ValueKey(_proofType),
            type: _proofType,
            existing: proofDocument,
            isRequired: true,
            onPicked: (file) => _addDocument(_proofType, file),
            onRemove: proofDocument == null
                ? null
                : () => _removeDocument(proofDocument.id),
          ),
          const SizedBox(height: AppSpacing.md),
          DocumentUploadTile(
            type: SupplierDocumentType.managerIdCard,
            existing: managerIdDocument,
            isRequired: true,
            onPicked: (file) =>
                _addDocument(SupplierDocumentType.managerIdCard, file),
            onRemove: managerIdDocument == null
                ? null
                : () => _removeDocument(managerIdDocument.id),
          ),
          const SizedBox(height: AppSpacing.md),
          DocumentUploadTile(
            type: SupplierDocumentType.articlesOfAssociation,
            existing: articlesDocument,
            onPicked: (file) =>
                _addDocument(SupplierDocumentType.articlesOfAssociation, file),
            onRemove: articlesDocument == null
                ? null
                : () => _removeDocument(articlesDocument.id),
          ),
          const SizedBox(height: AppSpacing.md),
          DocumentUploadTile(
            type: SupplierDocumentType.proofOfAddress,
            existing: addressDocument,
            onPicked: (file) =>
                _addDocument(SupplierDocumentType.proofOfAddress, file),
            onRemove: addressDocument == null
                ? null
                : () => _removeDocument(addressDocument.id),
          ),
          const SizedBox(height: AppSpacing.xl),
          MtcPrimaryButton(
            label: 'Soumettre mon dossier',
            isLoading: kycState.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _IndividualKycForm extends ConsumerWidget {
  const _IndividualKycForm({required this.supplierId, required this.kyc});

  final String supplierId;
  final SupplierKycIndividual kyc;

  SupplierDocument? _documentOf(SupplierDocumentType type) {
    for (final document in kyc.documents) {
      if (document.type == type) return document;
    }
    return null;
  }

  Future<void> _addDocument(
    WidgetRef ref,
    SupplierDocumentType type,
    XFile file,
  ) async {
    await ref
        .read(supplierKycControllerProvider.notifier)
        .addDocument(supplierId: supplierId, type: type, file: file);
  }

  Future<void> _removeDocument(WidgetRef ref, String documentId) async {
    await ref
        .read(supplierKycControllerProvider.notifier)
        .removeDocument(supplierId: supplierId, documentId: documentId);
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(supplierKycControllerProvider.notifier);
    final success = await controller.submit(supplierId: supplierId);
    if (!success && context.mounted) {
      final error = ref.read(supplierKycControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kycState = ref.watch(supplierKycControllerProvider);
    final frontDocument = _documentOf(SupplierDocumentType.nationalIdFront);
    final backDocument = _documentOf(SupplierDocumentType.nationalIdBack);
    final selfieDocument = _documentOf(SupplierDocumentType.selfieWithId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Pièce d'identité",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        DocumentUploadTile(
          type: SupplierDocumentType.nationalIdFront,
          existing: frontDocument,
          isRequired: true,
          onPicked: (file) =>
              _addDocument(ref, SupplierDocumentType.nationalIdFront, file),
          onRemove: frontDocument == null
              ? null
              : () => _removeDocument(ref, frontDocument.id),
        ),
        const SizedBox(height: AppSpacing.md),
        DocumentUploadTile(
          type: SupplierDocumentType.nationalIdBack,
          existing: backDocument,
          isRequired: true,
          onPicked: (file) =>
              _addDocument(ref, SupplierDocumentType.nationalIdBack, file),
          onRemove: backDocument == null
              ? null
              : () => _removeDocument(ref, backDocument.id),
        ),
        const SizedBox(height: AppSpacing.md),
        DocumentUploadTile(
          type: SupplierDocumentType.selfieWithId,
          existing: selfieDocument,
          isRequired: true,
          source: ImageSource.camera,
          onPicked: (file) =>
              _addDocument(ref, SupplierDocumentType.selfieWithId, file),
          onRemove: selfieDocument == null
              ? null
              : () => _removeDocument(ref, selfieDocument.id),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ConsentSection(supplierId: supplierId, consent: kyc.consent),
        const SizedBox(height: AppSpacing.xl),
        MtcPrimaryButton(
          label: 'Soumettre mon dossier',
          isLoading: kycState.isLoading,
          onPressed: () => _submit(context, ref),
        ),
      ],
    );
  }
}

class _ConsentSection extends ConsumerWidget {
  const _ConsentSection({required this.supplierId, required this.consent});

  final String supplierId;
  final DataProcessingConsent? consent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accepted = consent?.accepted ?? false;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consentement de traitement des données personnelles',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "En acceptant, vous autorisez Mali Trade Connect (MTC) à collecter et traiter votre pièce d'identité, "
            'votre selfie et vos informations de contact dans le seul but de vérifier votre identité en tant que '
            'vendeur individuel sur la plateforme, conformément à la loi n°2013-015 du 21 mai 2013 relative à la '
            "protection des données à caractère personnel et sous le contrôle de l'Autorité de Protection des "
            'Données à caractère Personnel (APDP) du Mali. Ces données sont conservées le temps nécessaire à la '
            'vérification de votre compte et ne sont partagées avec aucun tiers. Vous pouvez à tout moment demander '
            "l'accès, la rectification ou la suppression de vos données, ou retirer votre consentement, en "
            'contactant le support MTC.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: accepted,
            title: const Text("J'accepte le traitement de mes données personnelles"),
            onChanged: accepted
                ? null
                : (value) {
                    if (value == true) {
                      ref
                          .read(supplierKycControllerProvider.notifier)
                          .acceptConsent(supplierId: supplierId);
                    }
                  },
          ),
          if (accepted && consent != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Text(
                'Accepté le ${consent!.acceptedAt.day}/${consent!.acceptedAt.month}/${consent!.acceptedAt.year} (politique ${consent!.policyVersion})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
