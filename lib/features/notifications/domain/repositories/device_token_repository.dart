/// Registers/unregisters this device's FCM token against the signed-in
/// user, so the push send path (`get_device_tokens_for_notification_user`,
/// see `0034_device_tokens.sql`) knows where to deliver a notification.
abstract interface class DeviceTokenRepository {
  /// Upserts [fcmToken] for [userId] — on conflict (the token itself is
  /// unique, see `0034_device_tokens.sql`), reassigns it to [userId] rather
  /// than duplicating, so a token rotating or a different account logging
  /// in on the same device both resolve to one row.
  Future<void> registerToken({required String userId, required String fcmToken});

  /// Removes [fcmToken] — called on logout (while the session that owns it
  /// is still authenticated, since `device_tokens_delete_own`'s RLS needs
  /// `auth.uid()` to still resolve) and when FCM reports it stale.
  Future<void> deleteToken(String fcmToken);
}
