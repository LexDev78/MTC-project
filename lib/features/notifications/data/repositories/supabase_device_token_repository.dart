import 'package:flutter/foundation.dart';

import '../../domain/repositories/device_token_repository.dart';
import '../datasources/supabase_device_token_datasource.dart';

class SupabaseDeviceTokenRepository implements DeviceTokenRepository {
  SupabaseDeviceTokenRepository(this._datasource);

  final SupabaseDeviceTokenDatasource _datasource;

  // Same "never let a delivery-channel write block the real action" stance
  // as `SupabaseNotificationRepository.add()`: a failed token
  // register/delete is a missed-push risk, never something that should
  // surface as a user-facing error or block login/logout.
  @override
  Future<void> registerToken({
    required String userId,
    required String fcmToken,
  }) async {
    try {
      await _datasource.upsert(userId: userId, fcmToken: fcmToken);
    } catch (e) {
      debugPrint('DeviceTokenRepository.registerToken failed (ignored): $e');
    }
  }

  @override
  Future<void> deleteToken(String fcmToken) async {
    try {
      await _datasource.delete(fcmToken);
    } catch (e) {
      debugPrint('DeviceTokenRepository.deleteToken failed (ignored): $e');
    }
  }
}
