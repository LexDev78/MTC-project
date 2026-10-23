import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

/// Un conteneur de providers neuf pour chaque compte.
///
/// Tout l'état de l'app — données lues, formulaires en cours, codes
/// affichés — vit dans un `ProviderContainer`. Il était créé une fois au
/// démarrage et survivait à la déconnexion : le compte suivant, sur le même
/// appareil, héritait de ce que le précédent avait chargé. Constaté le
/// 18/10/2026 : les promotions d'une boutique affichées dans « Mes
/// promotions » d'une autre ; le statut de livraison lu par le fournisseur
/// resservi au client, qui ne voyait jamais son QR de remise. Et le
/// formulaire de commande gardait le téléphone, le message et la note vocale
/// du client précédent.
///
/// Quand un compte se termine — déconnexion, session expirée, compte retiré
/// — l'app repart donc d'un conteneur neuf, exactement comme à son
/// lancement.
///
/// « Se termine » : un compte que l'app a chargé ([currentUserProvider] a
/// livré un utilisateur) et qu'elle n'a plus, ou qui en remplace un autre.
/// Une connexion refusée en cours de route — un collaborateur retiré, dont
/// la session s'ouvre puis se ferme aussitôt — ne compte pas : l'écran de
/// connexion doit garder le message qui l'explique.
class SessionScope extends StatefulWidget {
  const SessionScope({
    super.key,
    required this.createContainer,
    this.initialContainer,
    this.onContainerChanged,
    this.disposeDelay = const Duration(seconds: 2),
    required this.child,
  });

  final ProviderContainer Function() createContainer;

  /// Le premier conteneur, s'il existe déjà — `bootstrap.dart` le crée avant
  /// `runApp` pour que les notifications push aient de quoi lire dès le
  /// démarrage.
  final ProviderContainer? initialContainer;

  /// Prévenu à chaque nouveau conteneur, pour ce qui le lit hors de l'arbre.
  final void Function(ProviderContainer container)? onContainerChanged;

  /// Délai avant de libérer l'ancien conteneur : la déconnexion qui a
  /// déclenché le changement finit de s'exécuter dessus.
  final Duration disposeDelay;

  final Widget child;

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  late ProviderContainer _container;
  ProviderSubscription<AsyncValue<AppUser?>>? _subscription;

  @override
  void initState() {
    super.initState();
    _install(widget.initialContainer ?? widget.createContainer());
  }

  void _install(ProviderContainer container) {
    _container = container;
    widget.onContainerChanged?.call(container);
    _subscription = container.listen<AsyncValue<AppUser?>>(
      currentUserProvider,
      (previous, next) {
        final before = previous?.valueOrNull?.id;
        if (before == null || next.isLoading || next.hasError) return;
        if (next.valueOrNull?.id != before) _renew();
      },
    );
  }

  void _renew() {
    final old = _container;
    _subscription?.close();
    setState(() => _install(widget.createContainer()));
    Future<void>.delayed(widget.disposeDelay, old.dispose);
  }

  @override
  void dispose() {
    _subscription?.close();
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      // Une clé par conteneur : tout l'arbre repart de zéro avec lui, comme
      // au lancement — navigation comprise.
      key: ObjectKey(_container),
      container: _container,
      child: widget.child,
    );
  }
}
