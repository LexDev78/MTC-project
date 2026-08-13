import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/features/supplier_onboarding/data/datasources/in_memory_supplier_kyc_datasource.dart';
import 'package:mtc_app/features/supplier_onboarding/data/repositories/in_memory_supplier_kyc_repository.dart';
import 'package:mtc_app/features/supplier_onboarding/domain/entities/supplier_kyc.dart';

void main() {
  late InMemorySupplierKycRepository repository;

  setUp(() {
    repository = InMemorySupplierKycRepository(InMemorySupplierKycDatasource());
  });

  group('company dossier', () {
    const supplierId = 'supplier-test-company';

    test('starts as an empty draft on first save', () async {
      await repository.saveDraftCompany(
        supplierId: supplierId,
        rccmNumber: 'MA.BKO.2026.B.1234',
      );

      final kyc = await repository.getForSupplier(supplierId);
      expect(kyc, isA<SupplierKycCompany>());
      expect(kyc.status, KycReviewStatus.draft);
      expect((kyc as SupplierKycCompany).rccmNumber, 'MA.BKO.2026.B.1234');
      expect(kyc.documents, isEmpty);
    });

    test('a second draft save only overwrites the fields it passes', () async {
      await repository.saveDraftCompany(
        supplierId: supplierId,
        rccmNumber: 'MA.BKO.2026.B.1234',
        taxId: 'NIF-001',
      );
      await repository.saveDraftCompany(supplierId: supplierId, taxId: 'NIF-002');

      final kyc =
          await repository.getForSupplier(supplierId) as SupplierKycCompany;
      expect(kyc.rccmNumber, 'MA.BKO.2026.B.1234');
      expect(kyc.taxId, 'NIF-002');
    });

    test(
      'submit fails without the manager ID and a registration proof',
      () async {
        await repository.saveDraftCompany(supplierId: supplierId);

        expect(
          () => repository.submit(supplierId: supplierId),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'submit succeeds once the manager ID and RCCM certificate are uploaded',
      () async {
        await repository.saveDraftCompany(supplierId: supplierId);
        await repository.addDocument(
          supplierId: supplierId,
          type: SupplierDocumentType.managerIdCard,
          filePath: '/tmp/manager-id.jpg',
        );
        await repository.addDocument(
          supplierId: supplierId,
          type: SupplierDocumentType.rccmCertificate,
          filePath: '/tmp/rccm.jpg',
        );

        await repository.submit(supplierId: supplierId);

        final kyc = await repository.getForSupplier(supplierId);
        expect(kyc.status, KycReviewStatus.submitted);
        expect(kyc.submittedAt, isNotNull);
      },
    );

    test(
      'an Entreprenant declaration satisfies the registration-proof '
      'requirement just like an RCCM certificate',
      () async {
        await repository.saveDraftCompany(supplierId: supplierId);
        await repository.addDocument(
          supplierId: supplierId,
          type: SupplierDocumentType.managerIdCard,
          filePath: '/tmp/manager-id.jpg',
        );
        await repository.addDocument(
          supplierId: supplierId,
          type: SupplierDocumentType.entreprenantDeclaration,
          filePath: '/tmp/entreprenant.jpg',
        );

        await repository.submit(supplierId: supplierId);

        expect(
          (await repository.getForSupplier(supplierId)).status,
          KycReviewStatus.submitted,
        );
      },
    );

    test('re-uploading the same document type replaces it, not duplicates it', () async {
      await repository.saveDraftCompany(supplierId: supplierId);
      await repository.addDocument(
        supplierId: supplierId,
        type: SupplierDocumentType.managerIdCard,
        filePath: '/tmp/first.jpg',
      );
      await repository.addDocument(
        supplierId: supplierId,
        type: SupplierDocumentType.managerIdCard,
        filePath: '/tmp/second.jpg',
      );

      final kyc = await repository.getForSupplier(supplierId);
      expect(kyc.documents, hasLength(1));
      expect(kyc.documents.single.filePath, '/tmp/second.jpg');
    });
  });

  group('individual dossier', () {
    const supplierId = 'supplier-test-individual';

    Future<void> uploadAllIdDocuments() async {
      await repository.addDocument(
        supplierId: supplierId,
        type: SupplierDocumentType.nationalIdFront,
        filePath: '/tmp/front.jpg',
      );
      await repository.addDocument(
        supplierId: supplierId,
        type: SupplierDocumentType.nationalIdBack,
        filePath: '/tmp/back.jpg',
      );
      await repository.addDocument(
        supplierId: supplierId,
        type: SupplierDocumentType.selfieWithId,
        filePath: '/tmp/selfie.jpg',
      );
    }

    test('submit fails without APDP consent even with all documents', () async {
      await repository.saveDraftIndividual(supplierId: supplierId);
      await uploadAllIdDocuments();

      expect(
        () => repository.submit(supplierId: supplierId),
        throwsA(isA<ValidationException>()),
      );
    });

    test('submit succeeds once documents and consent are both present', () async {
      await repository.saveDraftIndividual(supplierId: supplierId);
      await uploadAllIdDocuments();
      await repository.setConsent(supplierId: supplierId, policyVersion: 'v1');

      await repository.submit(supplierId: supplierId);

      final kyc =
          await repository.getForSupplier(supplierId) as SupplierKycIndividual;
      expect(kyc.status, KycReviewStatus.submitted);
      expect(kyc.consent?.accepted, isTrue);
      expect(kyc.consent?.policyVersion, 'v1');
    });

    test('setConsent refuses a company dossier', () async {
      const companyId = 'supplier-test-company-consent';
      await repository.saveDraftCompany(supplierId: companyId);

      expect(
        () => repository.setConsent(supplierId: companyId, policyVersion: 'v1'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('staff review', () {
    const supplierId = 'supplier-test-review';

    Future<String> submitACompleteCompanyDossier() async {
      await repository.saveDraftCompany(supplierId: supplierId);
      await repository.addDocument(
        supplierId: supplierId,
        type: SupplierDocumentType.managerIdCard,
        filePath: '/tmp/manager-id.jpg',
      );
      await repository.addDocument(
        supplierId: supplierId,
        type: SupplierDocumentType.rccmCertificate,
        filePath: '/tmp/rccm.jpg',
      );
      await repository.submit(supplierId: supplierId);
      return (await repository.getForSupplier(supplierId)).id;
    }

    test('rejecting records a reason and lets the supplier resubmit', () async {
      final kycId = await submitACompleteCompanyDossier();

      await repository.reject(
        kycId: kycId,
        staffId: 'staff-1',
        reason: 'Numéro RCCM illisible sur la photo.',
      );

      var kyc = await repository.getForSupplier(supplierId);
      expect(kyc.status, KycReviewStatus.rejected);
      expect(kyc.rejectionReason, 'Numéro RCCM illisible sur la photo.');

      await repository.submit(supplierId: supplierId);

      kyc = await repository.getForSupplier(supplierId);
      expect(kyc.status, KycReviewStatus.submitted);
      expect(kyc.rejectionReason, isNull);
    });

    test('approving clears any prior rejection reason', () async {
      final kycId = await submitACompleteCompanyDossier();
      await repository.startReview(kycId: kycId, staffId: 'staff-1');

      await repository.approve(kycId: kycId, staffId: 'staff-1');

      final kyc = await repository.getForSupplier(supplierId);
      expect(kyc.status, KycReviewStatus.approved);
      expect(kyc.reviewedByStaffId, 'staff-1');
      expect(kyc.reviewedAt, isNotNull);
    });

    test('the review queue only surfaces submitted/under-review dossiers', () async {
      const draftId = 'supplier-test-queue-draft';
      const approvedId = 'supplier-test-queue-approved';
      await repository.saveDraftCompany(supplierId: draftId);
      final approvedKycId = await () async {
        await repository.saveDraftCompany(supplierId: approvedId);
        await repository.addDocument(
          supplierId: approvedId,
          type: SupplierDocumentType.managerIdCard,
          filePath: '/tmp/manager-id.jpg',
        );
        await repository.addDocument(
          supplierId: approvedId,
          type: SupplierDocumentType.rccmCertificate,
          filePath: '/tmp/rccm.jpg',
        );
        await repository.submit(supplierId: approvedId);
        final kyc = await repository.getForSupplier(approvedId);
        await repository.approve(kycId: kyc.id, staffId: 'staff-1');
        return kyc.id;
      }();
      final submittedKycId = await submitACompleteCompanyDossier();

      final queue = await repository.watchQueue().first;
      final queueIds = queue.map((k) => k.id).toSet();

      expect(queueIds.contains(submittedKycId), isTrue);
      expect(queueIds.contains(approvedKycId), isFalse);
      expect(queue.any((k) => k.supplierId == draftId), isFalse);
    });
  });
}
