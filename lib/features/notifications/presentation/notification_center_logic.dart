import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../domain/entities/app_notification.dart';
import '../domain/notification_route_resolver.dart';
import 'controllers/notification_controller.dart';
import 'providers/notification_providers.dart';

/// Ce que fait un centre de notifications, quel que soit le rôle qui le
/// regarde : retenir ce qui a été ouvert ici, ouvrir une notification là où
/// elle mène, tout marquer comme lu, et relire la liste à l'arrivée.
///
/// Partagé par l'écran des fournisseurs et celui du client (au style du
/// kit) : seule l'apparence diffère, pas ce que fait un toucher.
mixin NotificationCenterLogic<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Ce qui a été ouvert ici, avant même que le serveur l'ait enregistré :
  /// la pastille disparaît au toucher, pas après l'aller-retour — qui peut
  /// prendre plusieurs secondes sur un réseau lent.
  final _lues = <String>{};

  /// À qui sont les notifications : la boutique gérée pour un fournisseur
  /// ou un collaborateur, le compte lui-même pour un client.
  String? watchNotificationOwner() =>
      ref.watch(operatingSupplierIdProvider) ??
      ref.watch(currentUserProvider).valueOrNull?.id;

  bool isUnreadHere(AppNotification notification) =>
      !notification.isRead && !_lues.contains(notification.id);

  void openNotification(AppNotification notification) {
    if (isUnreadHere(notification)) {
      setState(() => _lues.add(notification.id));
      // Sans attendre la réponse : ouvrir la commande ou la conversation
      // ne doit pas dépendre de l'accusé de lecture. La liste, et avec
      // elle les compteurs de la cloche et du menu, se relit quand il
      // aboutit.
      unawaited(
        ref
            .read(notificationControllerProvider.notifier)
            .markRead(notification.id),
      );
    }
    final route = resolveNotificationRoute(
      type: notification.type,
      referenceId: notification.referenceId,
      isClient: ref.read(currentUserProvider).valueOrNull is ClientUser,
      supplierRoutePrefix: ref.read(supplierRoutePrefixProvider),
    );
    if (route != null) unawaited(context.push(route));
  }

  void markAllRead(String userId, List<AppNotification> notifications) {
    setState(() => _lues.addAll(notifications.map((n) => n.id)));
    unawaited(
      ref.read(notificationControllerProvider.notifier).markAllRead(userId),
    );
  }

  @override
  void initState() {
    super.initState();
    // `notificationsProvider` n'est pas `autoDispose` (la cloche de l'en-tête
    // le garde en vie toute la session) et aucune souscription temps réel
    // ne couvre cette table : sans cette relecture, une notification créée
    // ailleurs pendant que la liste était déjà en mémoire resterait
    // invisible jusqu'à un rafraîchissement sans rapport. La relire à
    // chaque ouverture tient la promesse « vue à la prochaine visite ».
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId =
          ref.read(operatingSupplierIdProvider) ??
          ref.read(currentUserProvider).valueOrNull?.id;
      if (userId != null) ref.invalidate(notificationsProvider(userId));
    });
  }
}
