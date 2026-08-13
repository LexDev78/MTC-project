import 'dart:async';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/supplier_kyc.dart';
import '../../domain/kyc_requirements.dart' as kyc_requirements;

/// Holds every supplier's verification dossier in memory — one per
/// supplier, mutated in place through its review states (no history of past
/// submissions/rejections is kept). Swapping to Firebase later means
/// replacing this file only.
class InMemorySupplierKycDatasource {
  InMemorySupplierKycDatasource() {
    _dossiers.addAll(_seed());
  }

  final List<SupplierKyc> _dossiers = [];
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<List<SupplierKyc>> watchAll() {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changesController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map((_) => List<SupplierKyc>.unmodifiable(_dossiers));
  }

  SupplierKyc? findBySupplier(String supplierId) {
    for (final kyc in _dossiers) {
      if (kyc.supplierId == supplierId) return kyc;
    }
    return null;
  }

  SupplierKyc requireBySupplier(String supplierId) {
    return findBySupplier(supplierId) ??
        (throw NotFoundException(
          'Aucun dossier de vérification pour ce fournisseur : $supplierId',
        ));
  }

  SupplierKyc requireById(String kycId) {
    return _dossiers.firstWhere(
      (k) => k.id == kycId,
      orElse: () =>
          throw NotFoundException('Dossier de vérification introuvable : $kycId'),
    );
  }

  void _upsert(SupplierKyc kyc) {
    final index = _dossiers.indexWhere((k) => k.supplierId == kyc.supplierId);
    if (index == -1) {
      _dossiers.add(kyc);
    } else {
      _dossiers[index] = kyc;
    }
    _changesController.add(null);
  }

  void saveDraftCompany(
    String supplierId, {
    String? rccmNumber,
    String? taxId,
    String? legalRepresentativeName,
    String? registeredAddress,
  }) {
    final existing = findBySupplier(supplierId);
    final base = existing is SupplierKycCompany ? existing : null;
    _upsert(
      SupplierKyc.company(
        id: existing?.id ?? IdGenerator.next(),
        supplierId: supplierId,
        status: existing?.status ?? KycReviewStatus.draft,
        documents: existing?.documents ?? const [],
        createdAt: existing?.createdAt ?? DateTime.now(),
        submittedAt: existing?.submittedAt,
        reviewedAt: existing?.reviewedAt,
        reviewedByStaffId: existing?.reviewedByStaffId,
        rejectionReason: existing?.rejectionReason,
        rccmNumber: rccmNumber ?? base?.rccmNumber,
        taxId: taxId ?? base?.taxId,
        legalRepresentativeName:
            legalRepresentativeName ?? base?.legalRepresentativeName,
        registeredAddress: registeredAddress ?? base?.registeredAddress,
      ),
    );
  }

  void saveDraftIndividual(String supplierId) {
    if (findBySupplier(supplierId) != null) return;
    _upsert(
      SupplierKyc.individual(
        id: IdGenerator.next(),
        supplierId: supplierId,
        status: KycReviewStatus.draft,
        documents: const [],
        createdAt: DateTime.now(),
      ),
    );
  }

  void addDocument(
    String supplierId,
    SupplierDocumentType type,
    String filePath,
  ) {
    final existing = requireBySupplier(supplierId);
    final document = SupplierDocument(
      id: IdGenerator.next(),
      type: type,
      filePath: filePath,
      uploadedAt: DateTime.now(),
    );
    // Re-uploading a slot replaces it rather than accumulating duplicates.
    final documents = [
      ...existing.documents.where((d) => d.type != type),
      document,
    ];
    _upsert(existing.copyWith(documents: documents));
  }

  void removeDocument(String supplierId, String documentId) {
    final existing = requireBySupplier(supplierId);
    final documents = existing.documents
        .where((d) => d.id != documentId)
        .toList();
    _upsert(existing.copyWith(documents: documents));
  }

  void setConsent(String supplierId, String policyVersion) {
    final existing = requireBySupplier(supplierId);
    if (existing is! SupplierKycIndividual) {
      throw const ValidationException(
        'Le consentement de traitement des données ne concerne que les '
        'vendeurs individuels.',
      );
    }
    _upsert(
      existing.copyWith(
        consent: DataProcessingConsent(
          accepted: true,
          acceptedAt: DateTime.now(),
          policyVersion: policyVersion,
        ),
      ),
    );
  }

  void submit(String supplierId) {
    final existing = requireBySupplier(supplierId);
    if (!kyc_requirements.isComplete(existing)) {
      throw const ValidationException(
        'Complétez tous les documents requis avant de soumettre votre dossier.',
      );
    }
    _upsert(
      existing.copyWith(
        status: KycReviewStatus.submitted,
        submittedAt: DateTime.now(),
        rejectionReason: null,
      ),
    );
  }

