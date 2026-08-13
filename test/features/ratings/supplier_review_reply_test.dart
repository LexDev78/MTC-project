@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/ratings/presentation/controllers/review_controller.dart';
import 'package:mtc_app/features/ratings/presentation/providers/review_providers.dart';

import '../../support/supabase_test_harness.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetAndSeed();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'ReviewRepository.reply records the reply on the right supplier\'s '
    'review, and rejects a supplier trying to reply to someone else\'s',
    () async {
      final repo = container.read(reviewRepositoryProvider);

      await repo.reply(
        reviewId: 'seed-review-1',
        supplierId: DemoIds.supplierBogolanBamako,
        reply: 'Merci pour votre confiance !',
      );

      final reviews = await repo
          .watchForSupplier(DemoIds.supplierBogolanBamako)
          .first;
      final review = reviews.firstWhere((r) => r.id == 'seed-review-1');
      expect(review.supplierReply, 'Merci pour votre confiance !');
      expect(review.supplierRepliedAt, isNotNull);

      await expectLater(
        repo.reply(
          reviewId: 'seed-review-1',
          supplierId: DemoIds.supplierAlimentationSegou,
          reply: "Ce n'est pas mon avis",
        ),
        throwsA(isA<ValidationException>()),
      );
    },
  );

  test(
    'ReviewController.replyToReview resolves the operating supplier '
    'automatically — the caller never passes a supplierId',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final ok = await container
          .read(reviewControllerProvider.notifier)
          .replyToReview(
            reviewId: 'seed-review-1',
            reply: 'Merci beaucoup !',
          );
      expect(ok, isTrue);

      final reviews = await container
          .read(reviewRepositoryProvider)
          .watchForSupplier(DemoIds.supplierBogolanBamako)
          .first;
      expect(
        reviews.firstWhere((r) => r.id == 'seed-review-1').supplierReply,
        'Merci beaucoup !',
      );
    },
  );

  test('re-replying edits the existing reply rather than duplicating it', () async {
    final repo = container.read(reviewRepositoryProvider);

    await repo.reply(
      reviewId: 'seed-review-1',
      supplierId: DemoIds.supplierBogolanBamako,
      reply: 'Premier brouillon.',
    );
    await repo.reply(
      reviewId: 'seed-review-1',
      supplierId: DemoIds.supplierBogolanBamako,
      reply: 'Version corrigée.',
    );

    final reviews = await repo
        .watchForSupplier(DemoIds.supplierBogolanBamako)
        .first;
    expect(
      reviews.where((r) => r.id == 'seed-review-1'),
      hasLength(1),
    );
    expect(
      reviews.firstWhere((r) => r.id == 'seed-review-1').supplierReply,
      'Version corrigée.',
    );
  });
}
