import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';

import '../../domain/entities/supplier_kyc.dart';

/// La pièce du dossier, **affichée**.
///
/// L'écran de vérification réutilisait la tuile d'envoi de document, qui
/// n'annonce que « Document ajouté » avec une coche verte. L'agent devait
/// donc décider d'approuver ou de rejeter une pièce d'identité sans jamais la
/// voir — la seule chose que la validation est censée faire.
///
/// Le bucket `kyc-documents` est **privé** (`0001_initial_schema.sql`) : son
/// contenu passe par une URL signée, d'où `signed: true`. Une URL publique y
/// renverrait une erreur, pas une image.
class KycDocumentViewer extends StatelessWidget {
  const KycDocumentViewer({super.key, required this.document});

  final SupplierDocument document;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _ouvrirEnGrand(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 180,
              child: ResolvedImage(
                path: document.filePath,
                bucket: 'kyc-documents',
                signed: true,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: scheme.errorContainer,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Pièce illisible ou introuvable.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      document.type.label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Icon(Icons.zoom_in_rounded, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Plein écran sur fond noir : une pièce d'identité se vérifie en lisant un
  /// numéro et une date, ce qu'une vignette de 180 pixels ne permet pas.
  void _ouvrirEnGrand(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      useSafeArea: false,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: ResolvedImage(
                  path: document.filePath,
                  bucket: 'kyc-documents',
                  signed: true,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
