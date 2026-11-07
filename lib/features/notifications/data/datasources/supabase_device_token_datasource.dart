import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw `device_tokens` I/O — see `0034_device_tokens.sql`.
///
/// L'enregistrement passe par `register_device_token` (`0149`) et non plus
/// par un upsert : la policy refusait l'upsert dès que le jeton appartenait
/// à un autre compte, et ce refus était avalé. Après une déconnexion dont
/// le nettoyage n'avait pas atteint le serveur, le téléphone recevait pour
/// toujours les notifications du compte précédent. Détenir le jeton prouve
/// qu'on est sur l'appareil : la fonction le donne au compte connecté.
class SupabaseDeviceTokenDatasource {
  SupabaseDeviceTokenDatasource(this._client);

  final SupabaseClient _client;

  /// [userId] n'est plus envoyé : le serveur prend le compte de la session.
  Future<void> upsert({required String userId, required String fcmToken}) async {
    await _client.rpc(
      'register_device_token',
      params: {'p_token': fcmToken},
    );
  }

  Future<void> delete(String fcmToken) async {
    await _client.from('device_tokens').delete().eq('fcm_token', fcmToken);
  }
}
