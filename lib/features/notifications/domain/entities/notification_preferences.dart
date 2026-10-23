/// Les réglages de notification d'un client (`0118`) : tout couper, ou une
/// sorte de notification. Sans ligne en base, tout est permis.
///
/// Le serveur les applique à la source : une notification coupée n'est pas
/// écrite, donc ni listée, ni comptée, ni poussée sur le téléphone.
class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.orderUpdates = true,
    this.messages = true,
    this.comments = true,
  });

  factory NotificationPreferences.fromRow(Map<String, dynamic>? row) {
    if (row == null) return allOn;
    return NotificationPreferences(
      enabled: row['enabled'] as bool,
      orderUpdates: row['order_updates'] as bool,
      messages: row['messages'] as bool,
      comments: row['comments'] as bool,
    );
  }

  /// L'état d'un compte qui n'a jamais rien réglé.
  static const allOn = NotificationPreferences();

  /// Le maître interrupteur : coupé, plus rien n'arrive.
  final bool enabled;

  /// `order_status_update` : la commande avance, ou elle est annulée.
  final bool orderUpdates;

  /// `new_message` : une boutique écrit au client.
  final bool messages;

  /// `new_comment` : quelqu'un répond au commentaire du client sous un
  /// produit.
  final bool comments;

  bool get isAllOn => enabled && orderUpdates && messages && comments;

  Map<String, dynamic> toRow(String userId) => {
    'user_id': userId,
    'enabled': enabled,
    'order_updates': orderUpdates,
    'messages': messages,
    'comments': comments,
  };

  NotificationPreferences copyWith({
    bool? enabled,
    bool? orderUpdates,
    bool? messages,
    bool? comments,
  }) => NotificationPreferences(
    enabled: enabled ?? this.enabled,
    orderUpdates: orderUpdates ?? this.orderUpdates,
    messages: messages ?? this.messages,
    comments: comments ?? this.comments,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.enabled == enabled &&
      other.orderUpdates == orderUpdates &&
      other.messages == messages &&
      other.comments == comments;

  @override
  int get hashCode => Object.hash(enabled, orderUpdates, messages, comments);
}
