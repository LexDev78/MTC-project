import '../../domain/entities/supplier_kyc.dart';
import '../../domain/repositories/supplier_kyc_repository.dart';
import '../datasources/in_memory_supplier_kyc_datasource.dart';

class InMemorySupplierKycRepository implements SupplierKycRepository {
  InMemorySupplierKycRepository(this._datasource);

  final InMemorySupplierKycDatasource _datasource;

  @override
  Stream<SupplierKyc?> watchForSupplier(String supplierId) {
    return _datasource.watchAll().map(
      (_) => _datasource.findBySupplier(supplierId),
    );
  }

  @override
  Future<SupplierKyc> getForSupplier(String supplierId) async =>
      _datasource.requireBySupplier(supplierId);

  @override
  Stream<List<SupplierKyc>> watchQueue({Set<KycReviewStatus>? statuses}) {
    final wanted =
        statuses ??
        const {KycReviewStatus.submitted, KycReviewStatus.underReview};
    return _datasource.watchAll().map(
      (dossiers) => dossiers.where((k) => wanted.contains(k.status)).toList(),
    );
  }

  @override
  Future<void> saveDraftCompany({
    required String supplierId,
    String? rccmNumber,
    String? taxId,
    String? legalRepresentativeName,
    String? registeredAddress,
  }) async {
    _datasource.saveDraftCompany(
      supplierId,
      rccmNumber: rccmNumber,
      taxId: taxId,
      legalRepresentativeName: legalRepresentativeName,
      registeredAddress: registeredAddress,
    );
  }

  @override
  Future<void> saveDraftIndividual({required String supplierId}) async {
    _datasource.saveDraftIndividual(supplierId);
  }

  @override
  Future<void> addDocument({
    required String supplierId,
    required SupplierDocumentType type,
    required String filePath,
  }) async {
    _datasource.addDocument(supplierId, type, filePath);
  }

  @override
  Future<void> removeDocument({
    required String supplierId,
    required String documentId,
  }) async {
    _datasource.removeDocument(supplierId, documentId);
  }

  @override
  Future<void> setConsent({
    required String supplierId,
    required String policyVersion,
  }) async {
    _datasource.setConsent(supplierId, policyVersion);
  }

  @override
  Future<void> submit({required String supplierId}) async {
    _datasource.submit(supplierId);
  }

  @override
  Future<void> startReview({
    required String kycId,
    required String staffId,
  }) async {
    _datasource.startReview(kycId, staffId);
  }

  @override
  Future<void> approve({required String kycId, required String staffId}) async {
    _datasource.approve(kycId, staffId);
  }

  @override
  Future<void> reject({
    required String kycId,
    required String staffId,
    required String reason,
  }) async {
    _datasource.reject(kycId, staffId, reason);
  }
}
