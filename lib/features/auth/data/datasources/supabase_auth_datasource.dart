import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/storage/image_upload.dart';

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

  /// La fiche, ou `null` si ce compte n'en a pas — sans lever l'erreur
  /// `PGRST116` d'un `.single()` qui ne trouve rien.
  Future<Map<String, dynamic>?> fetchSupplierRowOrNull(String supplierId) {
    return _client.from('suppliers').select().eq('id', supplierId).maybeSingle();
  }

  /// Le nom d'une boutique, lisible par tous (le catalogue est public).
  Future<String?> fetchSupplierName(String supplierId) async {
    final row = await _client
        .from('suppliers')
        .select('business_name')
        .eq('id', supplierId)
        .maybeSingle();
    return row?['business_name'] as String?;
  }

  /// Fiche livreur (`couriers`, `0046_couriers_and_deliveries.sql`) — créée
  /// à l'inscription par `handle_new_user()`, comme la fiche fournisseur.
  Future<Map<String, dynamic>> fetchCourierRow(String courierId) {
    return _client.from('couriers').select().eq('id', courierId).single();
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

  /// Soft-deletes the caller's own account — see `deactivate_account()`
  /// (`0036_account_deactivation.sql`) for the exact rules (blocks a
  /// supplier with unresolved orders/payouts, staff accounts can't
  /// self-delete at all).
  Future<void> deactivateAccount() {
    return _client.rpc('deactivate_account');
  }

  /// Change le mot de passe de la session, **après avoir vérifié l'ancien**.
  ///
  /// `auth.updateUser` seul ne demande rien : quiconque tient un téléphone
  /// déverrouillé, session ouverte, pourrait remplacer le mot de passe et
  /// confisquer le compte. On se reconnecte donc d'abord avec le mot de passe
  /// actuel — c'est la preuve qu'on le connaît —, puis on le change.
  ///
  /// L'adresse de reconnexion est celle de l'authentification
  /// (`currentUser.email`), pas un `pseudoEmail` reconstruit : c'est elle qui
  /// fait foi, même pour un compte dont l'identifiant aurait été saisi
  /// autrement.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      throw const AuthException('Aucune session ouverte.');
    }
    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// L'adresse e-mail de contact du compte en session (`0109`), ou `null`.
  Future<String?> fetchContactEmail() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select('contact_email')
        .eq('id', userId)
        .maybeSingle();
    return row?['contact_email'] as String?;
  }

  /// L'adresse de contact et la date de sa vérification (`0124`).
  Future<Map<String, dynamic>?> fetchContactEmailRow() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return _client
        .from('profiles')
        .select('contact_email, contact_email_verified_at')
        .eq('id', userId)
        .maybeSingle();
  }

  /// Fait partir un code à [email]. Rend l'adresse normalisée, l'échéance
  /// du code et le délai avant de pouvoir en redemander un — jamais le code.
  Future<Map<String, dynamic>> requestContactEmailCode(String email) async {
    final result = await _client.rpc(
      'request_contact_email_code',
      params: {'p_email': email},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// `{"ok": true, "email": …}`, ou `{"ok": false, "message": …}` pour un
  /// code faux : une réponse et non une erreur, pour que l'essai reste
  /// compté côté serveur.
  Future<Map<String, dynamic>> confirmContactEmail(String code) async {
    final result = await _client.rpc(
      'confirm_contact_email',
      params: {'p_code': code},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// Mot de passe oublié : rend l'adresse masquée, l'échéance du code et
  /// le délai avant d'en redemander un (`0127`).
  Future<Map<String, dynamic>> requestPasswordReset(String identifier) async {
    final result = await _client.rpc(
      'request_password_reset',
      params: {'p_identifiant': identifier},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// `{"ok": true, "username": …}`, ou `{"ok": false, "message": …}` pour un
  /// code faux — une réponse et non une erreur, pour que l'essai reste
  /// compté côté serveur.
  Future<Map<String, dynamic>> resetPasswordWithCode({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    final result = await _client.rpc(
      'reset_password_with_code',
      params: {
        'p_identifiant': identifier,
        'p_code': code,
        'p_password': newPassword,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// Enregistre l'adresse de contact — ou la retire si [email] est vide.
  /// Le serveur la normalise (minuscules, sans blancs) et la renvoie.
  Future<String?> setContactEmail(String? email) async {
    final result = await _client.rpc(
      'set_my_contact_email',
      params: {'p_email': email},
    );
    return result as String?;
  }

  /// Change le nom affiché du compte en session (`0116`). Le serveur le
  /// normalise (blancs en trop retirés) et le renvoie.
  Future<String> setDisplayName(String displayName) async {
    final result = await _client.rpc(
      'set_my_display_name',
      params: {'p_display_name': displayName},
    );
    return result as String;
  }

  /// Change le numéro du compte client en session (`0121`). Le serveur le
  /// rend sous la forme `+223XXXXXXXX`.
  Future<String> setPhoneNumber(String phoneNumber) async {
    final result = await _client.rpc(
      'set_my_phone_number',
      params: {'p_phone': phoneNumber},
    );
    return result as String;
  }

  /// La date seule, sans heure ni fuseau : `1995-03-12`.
  Future<void> setBirthDate(DateTime? birthDate) {
    return _client.rpc(
      'set_my_birth_date',
      params: {
        'p_birth_date': birthDate == null
            ? null
            : '${birthDate.year.toString().padLeft(4, '0')}-'
                  '${birthDate.month.toString().padLeft(2, '0')}-'
                  '${birthDate.day.toString().padLeft(2, '0')}',
      },
    );
  }

  /// Dépose la photo dans le dossier du compte, dans le bucket privé
  /// `avatars`, et rend son chemin.
  Future<String> uploadAvatar({required String userId, required XFile photo}) {
    return uploadPickedImage(
      client: _client,
      bucket: 'avatars',
      folder: userId,
      file: photo,
    );
  }

  /// Retient [path] comme photo du compte, ou la retire (`null`).
  Future<void> setAvatarPath(String? path) {
    return _client.rpc('set_my_avatar', params: {'p_path': path});
  }

  Future<void> removeAvatarFile(String path) async {
    await _client.storage.from('avatars').remove([path]);
  }

  /// Le rattachement de ce compte à la boutique d'un autre, s'il existe
  /// (`supplier_collaborators`, `0093`).
  ///
  /// `maybeSingle` et non `single` : l'absence est le cas courant — la
  /// plupart des comptes fournisseur possèdent leur boutique.
  Future<Map<String, dynamic>?> fetchCollaborationRow(String userId) async {
    final row = await _client
        .from('supplier_collaborators')
        // `deactivated_at` : un accès retiré garde sa ligne (`0110`), et
        // c'est elle qui permet de dire au collaborateur ce qui lui arrive.
        .select('supplier_id, permissions, deactivated_at')
        .eq('user_id', userId)
        .maybeSingle();
    return row;
  }
}
