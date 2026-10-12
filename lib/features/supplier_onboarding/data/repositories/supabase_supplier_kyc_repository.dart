import 'package:mtc_app/core/error/exceptions.dart';

import '../../domain/entities/supplier_kyc.dart';
import '../../domain/kyc_requirements.dart' as kyc_requirements;
import '../../domain/repositories/supplier_kyc_repository.dart';
import '../datasources/supabase_supplier_kyc_datasource.dart';

class SupabaseSupplierKycRepository implements SupplierKycRepository {
  SupabaseSupplierKycRepository(this._datasource);

  final SupabaseSupplierKycDatasource _datasource;

  @override
  Stream<SupplierKyc?> watchForSupplier(String supplierId) {
    return _datasource
        .watchForSupplier(supplierId)
        .map((row) => row == null ? null : _fromRow(row));
  }

  @override
  Future<SupplierKyc> getForSupplier(String supplierId) async {
    return _fromRow(await _datasource.getForSupplier(supplierId));
  }

  @override
  Stream<List<SupplierKyc>> watchQueue({Set<KycReviewStatus>? statuses}) {
    final effective = statuses ?? const {KycReviewStatus.submitted, KycReviewStatus.underReview};
    final statusesDb = effective.map(_statusToDb).toList();
    return _datasource
        .watchQueue(statusesDb)
        .map((rows) => rows.map(_fromRow).toList());
  }

  @override
  Future<void> saveDraftCompany({
    required String supplierId,
    String? rccmNumber,
    String? taxId,
    String? legalRepresentativeName,
    String? registeredAddress,
  }) {
    return _datasource.saveDraftCompany(
      supplierId: supplierId,
      rccmNumber: rccmNumber,
      taxId: taxId,
      legalRepresentativeName: legalRepresentativeName,
      registeredAddress: registeredAddress,
    );
  }

  @override
  Future<void> saveDraftIndividual({required String supplierId}) {
    return _datasource.saveDraftIndividual(supplierId: supplierId);
  }

  @override
  Future<void> addDocument({
    required String supplierId,
    required SupplierDocumentType type,
    required String filePath,
  }) {
    return _datasource.addDocument(
      supplierId: supplierId,
      type: _docTypeToDb(type),
      filePath: filePath,
    );
  }

  @override
  Future<void> removeDocument({
    required String supplierId,
    required String documentId,
  }) {
    return _datasource.removeDocument(documentId: documentId);
  }

  @override
  Future<void> setConsent({
    required String supplierId,
    required String policyVersion,
  }) async {
    final existing = await getForSupplier(supplierId);
    if (existing is! SupplierKycIndividual) {
      throw const ValidationException(
        'Le consentement de traitement des données ne concerne que les '
        'vendeurs individuels.',
      );
    }
    await _datasource.setConsent(supplierId: supplierId, policyVersion: policyVersion);
  }

  @override
  Future<void> submit({required String supplierId}) async {
    final existing = await getForSupplier(supplierId);
    if (!kyc_requirements.isComplete(existing)) {
      throw const ValidationException(
        'Complétez tous les documents requis avant de soumettre votre dossier.',
      );
    }
    await _datasource.submit(supplierId: supplierId);
  }

  @override
  Future<void> startReview({required String kycId, required String staffId}) {
    return _datasource.startReview(kycId: kycId, staffId: staffId);
  }

  @override
  Future<void> review({
    required String kycId,
    required bool approve,
    String? reason,
  }) {
    return _datasource.review(kycId: kycId, approve: approve, reason: reason);
  }
}

SupplierKyc _fromRow(Map<String, dynamic> row) {
  final documents = (row['documents'] as List)
      .map((d) => SupplierDocument.fromJson(d as Map<String, dynamic>))
      .toList();
  final id = row['id'] as String;
  final supplierId = row['supplier_id'] as String;
  final status = _statusFromDb(row['status'] as String);
  final createdAt = DateTime.parse(row['created_at'] as String);
  final submittedAt = row['submitted_at'] == null
      ? null
      : DateTime.parse(row['submitted_at'] as String);
  final reviewedAt = row['reviewed_at'] == null
      ? null
      : DateTime.parse(row['reviewed_at'] as String);
  final reviewedByStaffId = row['reviewed_by_staff_id'] as String?;
  final rejectionReason = row['rejection_reason'] as String?;

  if (row['legal_type'] == 'company') {
    return SupplierKyc.company(
      id: id,
      supplierId: supplierId,
      status: status,
      documents: documents,
      createdAt: createdAt,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt,
      reviewedByStaffId: reviewedByStaffId,
      rejectionReason: rejectionReason,
      rccmNumber: row['rccm_number'] as String?,
      taxId: row['tax_id'] as String?,
      legalRepresentativeName: row['legal_representative_name'] as String?,
      registeredAddress: row['registered_address'] as String?,
    );
  }

  final consentAccepted = row['consent_accepted'] as bool?;
  return SupplierKyc.individual(
    id: id,
    supplierId: supplierId,
    status: status,
    documents: documents,
    createdAt: createdAt,
    submittedAt: submittedAt,
    reviewedAt: reviewedAt,
    reviewedByStaffId: reviewedByStaffId,
    rejectionReason: rejectionReason,
    consent: consentAccepted == null
        ? null
        : DataProcessingConsent(
            accepted: consentAccepted,
            acceptedAt: DateTime.parse(row['consent_accepted_at'] as String),
            policyVersion: row['consent_policy_version'] as String,
          ),
  );
}

KycReviewStatus _statusFromDb(String value) => switch (value) {
  'under_review' => KycReviewStatus.underReview,
  _ => KycReviewStatus.values.byName(value),
};

String _statusToDb(KycReviewStatus status) => switch (status) {
  KycReviewStatus.underReview => 'under_review',
  _ => status.name,
};

String _docTypeToDb(SupplierDocumentType type) => switch (type) {
  SupplierDocumentType.rccmCertificate => 'rccm_certificate',
  SupplierDocumentType.entreprenantDeclaration => 'entreprenant_declaration',
  SupplierDocumentType.articlesOfAssociation => 'articles_of_association',
  SupplierDocumentType.taxId => 'tax_id',
  SupplierDocumentType.managerIdCard => 'manager_id_card',
  SupplierDocumentType.proofOfAddress => 'proof_of_address',
  SupplierDocumentType.nationalIdFront => 'national_id_front',
  SupplierDocumentType.nationalIdBack => 'national_id_back',
  SupplierDocumentType.selfieWithId => 'selfie_with_id',
};
