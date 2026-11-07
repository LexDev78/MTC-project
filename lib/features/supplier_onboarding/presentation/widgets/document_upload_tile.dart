import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/core/widgets/document_slot_tile.dart';

import '../../domain/entities/supplier_kyc.dart';

/// Un emplacement de pièce du dossier fournisseur.
///
/// Habille `DocumentSlotTile` des types du fournisseur. La tuile elle-même
/// est devenue générique quand le dossier livreur a eu besoin de la même
/// (`0105`) : une seule implémentation, deux dossiers.
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
  final ValueChanged<XFile> onPicked;
  final VoidCallback? onRemove;
  final bool isRequired;
  final ImageSource source;

  @override
  Widget build(BuildContext context) {
    return DocumentSlotTile(
      label: type.label,
      hasFile: existing != null,
      onPicked: onPicked,
      onRemove: onRemove,
      isRequired: isRequired,
      source: source,
    );
  }
}
