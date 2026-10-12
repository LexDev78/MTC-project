import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';

import '../providers/characteristic_type_providers.dart';

/// Drives a staff member's approve/reject decision on a supplier-proposed
/// characteristic type — cloned from `KycReviewController`, just against a
/// single mutable record instead of a multi-field dossier.
class CharacteristicTypeReviewController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> approve({
    required String id,
    required String proposedBySupplierId,
    required String staffId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(characteristicTypeRepositoryProvider)
          .approve(id: id, staffId: staffId);
      await ref
          .read(notificationRepositoryProvider)
          .add(
            userId: proposedBySupplierId,
            type: NotificationType.characteristicTypeDecision,
            title: 'Caractéristique approuvée',
            body: 'Votre proposition de caractéristique a été validée.',
          );
    });
    return !state.hasError;
  }

  Future<bool> reject({
    required String id,
    required String proposedBySupplierId,
    required String staffId,
    required String reason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(characteristicTypeRepositoryProvider)
          .reject(id: id, staffId: staffId, reason: reason);
      await ref
          .read(notificationRepositoryProvider)
          .add(
            userId: proposedBySupplierId,
            type: NotificationType.characteristicTypeDecision,
            title: 'Caractéristique refusée',
            body: reason,
          );
    });
    return !state.hasError;
  }
}

final characteristicTypeReviewControllerProvider =
    AsyncNotifierProvider<CharacteristicTypeReviewController, void>(
      CharacteristicTypeReviewController.new,
    );
