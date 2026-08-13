import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

import '../providers/supplier_kyc_providers.dart';

/// Drives a staff member's approve/reject decision on a supplier's KYC
/// dossier. A decision touches four records — `SupplierKyc.status`,
/// `AppUser.verificationStatus`, `SupplierProfile.verificationStatus`,
/// `Product.isSupplierVerified` — so this controller is where that
/// cross-repository orchestration lives (mirroring `ReviewController.submit`,
/// which does the same thing across `ReviewRepository`/`SupplierRepository`/
/// `ProductRepository`).
class KycReviewController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> startReview({
    required String kycId,
    required String staffId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(supplierKycRepositoryProvider)
          .startReview(kycId: kycId, staffId: staffId),
    );
    return !state.hasError;
  }

  Future<bool> approve({
    required String kycId,
    required String supplierId,
    required String staffId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(supplierKycRepositoryProvider)
          .approve(kycId: kycId, staffId: staffId);
      await ref
          .read(authRepositoryProvider)
          .updateSupplierVerificationStatus(
            userId: supplierId,
            status: VerificationStatus.verified,
          );
      await ref
          .read(supplierRepositoryProvider)
          .updateVerificationStatus(
            supplierId: supplierId,
            status: VerificationStatus.verified,
          );
      await ref
          .read(productRepositoryProvider)
          .updateSupplierVerification(supplierId: supplierId, isVerified: true);
    });
    return !state.hasError;
  }

  Future<bool> reject({
    required String kycId,
    required String supplierId,
    required String staffId,
    required String reason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(supplierKycRepositoryProvider)
          .reject(kycId: kycId, staffId: staffId, reason: reason);
      await ref
          .read(authRepositoryProvider)
          .updateSupplierVerificationStatus(
            userId: supplierId,
            status: VerificationStatus.rejected,
          );
      await ref
          .read(supplierRepositoryProvider)
          .updateVerificationStatus(
            supplierId: supplierId,
            status: VerificationStatus.rejected,
          );
      await ref
          .read(productRepositoryProvider)
          .updateSupplierVerification(supplierId: supplierId, isVerified: false);
    });
    return !state.hasError;
  }
}

final kycReviewControllerProvider =
    AsyncNotifierProvider<KycReviewController, void>(KycReviewController.new);
