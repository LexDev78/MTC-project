import 'package:flutter/material.dart';

import 'package:mtc_app/core/widgets/private_document_viewer.dart';

import '../../domain/entities/supplier_kyc.dart';

/// La pièce du dossier fournisseur, affichée.
///
/// L'écran de vérification réutilisait la tuile d'envoi de document, qui
/// n'annonce que « Document ajouté » avec une coche verte. L'agent devait
/// donc décider d'approuver ou de rejeter une pièce d'identité sans jamais la
/// voir — la seule chose que la validation est censée faire.
///
/// Le rendu lui-même est parti dans `PrivateDocumentViewer` le jour où le
/// dossier livreur a demandé exactement la même chose (`0105`) : ici ne
/// reste que ce qui est propre au fournisseur, c'est-à-dire son type de
/// pièce et son bucket.
class KycDocumentViewer extends StatelessWidget {
  const KycDocumentViewer({super.key, required this.document});

  final SupplierDocument document;

  @override
  Widget build(BuildContext context) {
    return PrivateDocumentViewer(
      label: document.type.label,
      path: document.filePath,
      bucket: 'kyc-documents',
    );
  }
}
