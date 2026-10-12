@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/supplier_onboarding/domain/entities/supplier_kyc.dart';
import 'package:mtc_app/features/supplier_onboarding/presentation/providers/supplier_kyc_providers.dart';

import '../../support/supabase_test_harness.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetAndSeed();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
      ],
    );
    addTearDown(container.dispose);
  });

  // `supplier_kyc` RLS scopes owner writes to the caller's own
  // `operating_supplier_id()` — a fresh, KYC-untouched account per test
  // (rather than reusing the seeded Artisanat Sikasso/Fruits Niono
  // fixtures, already exercised end-to-end by `kyc_review_flow_test.dart`/
  // `supplier_kyc_flow_test.dart`) keeps these narrower validation-rule
  // tests isolated from each other and from those fixtures' own state.
  Future<String> signUpCompany(String usernameOrPhone) async {
    final user = await container.read(authRepositoryProvider).signUpSupplierTiers(
      displayName: 'Testeur',
      usernameOrPhone: usernameOrPhone,
      phoneNumber: '+22300000000',
      password: 'password123',
      businessName: 'Entreprise Test',
      city: 'Bamako',
      legalType: SupplierLegalType.company,
    );
    return user.id;
  }

  Future<String> signUpIndividual(String usernameOrPhone) async {
    final user = await container.read(authRepositoryProvider).signUpSupplierTiers(
      displayName: 'Testeur',
      usernameOrPhone: usernameOrPhone,
      phoneNumber: '+22300000001',
      password: 'password123',
      businessName: 'Boutique Test',
      city: 'Bamako',
      legalType: SupplierLegalType.individual,
    );
    return user.id;
  }

  Future<void> loginAs(String usernameOrPhone) => container
      .read(authRepositoryProvider)
      .login(usernameOrPhone: usernameOrPhone, password: 'password123');

  group('company dossier', () {
    test('starts as an empty draft on first save', () async {
      final supplierId = await signUpCompany('kyctest1');
      final repository = container.read(supplierKycRepositoryProvider);

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
      final supplierId = await signUpCompany('kyctest2');
      final repository = container.read(supplierKycRepositoryProvider);

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
        final supplierId = await signUpCompany('kyctest3');
        final repository = container.read(supplierKycRepositoryProvider);
        await repository.saveDraftCompany(supplierId: supplierId);

        await expectLater(
          () => repository.submit(supplierId: supplierId),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'submit succeeds once the manager ID and RCCM certificate are uploaded',
      () async {
        final supplierId = await signUpCompany('kyctest4');
        final repository = container.read(supplierKycRepositoryProvider);
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
        final supplierId = await signUpCompany('kyctest5');
        final repository = container.read(supplierKycRepositoryProvider);
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
      final supplierId = await signUpCompany('kyctest6');
      final repository = container.read(supplierKycRepositoryProvider);
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
    Future<void> uploadAllIdDocuments(String supplierId) async {
      final repository = container.read(supplierKycRepositoryProvider);
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
      final supplierId = await signUpIndividual('kyctest7');
      final repository = container.read(supplierKycRepositoryProvider);
      await repository.saveDraftIndividual(supplierId: supplierId);
      await uploadAllIdDocuments(supplierId);

      await expectLater(
        () => repository.submit(supplierId: supplierId),
        throwsA(isA<ValidationException>()),
      );
    });

    test('submit succeeds once documents and consent are both present', () async {
      final supplierId = await signUpIndividual('kyctest8');
      final repository = container.read(supplierKycRepositoryProvider);
      await repository.saveDraftIndividual(supplierId: supplierId);
      await uploadAllIdDocuments(supplierId);
      await repository.setConsent(supplierId: supplierId, policyVersion: 'v1');

      await repository.submit(supplierId: supplierId);

      final kyc =
          await repository.getForSupplier(supplierId) as SupplierKycIndividual;
      expect(kyc.status, KycReviewStatus.submitted);
      expect(kyc.consent?.accepted, isTrue);
      expect(kyc.consent?.policyVersion, 'v1');
    });

    test('setConsent refuses a company dossier', () async {
      final companyId = await signUpCompany('kyctest9');
      final repository = container.read(supplierKycRepositoryProvider);
      await repository.saveDraftCompany(supplierId: companyId);

      await expectLater(
        () => repository.setConsent(supplierId: companyId, policyVersion: 'v1'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('staff review', () {
    Future<String> submitACompleteCompanyDossier(String usernameOrPhone) async {
      final supplierId = await signUpCompany(usernameOrPhone);
      final repository = container.read(supplierKycRepositoryProvider);
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
      return supplierId;
    }

    test('rejecting records a reason and lets the supplier resubmit', () async {
      final supplierId = await submitACompleteCompanyDossier('kyctest10');
      final repository = container.read(supplierKycRepositoryProvider);
      final kycId = (await repository.getForSupplier(supplierId)).id;

      await loginAs('admin1');
      await repository.review(
        kycId: kycId,
        approve: false,
        reason: 'Numéro RCCM illisible sur la photo.',
      );

      var kyc = await repository.getForSupplier(supplierId);
      expect(kyc.status, KycReviewStatus.rejected);
      expect(kyc.rejectionReason, 'Numéro RCCM illisible sur la photo.');

      await loginAs('kyctest10');
      await repository.submit(supplierId: supplierId);

      kyc = await repository.getForSupplier(supplierId);
      expect(kyc.status, KycReviewStatus.submitted);
      expect(kyc.rejectionReason, isNull);
    });

    test('approving clears any prior rejection reason', () async {
      final supplierId = await submitACompleteCompanyDossier('kyctest11');
      final repository = container.read(supplierKycRepositoryProvider);
      final kycId = (await repository.getForSupplier(supplierId)).id;

      await loginAs('admin1');
      await repository.startReview(kycId: kycId, staffId: DemoIds.staffAdmin);
      await repository.review(kycId: kycId, approve: true);

      final kyc = await repository.getForSupplier(supplierId);
      expect(kyc.status, KycReviewStatus.approved);
      expect(kyc.reviewedByStaffId, DemoIds.staffAdmin);
      expect(kyc.reviewedAt, isNotNull);
    });

    test('the review queue only surfaces submitted/under-review dossiers', () async {
      final draftId = await signUpCompany('kyctest12');
      await container
          .read(supplierKycRepositoryProvider)
          .saveDraftCompany(supplierId: draftId);

      final approvedId = await submitACompleteCompanyDossier('kyctest13');
      final approvedKycId =
          (await container.read(supplierKycRepositoryProvider).getForSupplier(approvedId)).id;
      await loginAs('admin1');
      await container
          .read(supplierKycRepositoryProvider)
          .review(kycId: approvedKycId, approve: true);

      final submittedId = await submitACompleteCompanyDossier('kyctest14');
      final submittedKycId =
          (await container.read(supplierKycRepositoryProvider).getForSupplier(submittedId)).id;

      await loginAs('admin1');
      final queue = await container.read(supplierKycRepositoryProvider).watchQueue().first;
      final queueIds = queue.map((k) => k.id).toSet();

      expect(queueIds.contains(submittedKycId), isTrue);
      expect(queueIds.contains(approvedKycId), isFalse);
      expect(queue.any((k) => k.supplierId == draftId), isFalse);
    });
  });
}
