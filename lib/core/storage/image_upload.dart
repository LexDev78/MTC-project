import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/id_generator.dart';

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
  final dotIndex = file.name.lastIndexOf('.');
  final extension = dotIndex == -1 ? 'jpg' : file.name.substring(dotIndex + 1);
  final path = '$folder/${IdGenerator.next()}.$extension';
  await client.storage
      .from(bucket)
      .uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType ?? file.mimeType ?? 'image/jpeg',
        ),
      );
  return path;
}
