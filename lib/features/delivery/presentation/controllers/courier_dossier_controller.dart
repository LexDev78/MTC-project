import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/storage/image_upload.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/core/error/user_message.dart';

import '../../domain/entities/courier_dossier.dart';
import '../providers/delivery_providers.dart';

/// Le dossier du livreur : déposer ses pièces, puis le soumettre (`0105`).
///
/// Même découpage que `SupplierKycController` : le fichier part d'abord vers
/// le bucket privé, et seul son **chemin dans le bucket** est enregistré. Un
/// chemin local du téléphone enregistré tel quel ne voudrait rien dire pour
/// l'agent qui ouvre le dossier.
class CourierDossierController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Envoie [file] dans `courier-documents` sous le dossier du livreur, puis
  /// l'enregistre. La RLS du bucket impose ce découpage par identifiant : on
  /// ne peut pas écrire dans le dossier d'un autre livreur.
  Future<bool> addDocument({
    required CourierDocumentType type,
    required XFile file,
  }) async {
    final courier = ref.read(currentCourierProvider);
    if (courier == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final path = await uploadPickedImage(
        client: ref.read(supabaseClientProvider),
        bucket: 'courier-documents',
        folder: courier.id,
        file: file,
      );
      await ref
          .read(deliveryRepositoryProvider)
          .saveDocument(courierId: courier.id, type: type, filePath: path);
    });
    if (!state.hasError) ref.invalidate(courierDossierProvider);
    return !state.hasError;
  }

  Future<bool> removeDocument({required String documentId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(deliveryRepositoryProvider)
          .removeDocument(documentId: documentId),
    );
    if (!state.hasError) ref.invalidate(courierDossierProvider);
    return !state.hasError;
  }

  /// Dépose le dossier. Le serveur vérifie les pièces exigées par le moyen
  /// de transport : l'écran les affiche, il ne les garantit pas.
  ///
  /// Invalide aussi le compte en session — c'est `documentsSubmittedAt` qui
  /// décide de ce que montre l'écran d'attente, et il vient de changer.
  Future<bool> submit({
    required CourierVehicleType vehicleType,
    String? vehicleLabel,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(deliveryRepositoryProvider)
          .submitDossier(vehicleType: vehicleType, vehicleLabel: vehicleLabel),
    );
    if (!state.hasError) {
      ref.invalidate(courierDossierProvider);
      ref.invalidate(currentUserProvider);
    }
    return !state.hasError;
  }

  /// Le message à montrer au livreur si la dernière action a échoué —
  /// « Pièces manquantes : … », ou la cause traduite d'une panne.
  String? get lastError {
    final error = state.error;
    if (error == null) return null;
    return messagePourUtilisateur(
      error,
      repli: 'L\'action n\'a pas abouti. Réessayez.',
    );
  }
}

final courierDossierControllerProvider =
    AsyncNotifierProvider<CourierDossierController, void>(
      CourierDossierController.new,
    );
