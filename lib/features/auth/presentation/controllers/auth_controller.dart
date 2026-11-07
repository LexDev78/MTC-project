import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/notifications/presentation/providers/push_providers.dart';

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

  Future<bool> signUpCourier({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
    required String city,
    String? vehicleLabel,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signUpCourier(
            displayName: displayName,
            usernameOrPhone: usernameOrPhone,
            phoneNumber: phoneNumber,
            password: password,
            city: city,
            vehicleLabel: vehicleLabel,
          ),
    );
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    return !state.hasError;
  }

  Future<void> logout() async {
    // Deletes this device's FCM token *before* signing out — deliberately
    // ordered: `device_tokens_delete_own`'s RLS needs `auth.uid()` to still
    // resolve, which it won't once `authRepositoryProvider.logout()` clears
    // the session. `DeviceTokenRepository.deleteToken` already swallows its
    // own failures (best-effort), so a missed cleanup here is at worst a
    // stale token — pruned server-side the next time FCM reports it dead —
    // never something that should block logout.
    //
    // Guarded on `Firebase.apps` the same way `pushRegistrationProvider`
    // is: `firebaseMessagingProvider` throws synchronously with no app
    // initialized, true both pre-Phase-3 and in every test that pumps
    // `MtcApp` without going through `bootstrap.dart`.
    if (Firebase.apps.isNotEmpty) {
      final token = await ref.read(firebaseMessagingProvider).getToken();
      if (token != null) {
        await ref.read(deviceTokenRepositoryProvider).deleteToken(token);
      }
    }
    await ref.read(authRepositoryProvider).logout();
  }

  /// Soft-deletes the signed-in account then signs out — see
  /// `AuthRepository.deleteAccount` for exactly what this blocks. Same
  /// `AsyncValue.guard` shape as `login`, so a screen reads `state.error`
  /// for the failure message (e.g. "vous avez des commandes en cours") the
  /// same way it already does everywhere else in this class.
  Future<bool> deleteAccount() async {
    // Same ordering rationale as `logout` above: the FCM token must be
    // deleted while `auth.uid()` still resolves, which it won't once the
    // repository call below signs this device out.
    if (Firebase.apps.isNotEmpty) {
      final token = await ref.read(firebaseMessagingProvider).getToken();
      if (token != null) {
        await ref.read(deviceTokenRepositoryProvider).deleteToken(token);
      }
    }

    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).deleteAccount(),
    );
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    return !state.hasError;
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
