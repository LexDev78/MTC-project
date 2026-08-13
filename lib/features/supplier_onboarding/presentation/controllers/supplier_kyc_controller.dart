import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/constants/app_constants.dart';
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

  Future<bool> addDocument({
    required String supplierId,
    required SupplierDocumentType type,
    required String filePath,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(supplierKycRepositoryProvider)
          .addDocument(supplierId: supplierId, type: type, filePath: filePath),
    );
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
