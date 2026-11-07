import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';

import 'controllers/chat_controller.dart';

/// Ouvre la conversation du client avec une boutique — la crée au besoin —
/// et y emmène, avec [attachment] (un produit à joindre) s'il y en a un.
///
/// Un échec le dit : un bouton « Écrire à la boutique » qui ne répond pas se
/// lit comme une application cassée, et l'on recommence au lieu de
/// comprendre.
Future<void> openShopConversation(
  BuildContext context,
  WidgetRef ref, {
  required String supplierId,
  required String supplierName,
  Object? attachment,
}) async {
  void signaler(Object? erreur) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        messagePourUtilisateur(
          erreur,
          repli: 'La conversation n\'a pas pu être ouverte.',
        ),
      ),
    ),
  );

  final String? conversationId;
  try {
    conversationId = await ref
        .read(chatControllerProvider.notifier)
        .startConversationWithSupplier(
          supplierId: supplierId,
          supplierName: supplierName,
        );
  } catch (erreur) {
    if (context.mounted) signaler(erreur);
    return;
  }
  if (!context.mounted) return;
  if (conversationId == null) {
    signaler(ref.read(chatControllerProvider).error);
    return;
  }
  unawaited(
    context.push(AppRoutes.chatThread(conversationId), extra: attachment),
  );
}
