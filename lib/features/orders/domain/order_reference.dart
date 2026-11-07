import 'entities/order.dart';

/// Le numéro qu'un client lit et dicte (« #3F2A9C1B ») : les huit premiers
/// caractères de l'identifiant, en capitales — de quoi retrouver la
/// commande au service client, sans les trente-six caractères d'un UUID.
extension OrderReference on Order {
  String get reference {
    final brut = id.replaceAll('-', '');
    return '#${(brut.length > 8 ? brut.substring(0, 8) : brut).toUpperCase()}';
  }
}
