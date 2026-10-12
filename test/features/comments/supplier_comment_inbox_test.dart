@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/supplier_product_providers.dart';
import 'package:mtc_app/features/comments/presentation/controllers/comment_controller.dart';
import 'package:mtc_app/features/comments/presentation/providers/comment_providers.dart';
import 'package:mtc_app/features/comments/presentation/providers/supplier_comment_inbox_providers.dart';

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
    'watchForSupplier only returns comments left on that supplier\'s own '
    'products, and nothing for a supplier with none',
    () async {
      final comments = await container
          .read(productCommentRepositoryProvider)
          .watchForSupplier(DemoIds.supplierBogolanBamako)
          .first;
      expect(comments, hasLength(3));
      expect(comments.every((c) => c.supplierId == DemoIds.supplierBogolanBamako), isTrue);

      final none = await container
          .read(productCommentRepositoryProvider)
          .watchForSupplier(DemoIds.supplierElectroBamako)
          .first;
      expect(none, isEmpty);
    },
  );

  test(
    'CommentController.addComment resolves supplierId from the product '
    'automatically — the caller never has to know it',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'client1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final ok = await container
          .read(commentControllerProvider.notifier)
          .addComment(productId: DemoIds.product001, text: 'Une nouvelle question.');
      expect(ok, isTrue);

      final comments = await container
          .read(productCommentRepositoryProvider)
          .watchForSupplier(DemoIds.supplierBogolanBamako)
          .first;
      expect(
        comments.any(
          (c) =>
              c.text == 'Une nouvelle question.' &&
              c.supplierId == DemoIds.supplierBogolanBamako,
        ),
        isTrue,
      );
    },
  );

  test(
    'the inbox projection groups top-level comments with their replies and '
    'resolves the product name, flagging which ones already got a supplier '
    'reply',
    () async {
      // Both dependencies are `autoDispose` — without a listener held open
      // across the two reads below, either can be torn down the instant its
      // own `.future` resolves (no more subscribers), so
      // `supplierCommentInboxProvider`'s `ref.watch` a moment later can end
      // up creating a *fresh* instance (back to `AsyncLoading`) instead of
      // reusing the one just awaited. `container.listen` keeps both alive
      // for the rest of the test, same as a still-mounted screen would.
      final commentsSub = container.listen(
        supplierProductCommentsProvider(DemoIds.supplierBogolanBamako),
        (_, _) {},
      );
      addTearDown(commentsSub.close);
      final productsSub = container.listen(
        myProductsProvider(DemoIds.supplierBogolanBamako),
        (_, _) {},
      );
      addTearDown(productsSub.close);

      await container.read(
        supplierProductCommentsProvider(DemoIds.supplierBogolanBamako).future,
      );
      await container.read(
        myProductsProvider(DemoIds.supplierBogolanBamako).future,
      );

      final itemsAsync = container.read(
        supplierCommentInboxProvider(DemoIds.supplierBogolanBamako),
      );
      final items = itemsAsync.value!;

      // Two top-level seeded comments on product-001 ("comment-002" is a
      // reply, not top-level, so it doesn't get its own entry).
      expect(items, hasLength(2));
      expect(items.every((i) => i.productName == 'Tissu Bogolan traditionnel'), isTrue);

      final answered = items.firstWhere((i) => i.comment.id == DemoIds.comment001);
      expect(answered.hasSupplierReply, isTrue);
      expect(answered.replies, hasLength(1));

      final unanswered = items.firstWhere((i) => i.comment.id == DemoIds.comment003);
      expect(unanswered.hasSupplierReply, isFalse);
      expect(unanswered.replies, isEmpty);
    },
  );
}
