import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/di/providers.dart';

/// La remise d'une commande que la boutique livre elle-même (`0139`).
///
/// Elle ne se déclare plus d'un côté : la boutique ne passe plus seule une
/// telle commande à « livrée ». La remise se prouve par le code du client,
/// que la boutique scanne, ou par le client lui-même, d'un bouton — comme
/// une course MTC se clôt par le scan du livreur. Sans cela, une boutique
/// encaissait une vente payée d'avance qu'elle n'avait pas remise, et un
/// complice notait 5★ des commandes jamais livrées (audit du 27/10/2026).
///
/// Trois fonctions serveur, rien en local : le code ne se calcule ni ne se
/// garde dans l'app.
class SelfDeliveryHandover {
  SelfDeliveryHandover(this._client);

  final SupabaseClient _client;

  /// Le code à montrer à la boutique, côté client ; `null` une fois la
  /// remise faite, ou quand il n'y a rien à remettre.
  Future<String?> fetchCode(String groupId) async {
    final code = await _client.rpc(
      'fetch_self_delivery_code',
      params: {'p_group_id': groupId},
    );
    return code as String?;
  }

  /// La boutique a scanné le code : la commande est livrée. Lève l'erreur du
  /// serveur, à montrer telle quelle, si le code est refusé.
  Future<void> confirmByCode({required String groupId, required String code}) {
    return _client.rpc(
      'confirm_self_delivery_by_code',
      params: {'p_group_id': groupId, 'p_code': code},
    );
  }

  /// Le client confirme avoir reçu sa commande.
  Future<void> confirmReceived(String groupId) {
    return _client.rpc(
      'confirm_self_delivery_received',
      params: {'p_group_id': groupId},
    );
  }
}

final selfDeliveryHandoverProvider = Provider<SelfDeliveryHandover>(
  (ref) => SelfDeliveryHandover(ref.watch(supabaseClientProvider)),
);

/// `autoDispose`, comme le code d'une course (`deliveryCodeProvider`) : il
/// n'a pas à survivre à l'écran, ni au compte suivant sur le même appareil.
final selfDeliveryCodeProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, groupId) {
  return ref.watch(selfDeliveryHandoverProvider).fetchCode(groupId);
});
