import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/id_generator.dart';

/// Uploads a picked image to [bucket] under `<folder>/<uuid>.<ext>` and
/// returns the object **path** (never a resolved URL — see
/// `ResolvedImage`, which turns a path back into something displayable at
/// read time via `getPublicUrl`). `folder` is always the owning
/// supplier's id, matching the Storage policies in
/// `supabase/migrations/0001_initial_schema.sql`.
Future<String> uploadPickedImage({
  required SupabaseClient client,
  required String bucket,
  required String folder,
  required XFile file,
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
        fileOptions: FileOptions(contentType: file.mimeType ?? 'image/jpeg'),
      );
  return path;
}
