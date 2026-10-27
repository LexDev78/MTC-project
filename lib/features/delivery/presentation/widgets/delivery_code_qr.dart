import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/courier_delivery.dart';
import '../providers/delivery_providers.dart';

/// Le QR à présenter au livreur : celui du retrait côté fournisseur, celui de
/// la remise côté client.
///
/// Affiché sur fond blanc quoi qu'il arrive : un lecteur de QR cherche un
/// contraste sombre sur clair, et en mode sombre un code rendu dans les
/// couleurs du thème devient illisible pour la caméra d'en face.
///
/// Le code n'est jamais montré en clair à côté : il n'a aucune raison d'être
/// recopié à la main, et l'afficher inviterait à le dicter au téléphone — ce
/// qui ferait exactement ce que le scan est censé empêcher.
class DeliveryCodeQr extends ConsumerWidget {
  const DeliveryCodeQr({
    super.key,
    required this.deliveryId,
    required this.kind,
    required this.title,
    required this.instruction,
  });

  final String deliveryId;
  final DeliveryCodeKind kind;
  final String title;
  final String instruction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final codeAsync = ref.watch(
      deliveryCodeProvider((deliveryId: deliveryId, kind: kind)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            AsyncValueWidget(
              value: codeAsync,
              data: (code) {
                if (code == null) {
                  // Consommé : l'étape est accusée, le QR n'a plus lieu d'être.
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: scheme.primary),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(child: Text('Déjà scanné.')),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: QrImageView(
                        data: code,
                        size: 190,
                        backgroundColor: Colors.white,
                        // `Colors.black` et non `scheme.onSurface` : voir le
                        // commentaire de classe.
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      instruction,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
