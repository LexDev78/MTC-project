@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';

import '../../support/supabase_test_harness.dart';

Future<void> _openCheckout(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
      ],
      child: const MtcApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 400));

  await tester.tap(find.text('Commencer'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  // client2 (Moussa) has a pre-seeded cart — see checkout_flow_test.dart.
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'client2');
  await tester.enterText(fields.at(1), 'password123');
  await tester.tap(find.text('Se connecter'));
  await tester.pumpAndSettle(const Duration(seconds: 1));

  await tester.tap(find.byIcon(Icons.shopping_cart_outlined).first);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Commander'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'checkout defaults to home delivery with the rich form, and switching '
    'to pickup-point swaps in the point picker',
    (tester) async {
      await _openCheckout(tester);

      expect(find.text('Point de livraison'), findsOneWidget);
      expect(find.text('Livraison à domicile'), findsOneWidget);

      // Home delivery is the default — its form fields are visible.
      expect(find.text('Adresse de livraison'), findsOneWidget);
      expect(find.text('Commande prioritaire'), findsOneWidget);
      expect(find.text('Créneau de livraison'), findsOneWidget);
      expect(find.text('10:00 - 12:00'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text('Choisissez un point de retrait'), findsNothing);

      // In home-delivery mode, each supplier group still offers "Livraison
      // par le fournisseur", with a note that the supplier will be in touch
      // about delivery and its (separate) cost.
      await tester.scrollUntilVisible(
        find.text('Livraison par le fournisseur'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Livraison par le fournisseur'), findsWidgets);
      expect(
        find.text(
          'Le fournisseur vous contactera pour la livraison et les frais inclus.',
        ),
        findsWidgets,
      );
      // Checkboxes, not radio buttons, for the per-supplier delivery choice.
      expect(find.byType(CheckboxListTile), findsWidgets);
      expect(find.byType(RadioListTile<DeliveryMode>), findsNothing);

      // Scroll back up to reach the fulfillment-method selector, then
      // switch to pickup-point — it swaps the form out for the point list.
      await tester.scrollUntilVisible(
        find.text('Point de livraison'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Point de livraison'));
      await tester.pumpAndSettle();

      expect(find.text('Choisissez un point de retrait'), findsOneWidget);
      expect(find.text('Adresse de livraison'), findsNothing);
      expect(find.text('Commande prioritaire'), findsNothing);
      // The mocked pickup points are listed.
      expect(find.textContaining('Agence MTC'), findsWidgets);

      // No per-supplier delivery-mode choice — MTC always fetches the
      // parcel from the supplier once a pickup point is chosen.
      expect(find.text('Livraison par le fournisseur'), findsNothing);
      expect(
        find.text(
          'Le fournisseur vous contactera pour la livraison et les frais inclus.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'adding then removing a second phone number toggles the "add" button '
    'back in',
    (tester) async {
      await _openCheckout(tester);

      expect(find.text('Ajouter un autre numéro'), findsOneWidget);

      await tester.tap(find.text('Ajouter un autre numéro'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Autre numéro de téléphone'),
        '70123456',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('70123456'), findsOneWidget);
      expect(find.text('Ajouter un autre numéro'), findsNothing);

      await tester.tap(find.byTooltip('Retirer ce numéro'));
      await tester.pumpAndSettle();

      expect(find.text('Ajouter un autre numéro'), findsOneWidget);
      expect(find.text('70123456'), findsNothing);
    },
  );

  testWidgets(
    'writing a text message to the supplier shows it on the row, and it '
    'can be cleared',
    (tester) async {
      await _openCheckout(tester);

      expect(find.text('Message pour le fournisseur'), findsOneWidget);

      await tester.tap(find.text('Message pour le fournisseur'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'Sonnez deux fois, merci.',
      );
      await tester.pump();

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Sonnez deux fois, merci.'), findsOneWidget);

      await tester.tap(find.byTooltip('Supprimer'));
      await tester.pump();

      expect(find.text('Message pour le fournisseur'), findsOneWidget);
    },
  );

  testWidgets(
    'switching payment to "Maintenant" prompts for payment before '
    'confirming, and the button label reflects it',
    (tester) async {
      await _openCheckout(tester);

      // The payment section sits below the fold in the checkout ListView.
      await tester.scrollUntilVisible(
        find.text('Maintenant'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Maintenant'), findsOneWidget);
      expect(find.text('À la livraison'), findsOneWidget);
      expect(find.text('Confirmer la commande'), findsOneWidget);

      await tester.tap(find.text('Maintenant'));
      await tester.pumpAndSettle();

      expect(
        find.text('Le paiement vous sera demandé à la confirmation.'),
        findsOneWidget,
      );
      expect(find.text('Payer et commander'), findsOneWidget);

      await tester.tap(find.text('Payer et commander'));
      await tester.pumpAndSettle();

      // The Mobile Money sheet opens with both providers offered.
      expect(find.text('Payer avec Mobile Money'), findsOneWidget);
      expect(find.text('Orange Money'), findsOneWidget);
      expect(find.text('Moov Money'), findsOneWidget);
    },
  );
}
