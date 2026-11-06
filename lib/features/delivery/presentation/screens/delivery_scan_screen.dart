import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/error/user_message.dart';

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
    required String this.deliveryId,
    required DeliveryCodeKind this.expected,
  })  : submit = null,
        title = null,
        instruction = null;

  /// La boutique qui livre elle-même scanne le code du client
  /// (`confirm_self_delivery_by_code`, `0139`) : le même geste que le
  /// livreur, une autre fonction serveur. [submit] lève l'exception du
  /// serveur si le code est refusé.
  const DeliveryScanScreen.handover({
    super.key,
    required Future<void> Function(String code) this.submit,
    required String this.title,
    required String this.instruction,
  })  : deliveryId = null,
        expected = null;

  final String? deliveryId;

  /// Ce que le livreur *croit* scanner, pour le libellé seulement.
  final DeliveryCodeKind? expected;

  final Future<void> Function(String code)? submit;
  final String? title;
  final String? instruction;

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

  /// Le dernier code refusé, et quand.
  ///
  /// Le verrou ci-dessus est levé après un refus — exprès, voir plus bas —
  /// alors que le QR refusé, lui, reste dans le cadre. Il repartait donc au
  /// serveur à l'image suivante : constaté le 17/10/2026 dans Chrome, 32
  /// refus identiques en 3 s, autant d'alertes empilées pendant plus de deux
  /// minutes. Le même code n'est plus renvoyé qu'après [_pauseApresRefus] ;
  /// un code différent passe tout de suite.
  String? _dernierRefuse;
  DateTime? _refuseA;
  static const _pauseApresRefus = Duration(seconds: 3);

  bool _vientDEtreRefuse(String code) =>
      code == _dernierRefuse &&
      _refuseA != null &&
      DateTime.now().difference(_refuseA!) < _pauseApresRefus;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere(
          (value) => value != null && value.isNotEmpty,
          orElse: () => null,
        );
    if (code == null || _vientDEtreRefuse(code)) return;

    setState(() => _handling = true);
    if (widget.submit case final submit?) {
      Object? refus;
      try {
        await submit(code);
      } catch (error) {
        refus = error;
      }
      if (!mounted) return;
      if (refus == null) {
        Navigator.of(context).pop(true);
        return;
      }
      _refuser(code, refus);
      return;
    }
    final status = await ref
        .read(courierControllerProvider.notifier)
        .scan(deliveryId: widget.deliveryId!, code: code);

    if (!mounted) return;
    if (status == null) {
      _refuser(code, ref.read(courierControllerProvider).error);
      return;
    }

    Navigator.of(context).pop(status);
  }

  void _refuser(String code, Object? error) {
    _dernierRefuse = code;
    _refuseA = DateTime.now();
    // Une alerte à la fois : la nouvelle remplace la précédente au lieu
    // d'attendre son tour.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_message(error))));
    // Réarmé après coup : un code refusé peut l'être pour une raison que
    // le livreur corrige sur place (mauvais QR présenté, mauvaise étape).
    setState(() => _handling = false);
  }

  /// Le motif vient du serveur, rédigé pour le livreur.
  ///
  /// La version précédente l'extrayait de `toString()` avec une expression
  /// qui s'arrêtait à la **première virgule** : « Code inconnu, expiré, ou
  /// déjà utilisé » devenait « Code inconnu ». `messagePourUtilisateur` lit
  /// le message lui-même, entier.
  String _message(Object? error) =>
      messagePourUtilisateur(error, repli: 'Code refusé.');

  @override
  Widget build(BuildContext context) {
    final titre = widget.title ??
        (widget.expected == DeliveryCodeKind.pickup
            ? 'Code de retrait'
            : 'Code de remise');
    final consigne = widget.instruction ??
        (widget.expected == DeliveryCodeKind.pickup
            ? 'Demandez au fournisseur d\'afficher le code de retrait.'
            : 'Demandez au client d\'afficher le code de remise.');

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
