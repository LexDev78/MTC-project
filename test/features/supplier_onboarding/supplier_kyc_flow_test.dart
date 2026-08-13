@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/supplier_onboarding/domain/entities/supplier_kyc.dart';
import 'package:mtc_app/features/supplier_onboarding/presentation/controllers/supplier_kyc_controller.dart';
import 'package:mtc_app/features/supplier_onboarding/presentation/providers/supplier_kyc_providers.dart';

import '../../support/supabase_test_harness.dart';

/// `addDocument` now uploads the picked file to real Storage — needs an
/// `XFile` backed by an actual file on disk, not just a device path string.
Future<XFile> _fakeDocumentFile(String name) async {
  final file = File('${Directory.systemTemp.path}/$name');
  await file.writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);
  return XFile(file.path);
}

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

  // `supplier_kyc` has no anon-readable grant (private KYC dossiers) — any
  // test touching it, even read-only, needs a real session.
  Future<void> login(String usernameOrPhone) async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: usernameOrPhone, password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test(
    'a fresh individual (fournisseur libre) account has no dossier until it '
    'submits one, then moves from unverified-with-nothing to submitted',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur3', password: 'password123');
      final user =
          await container.read(currentUserProvider.future) as SupplierTiersUser;
      expect(user.legalType, SupplierLegalType.individual);
      expect(user.verificationStatus, VerificationStatus.unverified);

      final before = await container
          .read(supplierKycRepositoryProvider)
          .watchForSupplier(user.id)
          .first;
      expect(before, isNull);

      final controller = container.read(supplierKycControllerProvider.notifier);
      await controller.ensureDraftStarted(
        supplierId: user.id,
        legalType: user.legalType,
      );

      final draft = await container
          .read(supplierKycRepositoryProvider)
          .getForSupplier(user.id);
      expect(draft, isA<SupplierKycIndividual>());
      expect(draft.status, KycReviewStatus.draft);

      // Submitting incomplete fails.
      final prematureSubmit = await controller.submit(supplierId: user.id);
      expect(prematureSubmit, isFalse);

      await controller.addDocument(
        supplierId: user.id,
        type: SupplierDocumentType.nationalIdFront,
        file: await _fakeDocumentFile('front.jpg'),
      );
      await controller.addDocument(
        supplierId: user.id,
        type: SupplierDocumentType.nationalIdBack,
        file: await _fakeDocumentFile('back.jpg'),
      );
      await controller.addDocument(
        supplierId: user.id,
        type: SupplierDocumentType.selfieWithId,
        file: await _fakeDocumentFile('selfie.jpg'),
      );

      // Still missing consent.
      final stillMissingConsent = await controller.submit(supplierId: user.id);
      expect(stillMissingConsent, isFalse);

      await controller.acceptConsent(supplierId: user.id);
      final success = await controller.submit(supplierId: user.id);
      expect(success, isTrue);

      final after = await container
          .read(supplierKycRepositoryProvider)
          .getForSupplier(user.id);
      expect(after.status, KycReviewStatus.submitted);
      expect((after as SupplierKycIndividual).consent?.accepted, isTrue);
    },
  );

  test(
    'the seeded pending supplier (Artisanat Sikasso) already has a '
    'submitted dossier sitting in the staff review queue',
    () async {
      await login('admin1');
      final queue = await container
          .read(supplierKycRepositoryProvider)
          .watchQueue()
          .first;

      expect(
        queue.any((k) => k.supplierId == DemoIds.supplierArtisanatSikasso),
        isTrue,
      );
    },
  );

  test(
    'the seeded rejected supplier (Fruits Niono) can correct and resubmit '
    'its dossier',
    () async {
      const supplierId = DemoIds.supplierFruitsNiono;
      await login('fournisseur4');
      final repository = container.read(supplierKycRepositoryProvider);
      final rejected = await repository.getForSupplier(supplierId);
      expect(rejected.status, KycReviewStatus.rejected);
      expect(rejected.rejectionReason, isNotNull);

      final controller = container.read(supplierKycControllerProvider.notifier);
      await controller.addDocument(
        supplierId: supplierId,
        type: SupplierDocumentType.rccmCertificate,
        file: await _fakeDocumentFile('rccm-corrected.jpg'),
      );
      final success = await controller.submit(supplierId: supplierId);

      expect(success, isTrue);
      final resubmitted = await repository.getForSupplier(supplierId);
      expect(resubmitted.status, KycReviewStatus.submitted);
      expect(resubmitted.rejectionReason, isNull);
    },
  );
}
