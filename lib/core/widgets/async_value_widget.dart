import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mtc_error_view.dart';
import 'mtc_loading_view.dart';

/// Renders an [AsyncValue] through the app's shared loading/error views, so
/// every feature's list/detail screen handles async state the same way.
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.skipLoadingOnReload = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final WidgetBuilder? loading;
  final Widget Function(Object error, StackTrace stackTrace)? error;

  /// Garder les données déjà affichées pendant un **recalcul**, au lieu de
  /// les remplacer par l'indicateur de chargement.
  ///
  /// À activer sur un écran dont les données se recalculent en réponse à un
  /// geste de l'utilisateur. Sans cela, appliquer un code promo au paiement
  /// vidait toute la page et la redessinait — pour une soustraction.
  ///
  /// Laissé à `false` par défaut : sur un écran dont le contenu se
  /// rafraîchit tout seul, montrer l'ancien état sans rien signaler peut
  /// aussi induire en erreur. C'est à chaque écran de dire ce qui convient.
  final bool skipLoadingOnReload;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: skipLoadingOnReload,
      data: data,
      loading: () => loading?.call(context) ?? const MtcLoadingView(),
      error: (err, stack) =>
          error?.call(err, stack) ?? MtcErrorView(message: err.toString()),
    );
  }
}
