import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/supplier_kyc.dart';

/// One document slot in the KYC wizard — picks an image (camera or
/// gallery, per [source]) and hands the resulting file path to [onPicked].
/// Self-contained the same way `ChatComposer`'s image picking is: the
/// picking logic lives next to the button that triggers it, not in a
/// controller.
class DocumentUploadTile extends StatelessWidget {
  const DocumentUploadTile({
    super.key,
    required this.type,
    required this.existing,
    required this.onPicked,
    required this.onRemove,
    this.isRequired = false,
    this.source = ImageSource.gallery,
  });

  final SupplierDocumentType type;
  final SupplierDocument? existing;
  final ValueChanged<String> onPicked;
  final VoidCallback? onRemove;
  final bool isRequired;
  final ImageSource source;

  Future<void> _pick(BuildContext context) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file != null) onPicked(file.path);
    } catch (_) {
      if (!context.mounted) return;
      final sourceLabel = source == ImageSource.camera
          ? 'à la caméra'
          : 'à la galerie';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Impossible d'accéder $sourceLabel. Vérifiez l'autorisation dans les réglages du téléphone.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uploaded = existing != null;

    return Card(
      child: ListTile(
        leading: Icon(
          uploaded ? Icons.check_circle_rounded : Icons.upload_file_outlined,
          color: uploaded ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(isRequired ? '${type.label} *' : type.label),
        subtitle: Text(uploaded ? 'Document ajouté' : 'Aucun fichier'),
        trailing: uploaded
            ? IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                tooltip: 'Retirer',
                onPressed: onRemove,
              )
            : TextButton(
                onPressed: () => _pick(context),
                child: Text(
                  source == ImageSource.camera ? 'Prendre une photo' : 'Choisir',
                ),
              ),
        onTap: uploaded ? null : () => _pick(context),
      ),
    );
  }
}
