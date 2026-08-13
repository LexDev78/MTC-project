import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/catalog/domain/entities/product_category.dart'
    show SupplierType;
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

import '../../domain/entities/user_role.dart';
import '../providers/auth_providers.dart';

/// Drives login/sign-up form submissions. Exposes `AsyncValue<void>` so
/// screens render loading/error state the same way every other async action
/// in the app does (`AsyncValueWidget`/`.when`).
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> login({
    required String usernameOrPhone,
    required String password,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .login(usernameOrPhone: usernameOrPhone, password: password),
    );
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    return !state.hasError;
  }

  Future<bool> signUpClient({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signUpClient(
            displayName: displayName,
            usernameOrPhone: usernameOrPhone,
            phoneNumber: phoneNumber,
            password: password,
          ),
    );
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    return !state.hasError;
  }

  Future<bool> signUpSupplierTiers({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
    required String businessName,
    required String city,
    required SupplierLegalType legalType,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .signUpSupplierTiers(
            displayName: displayName,
            usernameOrPhone: usernameOrPhone,
            phoneNumber: phoneNumber,
            password: password,
            businessName: businessName,
            city: city,
            legalType: legalType,
          );
      // Cross-repository orchestration lives here, in the controller — never
      // inside a `data/` repository (see `ReviewController` for the same
      // pattern). The public storefront card is a separate entity from the
      // auth account, so it needs to be created explicitly.
      await ref
          .read(supplierRepositoryProvider)
          .createProfile(
            id: user.id,
            businessName: businessName,
            supplierType: SupplierType.tiers,
            city: city,
            legalType: legalType,
          );
    });
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    return !state.hasError;
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
