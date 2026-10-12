@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_characteristic_type.dart';
import 'package:mtc_app/features/catalog/presentation/controllers/characteristic_type_review_controller.dart';
import 'package:mtc_app/features/catalog/presentation/controllers/supplier_product_controller.dart';
import 'package:mtc_app/features/catalog/presentation/providers/characteristic_type_providers.dart';

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

  /// Attend que [provider] reflète [condition].
  ///
  /// Les deux listes de ce fichier sont des `StreamProvider` branchés sur un
  /// refetch déclenché *après* l'écriture (voir
  /// `SupabaseCharacteristicTypeDatasource._watch`) : au retour du `await` de
  /// la décision, la requête de rafraîchissement est encore en vol et la
  /// valeur en cache est forcément l'ancienne. Lire une fois et conclure
  /// revient à exiger du flux qu'il soit déjà à jour — ce que l'architecture
  /// ne promet nulle part, et qui fait échouer la lecture juste après une
  /// décision alors que l'écran, lui, se met bien à jour une fraction de
  /// seconde plus tard. Borné : si la condition n'arrive jamais, le test
  /// échoue (c'est alors une vraie anomalie, pas une question de timing).
  Future<List<ProductCharacteristicType>> attendreQue(
    StreamProvider<List<ProductCharacteristicType>> provider,
    bool Function(List<ProductCharacteristicType>) condition, {
    int tentatives = 30,
  }) async {
    for (var i = 0; i < tentatives; i++) {
      final valeur = container.read(provider).valueOrNull;
      if (valeur != null && condition(valeur)) return valeur;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('Le flux ne reflète toujours pas la décision après 3 s.');
  }

  Future<void> login(String usernameOrPhone) async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: usernameOrPhone, password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  // Regression test for a real bug found in manual testing: `resetAndSeed()`
  // (`test_reset_and_seed()`, `0002_test_reset_fn.sql`) does
  // `truncate table ... public.suppliers ... cascade` — since
  // `product_characteristic_types.proposed_by_supplier_id` references
  // `suppliers`, TRUNCATE CASCADE wiped the *entire* table (not just rows
  // with a non-null FK), silently deleting the 4 pre-approved seed types
  // every single reset. The supplier-facing variant manager screen showed
  // no characteristics to pick from as a result. Fixed in
  // `0020_reseed_characteristic_types.sql` by re-inserting them inside
  // `test_reset_and_seed()` itself.
  test(
    'the 4 pre-approved characteristic types survive a reset',
    () async {
      final types = await container.read(approvedCharacteristicTypesProvider.future);
      expect(types.map((t) => t.id).toSet(), {'couleur', 'stockage', 'taille', 'poids'});
      expect(types.every((t) => t.status == CharacteristicTypeStatus.approved), isTrue);
    },
  );

  test(
    'a proposed type is pending and invisible to the approved list until a '
    'staff member decides on it',
    () async {
      await login('fournisseur1');

      final ok = await container
          .read(supplierProductControllerProvider.notifier)
          .proposeCharacteristicType('Matière');
      expect(ok, isTrue);

      final approved = await container.read(approvedCharacteristicTypesProvider.future);
      expect(approved.any((t) => t.label == 'Matière'), isFalse);

      await login('agent1');
      final queue = await container.read(characteristicTypeQueueProvider.future);
      expect(queue.any((t) => t.label == 'Matière' && t.status == CharacteristicTypeStatus.pending), isTrue);
    },
  );

  test(
    'CharacteristicTypeReviewController.approve moves the type into the '
    'approved list and notifies the proposer',
    () async {
      await login('fournisseur1');
      await container
          .read(supplierProductControllerProvider.notifier)
          .proposeCharacteristicType('Matière');

      await login('agent1');
      final proposal = (await container.read(characteristicTypeQueueProvider.future))
          .firstWhere((t) => t.label == 'Matière');

      final ok = await container
          .read(characteristicTypeReviewControllerProvider.notifier)
          .review(id: proposal.id, approve: true);
      expect(ok, isTrue);

      final approved = await container.read(approvedCharacteristicTypesProvider.future);
      expect(approved.any((t) => t.label == 'Matière'), isTrue);

      final notifications = await fetchNotificationsForUserAsAdmin(
        DemoIds.supplierBogolanBamako,
      );
      expect(
        notifications.any((n) => n['type'] == 'characteristic_type_decision'),
        isTrue,
      );
    },
  );

  test(
    'CharacteristicTypeReviewController.reject records the reason and keeps '
    'the type out of the approved list',
    () async {
      await login('fournisseur1');
      await container
          .read(supplierProductControllerProvider.notifier)
          .proposeCharacteristicType('Odeur');

      await login('agent1');
      final proposal = (await container.read(characteristicTypeQueueProvider.future))
          .firstWhere((t) => t.label == 'Odeur');

      await container
          .read(characteristicTypeReviewControllerProvider.notifier)
          .review(
            id: proposal.id,
            approve: false,
            reason: 'Pas pertinent pour ce catalogue.',
          );

      final approved = await container.read(approvedCharacteristicTypesProvider.future);
      expect(approved.any((t) => t.label == 'Odeur'), isFalse);

      final queueAfter = await attendreQue(
        characteristicTypeQueueProvider,
        (types) => !types.any((t) => t.label == 'Odeur'),
      );
      expect(queueAfter.any((t) => t.label == 'Odeur'), isFalse);
    },
  );
}
