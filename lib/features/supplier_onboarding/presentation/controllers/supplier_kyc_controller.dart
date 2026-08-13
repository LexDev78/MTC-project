import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/core/constants/app_constants.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/storage/image_upload.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';

import '../../domain/entities/supplier_kyc.dart';
import '../providers/supplier_kyc_providers.dart';

/// Drives the KYC wizard's form submissions. Exposes `AsyncValue<void>` so
/// the screen renders loading/error state the same way every other async
/// action in the app does (`AsyncValueWidget`/`.when`).
class SupplierKycController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Creates the dossier (empty, `draft`) on the supplier's very first visit
  /// to the wizard — a no-op if one already exists. Safe to call every time
  /// the screen opens.
  Future<void> ensureDraftStarted({
    required String supplierId,
    required SupplierLegalType legalType,
  }) async {
    final repository = ref.read(supplierKycRepositoryProvider);
    switch (legalType) {
      case SupplierLegalType.company:
        await repository.saveDraftCompany(supplierId: supplierId);
      case SupplierLegalType.individual:
        await repository.saveDraftIndividual(supplierId: supplierId);
    }
  }

  Future<bool> saveCompanyInfo({
    required String supplierId,
    String? rccmNumber,
    String? taxId,
    String? legalRepresentativeName,
    String? registeredAddress,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(supplierKycRepositoryProvider)
          .saveDraftCompany(
            supplierId: supplierId,
            rccmNumber: rccmNumber,
            taxId: taxId,
            legalRepresentativeName: legalRepresentativeName,
            registeredAddress: registeredAddress,
          ),
    );
    return !state.hasError;
  }

  /// Uploads [file] to the private `kyc-documents` bucket (own folder,
  /// enforced by Storage RLS) before recording it — [file] is still a raw
  /// local device path picked by `DocumentUploadTile`, never persisted as
  /// such.
  Future<bool> addDocument({
    required String supplierId,
    required SupplierDocumentType type,
    required XFile file,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final path = await uploadPickedImage(
        client: ref.read(supabaseClientProvider),
        bucket: 'kyc-documents',
        folder: supplierId,
        file: file,
      );
      await ref
          .read(supplierKycRepositoryProvider)
          .addDocument(supplierId: supplierId, type: type, filePath: path);
    });
    return !state.hasError;
  }

  Future<bool> removeDocument({
    required String supplierId,
    required String documentId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(supplierKycRepositoryProvider)
          .removeDocument(supplierId: supplierId, documentId: documentId),
    );
    return !state.hasError;
  }

  Future<bool> acceptConsent({required String supplierId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(supplierKycRepositoryProvider)
          .setConsent(
            supplierId: supplierId,
            policyVersion: AppConstants.currentDataProcessingPolicyVersion,
          ),
    );
    return !state.hasError;
  }

  Future<bool> submit({required String supplierId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(supplierKycRepositoryProvider).submit(supplierId: supplierId),
    );
    return !state.hasError;
  }
}

final supplierKycControllerProvider =
    AsyncNotifierProvider<SupplierKycController, void>(
      SupplierKycController.new,
    );
