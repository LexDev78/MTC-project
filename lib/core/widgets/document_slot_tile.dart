import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Un emplacement de pièce à déposer — choisit une image (caméra ou galerie,
/// selon [source]) et remet le fichier à [onPicked], qui l'envoie avant de
/// l'enregistrer : le chemin local du téléphone n'est jamais persisté.
///
/// Générique à dessein : la même tuile sert au dossier du fournisseur
/// (`DocumentUploadTile`, qui l'habille de ses propres types) et à celui du
/// livreur (`0105`). Elle ne connaît qu'un libellé et la présence d'un
/// fichier — c'est tout ce qui change d'un dossier à l'autre.
///
/// La sélection vit ici, à côté du bouton qui la déclenche, comme pour
/// `ChatComposer` : un contrôleur n'a rien à savoir d'un sélecteur d'images.
class DocumentSlotTile extends StatelessWidget {
  const DocumentSlotTile({
    super.key,
    required this.label,
    required this.hasFile,
    required this.onPicked,
    required this.onRemove,
    this.isRequired = false,
    this.source = ImageSource.gallery,
  });

  final String label;
  final bool hasFile;
  final ValueChanged<XFile> onPicked;
  final VoidCallback? onRemove;
  final bool isRequired;
  final ImageSource source;

  Future<void> _pick(BuildContext context) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file != null) onPicked(file);
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

    return Card(
      child: ListTile(
        leading: Icon(
          hasFile ? Icons.check_circle_rounded : Icons.upload_file_outlined,
          color: hasFile ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(isRequired ? '$label *' : label),
        subtitle: Text(hasFile ? 'Document ajouté' : 'Aucun fichier'),
        trailing: hasFile
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
        onTap: hasFile ? null : () => _pick(context),
      ),
    );
  }
}
