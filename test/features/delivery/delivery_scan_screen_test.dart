import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/features/delivery/domain/entities/courier_delivery.dart';
import 'package:mtc_app/features/delivery/presentation/controllers/courier_controller.dart';
import 'package:mtc_app/features/delivery/presentation/screens/delivery_scan_screen.dart';

/// Refuse tout code, comme le serveur un code déjà consommé, et compte les
/// envois.
class _RefuseTout extends CourierController {
  _RefuseTout(this.envois);

  final List<String> envois;

  @override
  Future<DeliveryStatus?> scan({
    required String deliveryId,
    required String code,
  }) async {
    envois.add(code);
    // Comme le vrai contrôleur : l'erreur arrive après un aller-retour, donc
    // après la fin de `build()` — posée avant, elle serait écrasée par lui.
    state = const AsyncLoading();
    state = await AsyncValue.guard<void>(
      () async => throw const PostgrestException(
        message: 'Code invalide ou déjà utilisé.',
        code: 'P0001',
      ),
    );
    return null;
  }
}

// Constaté le 17/10/2026 dans Chrome : un QR refusé, resté dans le cadre,
// repartait au serveur à chaque image — 32 refus identiques en 3 s, autant
// d'alertes empilées.
void main() {
  testWidgets('un code refusé ne repart pas au serveur à chaque image', (
    tester,
  ) async {
    final envois = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courierControllerProvider.overrideWith(() => _RefuseTout(envois)),
        ],
        child: const MaterialApp(
          home: DeliveryScanScreen(
            deliveryId: 'course-1',
            expected: DeliveryCodeKind.delivery,
          ),
        ),
      ),
    );

    final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
    Future<void> image(String code) async {
      scanner.onDetect!(BarcodeCapture(barcodes: [Barcode(rawValue: code)]));
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Le QR refusé reste dans le cadre pendant trente images.
    for (var i = 0; i < 30; i++) {
      await image('CODE-A');
    }
    expect(envois, ['CODE-A'], reason: 'un seul envoi pour le même code');
    expect(find.text('Code invalide ou déjà utilisé.'), findsOneWidget);

    // Après la pause, le même code repart : le livreur a pu corriger sur
    // place ce qui le faisait refuser.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 3100)),
    );
    await image('CODE-A');
    expect(envois, ['CODE-A', 'CODE-A']);

    // Un autre code passe tout de suite.
    await image('CODE-B');
    expect(envois, ['CODE-A', 'CODE-A', 'CODE-B']);
  });
}
