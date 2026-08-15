import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around `SupabaseClient.auth` + the raw `profiles`/`suppliers`
/// rows an account needs — no `AppUser` knowledge here (see
/// `SupabaseAuthRepository`, which hydrates the domain entity and translates
/// [AuthException] into this app's typed [AppException]s).
class SupabaseAuthDatasource {
  SupabaseAuthDatasource(this._client);

  final SupabaseClient _client;

  /// Emits on every auth state change (sign-in, sign-out, token refresh) —
  /// including an initial event reflecting whatever session
  /// `Supabase.initialize()` already restored, so a fresh listener never
  /// has to wait for a first real change to know where it stands.
  Stream<AuthState> onAuthStateChange() => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) {
    return _client.auth.signUp(email: email, password: password, data: data);
  }

  /// Also tears down the Realtime socket: `signOut` re-authorizes any
  /// still-joined channels with the anon key rather than closing them
  /// (`SupabaseClient._handleTokenChanged` in the `supabase` package), so a
  /// channel that was open at sign-out time is left silently unable to see
  /// any RLS-protected rows. The next `.stream()` subscription (after this
  /// sign-out, or after a subsequent sign-in) would keep reusing that
  /// half-dead channel instead of getting a fresh one. Disconnecting here
  /// forces every channel to close, so the next `.stream()` call opens a new
  /// socket + channel from scratch.
  Future<void> signOut() async {
    await _client.auth.signOut();
    await _client.realtime.disconnect();
  }

  Future<Map<String, dynamic>> fetchProfileRow(String userId) {
    return _client.from('profiles').select().eq('id', userId).single();
  }

  Future<Map<String, dynamic>> fetchSupplierRow(String supplierId) {
    return _client.from('suppliers').select().eq('id', supplierId).single();
  }

  Future<void> updateSupplierVerificationStatus({
    required String supplierId,
    required String status,
  }) {
    return _client
        .from('suppliers')
        .update({'verification_status': status})
        .eq('id', supplierId);
  }
}
