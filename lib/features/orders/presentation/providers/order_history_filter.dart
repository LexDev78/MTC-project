import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/order.dart';
import 'order_providers.dart';

/// Jusqu'où remonte l'historique des commandes : le filtre de la recherche
/// dans la maquette « Orders » du kit.
enum OrderPeriod {
  all('Toutes les dates', null),
  last30Days('30 derniers jours', 30),
  last3Months('3 derniers mois', 91),
  last12Months('12 derniers mois', 365);

  const OrderPeriod(this.label, this._jours);

  final String label;
  final int? _jours;

  /// « sur les 30 derniers jours », à accoler à une phrase ; vide pour
  /// toutes les dates.
  String get suffix => _jours == null ? '' : ' sur les ${label.toLowerCase()}';

  bool includes(DateTime placedAt, {DateTime? now}) {
    final jours = _jours;
    if (jours == null) return true;
    final depuis = (now ?? DateTime.now()).subtract(Duration(days: jours));
    return !placedAt.isBefore(depuis);
  }
}

/// La période choisie, partagée par l'historique et ses rubriques.
///
/// `autoDispose` : elle vit tant qu'un écran des commandes est ouvert, et
/// l'historique rouvert plus tard repart de toutes les dates.
final orderPeriodProvider = StateProvider.autoDispose<OrderPeriod>(
  (ref) => OrderPeriod.all,
);

/// Les commandes du client sur la période choisie, toujours de la plus
/// récente à la plus ancienne.
final ordersInPeriodProvider = Provider.autoDispose<AsyncValue<List<Order>>>((
  ref,
) {
  final periode = ref.watch(orderPeriodProvider);
  return ref
      .watch(ordersForUserProvider)
      .whenData(
        (liste) => [
          for (final c in liste)
            if (periode.includes(c.placedAt)) c,
        ],
      );
});
