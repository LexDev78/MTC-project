@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/supplier_onboarding/domain/entities/supplier_kyc.dart';
import 'package:mtc_app/features/supplier_onboarding/presentation/controllers/kyc_review_controller.dart';
import 'package:mtc_app/features/supplier_onboarding/presentation/providers/supplier_kyc_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

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

  test(
    'approving the seeded submitted dossier (Artisanat Sikasso) marks the '
    'account and public profile verified together',
    () async {
      const supplierId = DemoIds.supplierArtisanatSikasso;
      // `supplier_kyc` has no anon-readable grant at all (private KYC
      // dossiers) — RLS requires an authenticated staff session even for
      // this first read, same as the real staff console always has one by
      // the time this screen is reachable (see BACKEND_MIGRATION_PROGRESS.md,
      // Lot 3/6).
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'admin1', password: 'password123');

      final kycBefore = await container
          .read(supplierKycRepositoryProvider)
          .getForSupplier(supplierId);
      expect(kycBefore.status, KycReviewStatus.submitted);

      final success = await container
          .read(kycReviewControllerProvider.notifier)
          .approve(
            kycId: kycBefore.id,
            supplierId: supplierId,
            staffId: DemoIds.staffAdmin,
          );
      expect(success, isTrue);

      final kycAfter = await container
          .read(supplierKycRepositoryProvider)
          .getForSupplier(supplierId);
      expect(kycAfter.status, KycReviewStatus.approved);
      expect(kycAfter.reviewedByStaffId, DemoIds.staffAdmin);

      final account = await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur2', password: 'password123')
          as SupplierTiersUser;
      expect(account.verificationStatus, VerificationStatus.verified);

      final profile = await container
          .read(supplierRepositoryProvider)
          .getById(supplierId);
      expect(profile.verificationStatus, VerificationStatus.verified);
    },
  );

  test(
    'rejecting a dossier records the reason on the account and public '
    'profile together, and the supplier can resubmit afterwards',
    () async {
      const supplierId = DemoIds.supplierArtisanatSikasso;
      // `supplier_kyc` has no anon-readable grant at all (private KYC
      // dossiers) — RLS requires an authenticated staff session even for
      // this first read, same as the real staff console always has one by
      // the time this screen is reachable (see BACKEND_MIGRATION_PROGRESS.md,
      // Lot 3/6).
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'agent1', password: 'password123');

      final kyc = await container
          .read(supplierKycRepositoryProvider)
          .getForSupplier(supplierId);

      final reviewController = container.read(
        kycReviewControllerProvider.notifier,
      );
      final rejected = await reviewController.reject(
        kycId: kyc.id,
        supplierId: supplierId,
        staffId: DemoIds.staffAgent,
        reason: 'NIF illisible sur le document fourni.',
      );
      expect(rejected, isTrue);

      final account = await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur2', password: 'password123')
          as SupplierTiersUser;
      expect(account.verificationStatus, VerificationStatus.rejected);

      final profile = await container
          .read(supplierRepositoryProvider)
          .getById(supplierId);
      expect(profile.verificationStatus, VerificationStatus.rejected);

      // The seeded Sikasso dossier already has its required documents, so
      // resubmitting after a rejection succeeds without touching them again.
      await container
          .read(supplierKycRepositoryProvider)
          .submit(supplierId: supplierId);

      final kycAfterResubmit = await container
          .read(supplierKycRepositoryProvider)
          .getForSupplier(supplierId);
      expect(kycAfterResubmit.status, KycReviewStatus.submitted);
      expect(kycAfterResubmit.rejectionReason, isNull);
    },
  );
}
