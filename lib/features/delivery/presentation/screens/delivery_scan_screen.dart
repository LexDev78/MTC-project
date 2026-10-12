import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

import '../../domain/entities/courier_delivery.dart';
import '../controllers/courier_controller.dart';

/// Scan du QR présenté par le fournisseur (retrait) ou par le client
/// (remise).
///
/// L'écran ne décide de rien : il lit un code et le transmet. C'est le
/// serveur qui détermine quelle étape il accuse, à partir du statut de la
/// course (`scan_delivery_code`, `0051`) — sans quoi l'app pourrait accuser
/// une remise sans retrait en changeant un paramètre.
class DeliveryScanScreen extends ConsumerStatefulWidget {
  const DeliveryScanScreen({
    super.key,
    required this.deliveryId,
    required this.expected,
  });

  final String deliveryId;

  /// Ce que le livreur *croit* scanner, pour le libellé seulement.
  final DeliveryCodeKind expected;

  @override
  ConsumerState<DeliveryScanScreen> createState() => _DeliveryScanScreenState();
}

class _DeliveryScanScreenState extends ConsumerState<DeliveryScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Un QR est détecté plusieurs fois par seconde tant qu'il reste dans le
  /// cadre. Sans ce verrou, le premier scan réussi serait suivi d'une volée
  /// d'appels identiques — tous refusés, puisque le code vient d'être
  /// consommé — et le livreur verrait une erreur juste après son succès.
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((value) => value != null && value.isNotEmpty, orElse: () => null);
    if (code == null) return;

    setState(() => _handling = true);
    final status = await ref
        .read(courierControllerProvider.notifier)
        .scan(deliveryId: widget.deliveryId, code: code);

    if (!mounted) return;
    if (status == null) {
      final error = ref.read(courierControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
      // Réarmé après coup : un code refusé peut l'être pour une raison que
      // le livreur corrige sur place (mauvais QR présenté, mauvaise étape).
      setState(() => _handling = false);
      return;
    }

    Navigator.of(context).pop(status);
  }

  /// Le motif vient du serveur. On ne garde que son message, sans le code
  /// d'erreur ni le détail SQL qui ne disent rien au livreur.
  String _message(Object? error) {
    if (error == null) return 'Code refusé.';
    final text = error.toString();
    final match = RegExp(r'message: ([^,]+)').firstMatch(text);
    return match?.group(1) ?? 'Code refusé.';
  }

  @override
  Widget build(BuildContext context) {
    final titre = widget.expected == DeliveryCodeKind.pickup
        ? 'Code de retrait'
        : 'Code de remise';
    final consigne = widget.expected == DeliveryCodeKind.pickup
        ? 'Demandez au fournisseur d\'afficher le code de retrait.'
        : 'Demandez au client d\'afficher le code de remise.';

    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Text(
                  consigne,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          if (_handling)
            const ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
