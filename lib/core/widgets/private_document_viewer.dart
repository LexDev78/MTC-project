import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';

/// La pièce d'un dossier, **affichée**, depuis un bucket privé.
///
/// Un agent doit décider d'approuver ou de rejeter une pièce d'identité sans
/// jamais la voir si l'écran se contente d'annoncer « Document ajouté » — ce
/// qui était le cas de la vérification fournisseur avant
/// `KycDocumentViewer`, et de la validation livreur avant `0105`.
///
/// Les deux buckets concernés (`kyc-documents`, `courier-documents`) sont
/// **privés** : leur contenu passe par une URL signée, d'où `signed: true`.
/// Une URL publique y renverrait une erreur, pas une image.
class PrivateDocumentViewer extends StatelessWidget {
  const PrivateDocumentViewer({
    super.key,
    required this.label,
    required this.path,
    required this.bucket,
  });

  final String label;
  final String path;
  final String bucket;

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
                path: path,
                bucket: bucket,
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
                      label,
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
                  path: path,
                  bucket: bucket,
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