  void startReview(String kycId, String staffId) {
    final existing = requireById(kycId);
    _upsert(
      existing.copyWith(
        status: KycReviewStatus.underReview,
        reviewedByStaffId: staffId,
      ),
    );
  }

  void approve(String kycId, String staffId) {
    final existing = requireById(kycId);
    _upsert(
      existing.copyWith(
        status: KycReviewStatus.approved,
        reviewedAt: DateTime.now(),
        reviewedByStaffId: staffId,
        rejectionReason: null,
      ),
    );
  }

  void reject(String kycId, String staffId, String reason) {
    final existing = requireById(kycId);
    _upsert(
      existing.copyWith(
        status: KycReviewStatus.rejected,
        reviewedAt: DateTime.now(),
        reviewedByStaffId: staffId,
        rejectionReason: reason,
      ),
    );
  }

  /// Keeps each seeded supplier tiers account (see
  /// `InMemoryAuthDatasource._seedDemoAccounts`) consistent with a dossier
  /// matching its `AppUser.verificationStatus` — so `verified`/`pending`
  /// accounts have something to show, and the staff review queue (Lot 3)
  /// has real content to work through without needing a fresh submission
  /// first. `supplierCoutureKayes` (unverified) deliberately gets no
  /// dossier — a fresh sign-up hasn't started one yet.
  List<SupplierKyc> _seed() {
    final now = DateTime.now();
    return [
      SupplierKyc.company(
        id: 'kyc-bogolan-bamako',
        supplierId: DemoIds.supplierBogolanBamako,
        status: KycReviewStatus.approved,
        documents: [
          SupplierDocument(
            id: 'doc-bogolan-rccm',
            type: SupplierDocumentType.rccmCertificate,
            filePath: 'seed://rccm-bogolan.jpg',
            uploadedAt: now.subtract(const Duration(days: 60)),
          ),
          SupplierDocument(
            id: 'doc-bogolan-manager-id',
            type: SupplierDocumentType.managerIdCard,
            filePath: 'seed://id-bogolan.jpg',
            uploadedAt: now.subtract(const Duration(days: 60)),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 61)),
        submittedAt: now.subtract(const Duration(days: 60)),
        reviewedAt: now.subtract(const Duration(days: 58)),
        reviewedByStaffId: DemoIds.staffAdmin,
        rccmNumber: 'MA.BKO.2022.B.0456',
        taxId: 'NIF-004521',
        legalRepresentativeName: 'Ibrahima Coulibaly',
        registeredAddress: 'Zone Industrielle, Bamako',
      ),
      SupplierKyc.company(
        id: 'kyc-artisanat-sikasso',
        supplierId: DemoIds.supplierArtisanatSikasso,
        status: KycReviewStatus.submitted,
        documents: [
          SupplierDocument(
            id: 'doc-sikasso-rccm',
            type: SupplierDocumentType.rccmCertificate,
            filePath: 'seed://rccm-sikasso.jpg',
            uploadedAt: now.subtract(const Duration(days: 2)),
          ),
          SupplierDocument(
            id: 'doc-sikasso-manager-id',
            type: SupplierDocumentType.managerIdCard,
            filePath: 'seed://id-sikasso.jpg',
            uploadedAt: now.subtract(const Duration(days: 2)),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 3)),
        submittedAt: now.subtract(const Duration(days: 2)),
        rccmNumber: 'MA.SIK.2026.B.0789',
        taxId: 'NIF-009873',
        legalRepresentativeName: 'Fatoumata Keita',
        registeredAddress: 'Marché Central, Sikasso',
      ),
      SupplierKyc.company(
        id: 'kyc-fruits-niono',
        supplierId: DemoIds.supplierFruitsNiono,
        status: KycReviewStatus.rejected,
        documents: [
          SupplierDocument(
            id: 'doc-niono-manager-id',
            type: SupplierDocumentType.managerIdCard,
            filePath: 'seed://id-niono.jpg',
            uploadedAt: now.subtract(const Duration(days: 5)),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 6)),
        submittedAt: now.subtract(const Duration(days: 5)),
        reviewedAt: now.subtract(const Duration(days: 4)),
        reviewedByStaffId: DemoIds.staffAgent,
        rejectionReason:
            'Le numéro RCCM fourni ne correspond à aucun enregistrement '
            'valide. Merci de soumettre un extrait RCCM lisible et à jour.',
        taxId: 'NIF-002211',
        legalRepresentativeName: 'Seydou Traoré',
        registeredAddress: 'Marché de Niono',
      ),
    ];
  }
}
