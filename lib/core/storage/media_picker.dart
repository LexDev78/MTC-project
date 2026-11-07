import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'image_upload.dart';

/// Ce qu'une cueillette a rapporté : les chemins envoyés, et combien de
/// fichiers sont restés en route.
///
/// Les échecs sont comptés plutôt que levés : sur dix photos choisies, une
/// seule trop lourde ne doit pas faire perdre les neuf autres, déjà
/// téléversées. L'appelant annonce ce qui a échoué dans ses propres termes
/// et garde le reste.
typedef MediaUploadResult = ({List<String> paths, int failures});

/// Plusieurs photos en une fois, téléversées dans [bucket] sous [folder].
///
/// `folder` est toujours l'identifiant du propriétaire : c'est ce que les
/// policies Storage vérifient à l'envoi (`(storage.foldername(name))[1] =
/// auth.uid()`) et, pour les avis, ce que la base revérifie à l'écriture de
/// la ligne (`validate_media_paths`, `0061`). Un dossier qui n'est pas le
/// sien est refusé des deux côtés.
Future<MediaUploadResult> pickAndUploadImages({
  required SupabaseClient client,
  required String bucket,
  required String folder,
  int? limit,
}) async {
  final List<XFile> files;
  try {
    files = await ImagePicker().pickMultiImage(imageQuality: 85, limit: limit);
  } catch (_) {
    return (paths: const <String>[], failures: 0);
  }
  if (files.isEmpty) return (paths: const <String>[], failures: 0);

  final paths = <String>[];
  var failures = 0;
  for (final file in files) {
    try {
      paths.add(
        await uploadPickedImage(
          client: client,
          bucket: bucket,
          folder: folder,
          file: file,
        ),
      );
    } catch (_) {
      failures++;
    }
  }
  return (paths: paths, failures: failures);
}

/// Une courte vidéo. Renvoie `null` si l'utilisateur a renoncé, et lève si
/// l'envoi a échoué — un seul fichier, donc rien à sauver d'un demi-succès.
///
/// [maxDuration] est une consigne donnée au sélecteur, pas une garantie :
/// selon la plateforme il propose de rogner, ou l'ignore pour un fichier
/// déjà présent dans la galerie. Ce qui tient vraiment, c'est le plafond du
/// bucket (25 Mo), vérifié aussi côté client par `uploadPickedImage`.
Future<String?> pickAndUploadVideo({
  required SupabaseClient client,
  required String bucket,
  required String folder,
  Duration maxDuration = const Duration(seconds: 30),
}) async {
  final file = await ImagePicker().pickVideo(
    source: ImageSource.gallery,
    maxDuration: maxDuration,
  );
  if (file == null) return null;
  return uploadPickedImage(
    client: client,
    bucket: bucket,
    folder: folder,
    file: file,
    // `XFile.mimeType` n'est renseigné que par certaines plateformes :
    // l'extension est le seul indice fiable, et une vidéo envoyée sans type
    // (donc `image/jpeg` par défaut) serait refusée par le bucket.
    contentType: file.name.toLowerCase().endsWith('.mov')
        ? 'video/quicktime'
        : 'video/mp4',
  );
}
