import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/id_generator.dart';

/// Mirrors the `allowed_mime_types` set on every Storage bucket
/// (`supabase/migrations/0033_fix_notification_spoofing_payout_amount_and_upload_limits.sql`,
/// `0044_variant_video.sql`) — rejecting here too gives an immediate,
/// friendly error instead of a round-trip to Storage for something the
/// server would refuse anyway.
const _allowedContentTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'audio/mp4',
  'video/mp4',
  'video/quicktime',
};

/// Below every bucket's own `file_size_limit` — un contrôle immédiat plutôt
/// qu'un aller-retour dépensé pour un fichier que Storage refusera. Les
/// vidéos ont leur propre plafond : 5 ou 10 Mo suffisent à une photo, pas à
/// une vidéo de quelques dizaines de secondes (bucket `product-videos`,
/// 25 Mo).
const _maxUploadSizeBytes = 10 * 1024 * 1024;
const _maxVideoUploadSizeBytes = 25 * 1024 * 1024;

/// Uploads a picked file to [bucket] under `<folder>/<uuid>.<ext>` and
/// returns the object **path** (never a resolved URL — see
/// `ResolvedImage`, which turns a path back into something displayable at
/// read time via `getPublicUrl`). `folder` is always the owning
/// supplier/participant's id, matching the Storage policies in
/// `supabase/migrations/0001_initial_schema.sql`. Despite the name, also
/// used for KYC documents and voice notes (a plain local `XFile(path)`
/// works the same as a picker-sourced one) — pass [contentType] whenever
/// [file] isn't an image (its own `mimeType` is only ever set by
/// `image_picker`, never by a bare `XFile(path)` wrapping e.g. a `record`
/// package output), otherwise it would silently default to
/// `image/jpeg`.
Future<String> uploadPickedImage({
  required SupabaseClient client,
  required String bucket,
  required String folder,
  required XFile file,
  String? contentType,
}) async {
  final bytes = await file.readAsBytes();
  final effectiveContentType = contentType ?? file.mimeType ?? 'image/jpeg';
  if (!_allowedContentTypes.contains(effectiveContentType)) {
    throw Exception('Type de fichier non supporté : $effectiveContentType.');
  }
  final maxBytes = effectiveContentType.startsWith('video/')
      ? _maxVideoUploadSizeBytes
      : _maxUploadSizeBytes;
  if (bytes.length > maxBytes) {
    throw Exception('Fichier trop volumineux (max ${maxBytes ~/ (1024 * 1024)} Mo).');
  }

  final dotIndex = file.name.lastIndexOf('.');
  final extension = dotIndex == -1 ? 'jpg' : file.name.substring(dotIndex + 1);
  final path = '$folder/${IdGenerator.next()}.$extension';
  await client.storage
      .from(bucket)
      .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: effectiveContentType));
  return path;
}
