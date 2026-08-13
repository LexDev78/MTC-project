import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final result = await AsyncValue.guard(
      // The public storefront card used to be created here as a separate
      // step (`SupplierRepository.createProfile`) — now redundant:
      // `handle_new_user()` (Postgres trigger on `auth.users`,
      // `supabase/migrations/0001_initial_schema.sql`) creates the
      // matching `suppliers` row atomically in the same transaction as
      // the account itself. Calling `createProfile` here too would try to
      // insert a second row with the same id and fail.
      () => ref
          .read(authRepositoryProvider)
          .signUpSupplierTiers(
            displayName: displayName,
            usernameOrPhone: usernameOrPhone,
            phoneNumber: phoneNumber,
            password: password,
            businessName: businessName,
            city: city,
            legalType: legalType,
          ),
    );
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
