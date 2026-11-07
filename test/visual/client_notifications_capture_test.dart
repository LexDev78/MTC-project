import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/chat/domain/entities/chat.dart';
import 'package:mtc_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:mtc_app/features/chat/presentation/screens/conversation_list_screen.dart';
import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/notifications/presentation/screens/client_notifications_screen.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../support/shop_capture.dart';
import '../support/shop_fixtures.dart';

AppNotification _notification(
  String id,
  NotificationType type,
  String titre,
  String corps,
  Duration age, {
  bool lue = false,
}) => AppNotification(
  id: id,
  userId: 'client-awa',
  type: type,
  title: titre,
  body: corps,
  createdAt: maintenant.subtract(age),
  isRead: lue,
);

final _notifications = [
  _notification(
    'n1',
    NotificationType.orderStatusUpdate,
    'Commande en route',
    'Votre commande chez MTC Officiel est partie avec son livreur.',
    const Duration(minutes: 2),
  ),
  _notification(
    'n2',
    NotificationType.newMessage,
    'Nouveau message',
    'Bogolan Bamako vous a répondu au sujet du tissu indigo.',
    const Duration(hours: 6),
  ),
  _notification(
    'n3',
    NotificationType.newComment,
    'Réponse à votre question',
    'La boutique a répondu sous « Miel pur de Kita ».',
    const Duration(days: 2),
    lue: true,
  ),
  _notification(
    'n4',
    NotificationType.orderStatusUpdate,
    'Commande livrée',
    'Votre commande chez Atelier de Mopti est arrivée. Laissez un avis !',
    const Duration(days: 9),
    lue: true,
  ),
];

List<Override> _donnees(List<AppNotification> liste) => [
  currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
  operatingSupplierIdProvider.overrideWithValue(null),
  notificationsProvider(
    'client-awa',
  ).overrideWith((ref) => Stream.value(liste)),
];

ChatConversation _conversation(
  String boutique,
  String dernier,
  Duration age, {
  int nonLus = 0,
}) => ChatConversation(
  id: 'conv-$boutique',
  clientId: 'client-awa',
  clientDisplayNameSnapshot: 'Awa Traoré',
  supplierId: 'f-$boutique',
  supplierName: boutique,
  lastMessagePreview: dernier,
  lastMessageAt: maintenant.subtract(age),
  unreadCountClient: nonLus,
  unreadCountSupplier: 0,
);

void main() {
  capturerEcran(
    'notifications',
    () => const ClientNotificationsScreen(),
    overrides: () => _donnees(_notifications),
  );
  capturerEcran(
    'notifications_vide',
    () => const ClientNotificationsScreen(),
    overrides: () => _donnees(const []),
  );
  capturerEcran(
    'messages',
    () => const ConversationListScreen(),
    overrides: () => [
      currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
      conversationsProvider.overrideWith(
        (ref) => Stream.value([
          _conversation(
            'Bogolan Bamako',
            'Oui, il reste trois pièces en indigo.',
            const Duration(minutes: 12),
            nonLus: 2,
          ),
          _conversation(
            'Coopérative de Kita',
            'Vous : Le miel est-il de cette année ?',
            const Duration(days: 1),
          ),
          _conversation('Atelier de Mopti', '', const Duration(days: 8)),
        ]),
      ),
    ],
  );
  capturerEcran(
    'messages_vide',
    () => const ConversationListScreen(),
    overrides: () => [
      currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
      conversationsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
  );
}
