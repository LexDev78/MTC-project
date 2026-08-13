@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/comments/presentation/widgets/product_comments_modal.dart';

import '../../support/supabase_test_harness.dart';

Future<void> _openModal(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
        currentUserProvider.overrideWith(
          (ref) => Stream.value(
            AppUser.client(
              id: 'test-client',
              displayName: 'Testeur',
              usernameOrPhone: 'testeur',
              phoneNumber: '+22300000000',
              createdAt: DateTime(2024, 1, 1),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () =>
                    showProductCommentsModal(context, productId: 'product-001'),
                child: const Text('Ouvrir les commentaires'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Ouvrir les commentaires'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'shows the seeded comment thread with reply, like and attachment '
    'controls',
    (tester) async {
      await _openModal(tester);

      // Seeded top-level comment (product-001) + its seeded reply.
      expect(
        find.textContaining('Le tissu est-il aussi solide'),
        findsOneWidget,
      );
      expect(find.text('Bogolan Bamako'), findsWidgets);
      expect(find.text('Fournisseur'), findsWidgets);
      expect(find.text('Répondre'), findsWidgets);

      // The composer offers text, photo, and voice input.
      expect(find.byIcon(Icons.image_outlined), findsWidgets);
      expect(find.byIcon(Icons.mic_none_rounded), findsWidgets);
    },
  );

  testWidgets('tapping the like button toggles the like count', (
    tester,
  ) async {
    await _openModal(tester);

    // "Magnifiques couleurs..." was seeded with one like already.
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    // Tapping again un-likes it.
    await tester.tap(find.byIcon(Icons.favorite_rounded).first);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('posting a top-level text comment adds it to the thread', (
    tester,
  ) async {
    await _openModal(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Ajouter un commentaire...'),
      'Est-ce disponible en grande taille ?',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(
      find.text('Est-ce disponible en grande taille ?'),
      findsOneWidget,
    );
  });
}
