@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/core/mock_data/malian_locations.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/suppliers/data/datasources/supabase_supplier_datasource.dart';
import 'package:mtc_app/features/suppliers/data/repositories/supabase_supplier_repository.dart';
import 'package:mtc_app/features/suppliers/presentation/controllers/supplier_account_controller.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

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
    'SupplierRepository.updateStorefront replaces every editable field at '
    'once, and setOpen flips isOpen independently',
    () async {
      // Writing to `suppliers` requires an authenticated owner session —
      // RLS (see BACKEND_MIGRATION_PROGRESS.md, Lot 3/4) — even when
      // calling the repository directly rather than through the
      // controller.
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final repo = container.read(supplierRepositoryProvider);

      await repo.updateStorefront(
        supplierId: DemoIds.supplierBogolanBamako,
        businessName: 'Bogolan Bamako',
        description: 'Tissus traditionnels tissés main.',
        bannerUrl: '/tmp/banner.jpg',
        publicPhoneNumbers: const ['+22370000000', '+22370000001'],
        openingHoursLabel: 'Lun-Sam 8h-18h',
      );
      await repo.updateLocation(
        supplierId: DemoIds.supplierBogolanBamako,
        fullAddress: 'Marché de Médine, Bamako',
        addressLatitude: 12.6,
        addressLongitude: -8.0,
        deliveryZones: const ['Bamako', 'Kati'],
      );

      final updated = await repo.getById(DemoIds.supplierBogolanBamako);
      expect(updated.description, 'Tissus traditionnels tissés main.');
      expect(updated.fullAddress, 'Marché de Médine, Bamako');
      expect(updated.publicPhoneNumbers, ['+22370000000', '+22370000001']);
      expect(updated.deliveryZones, ['Bamako', 'Kati']);
      expect(updated.openingHoursLabel, 'Lun-Sam 8h-18h');
      expect(updated.isOpen, isTrue); // untouched by updateStorefront

      await repo.setOpen(supplierId: DemoIds.supplierBogolanBamako, isOpen: false);
      final closed = await repo.getById(DemoIds.supplierBogolanBamako);
      expect(closed.isOpen, isFalse);
      // updateStorefront fields survive a setOpen call untouched.
      expect(closed.description, 'Tissus traditionnels tissés main.');
    },
  );

  // Le point de retrait vient désormais de la carte, posé par le
  // fournisseur. Avant, il était déduit du **nom de la ville** : toutes les
  // boutiques de Bamako partageaient le même point, et le livreur était
  // envoyé au centre-ville quelle que soit la boutique.
  test(
    'updateLocation enregistre le point posé sur la carte, et ne l\'écrase '
    'pas quand aucun nouveau point n\'est fourni',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      const pose = LatLng(12.6601, -7.9712);
      final ok = await container
          .read(supplierAccountControllerProvider.notifier)
          .updateLocation(
            fullAddress: 'Rue 123, Bamako',
            pickupPoint: pose,
            deliveryZones: const ['Bamako'],
          );
      expect(ok, isTrue);

      final repository = container.read(supplierRepositoryProvider);
      var updated = await repository.getById(DemoIds.supplierBogolanBamako);
      expect(updated.fullAddress, 'Rue 123, Bamako');
      expect(updated.addressLatitude, closeTo(pose.latitude, 0.00001));
      expect(updated.addressLongitude, closeTo(pose.longitude, 0.00001));
      // Et surtout : ce n'est pas le centre de Bamako.
      expect(
        updated.addressLatitude,
        isNot(closeTo(MalianCity.bamako.coordinates.latitude, 0.0001)),
      );

      // Deuxième enregistrement sans nouveau point — par exemple le
      // fournisseur ne change que ses zones. Le repère doit survivre.
      await container
          .read(supplierAccountControllerProvider.notifier)
          .updateLocation(
            fullAddress: 'Rue 123, Bamako',
            pickupPoint: null,
            deliveryZones: const ['Bamako', 'Kati'],
          );

      updated = await repository.getById(DemoIds.supplierBogolanBamako);
      expect(updated.addressLatitude, closeTo(pose.latitude, 0.00001));
      expect(updated.deliveryZones, ['Bamako', 'Kati']);
    },
  );

  // La raison d'être du découpage en deux écritures. « Profil » et
  // « Localisation » sont deux écrans, chacun avec son « Enregistrer ».
  // S'ils écrivaient les mêmes colonnes, celui qui aurait les données les plus
  // anciennes en mémoire effacerait le travail de l'autre — et le
  // fournisseur ne verrait rien, puisque chaque écran affiche ce qu'il
  // vient de sauver.
  test(
    'enregistrer la vitrine ne touche pas à la localisation, et inversement',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final controller = container.read(
        supplierAccountControllerProvider.notifier,
      );
      final repository = container.read(supplierRepositoryProvider);

      await controller.updateLocation(
        fullAddress: 'Rue 123, Bamako',
        pickupPoint: const LatLng(12.6601, -7.9712),
        deliveryZones: const ['Bamako'],
      );
      await controller.updateStorefront(
        businessName: 'Bogolan Bamako',
        description: 'Une description toute neuve.',
        bannerUrl: null,
        publicPhoneNumbers: const ['+22370000003'],
        openingHoursLabel: 'Lun-Ven 9h-17h',
      );

      var updated = await repository.getById(DemoIds.supplierBogolanBamako);
      expect(updated.description, 'Une description toute neuve.');
      // L'adresse et le repère ont survécu à l'enregistrement de la vitrine.
      expect(updated.fullAddress, 'Rue 123, Bamako');
      expect(updated.addressLatitude, closeTo(12.6601, 0.00001));
      expect(updated.deliveryZones, ['Bamako']);

      // Et dans l'autre sens.
      await controller.updateLocation(
        fullAddress: 'Rue 456, Bamako',
        pickupPoint: null,
        deliveryZones: const ['Bamako', 'Kati'],
      );

      updated = await repository.getById(DemoIds.supplierBogolanBamako);
      expect(updated.fullAddress, 'Rue 456, Bamako');
      expect(updated.description, 'Une description toute neuve.');
      expect(updated.openingHoursLabel, 'Lun-Ven 9h-17h');
      expect(updated.publicPhoneNumbers, ['+22370000003']);
    },
  );

  test('le nom de la boutique est modifiable depuis « Profil »', () async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: 'fournisseur1', password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final ok = await container
        .read(supplierAccountControllerProvider.notifier)
        .updateStorefront(
          businessName: 'Bogolan Bamako — Médine',
          description: null,
          bannerUrl: null,
          publicPhoneNumbers: const [],
          openingHoursLabel: null,
        );
    expect(ok, isTrue);

    final updated = await container
        .read(supplierRepositoryProvider)
        .getById(DemoIds.supplierBogolanBamako);
    expect(updated.businessName, 'Bogolan Bamako — Médine');
  });

  test(
    'SupplierAccountController.setOpen resolves the operating supplier '
    'automatically',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final ok = await container
          .read(supplierAccountControllerProvider.notifier)
          .setOpen(false);
      expect(ok, isTrue);

      final updated = await container
          .read(supplierRepositoryProvider)
          .getById(DemoIds.supplierBogolanBamako);
      expect(updated.isOpen, isFalse);
    },
  );

  // « Mon profil se réinitialise quand je me déconnecte. »
  //
  // Il ne se réinitialisait pas : il n'était jamais relu.
  // `supplierDetailProvider` est un `FutureProvider` sans `autoDispose`, et
  // le `ProviderScope` est posé à la racine de l'app — sa valeur survit donc
  // à la navigation **et** à la déconnexion. La base prenait bien la
  // modification ; l'écran continuait d'afficher l'ancienne.
  test(
    'la fiche en cache est relue après un enregistrement',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Première lecture : c'est elle qui remplit le cache.
      final avant = await container.read(
        supplierDetailProvider(DemoIds.supplierBogolanBamako).future,
      );

      await container
          .read(supplierAccountControllerProvider.notifier)
          .updateStorefront(
            businessName: 'Bogolan Bamako',
            description: 'Une description que le fournisseur vient de taper.',
            bannerUrl: null,
            publicPhoneNumbers: const ['+22370000009'],
            openingHoursLabel: 'Lun-Sam 9h-19h',
          );

      final apres = await container.read(
        supplierDetailProvider(DemoIds.supplierBogolanBamako).future,
      );
      expect(
        apres.description,
        'Une description que le fournisseur vient de taper.',
        reason: 'sans invalidation, on relirait la valeur d\'avant',
      );
      expect(apres.description, isNot(avant.description));
      expect(apres.openingHoursLabel, 'Lun-Sam 9h-19h');

      // Et la localisation, écrite par l'autre écran, rafraîchit aussi.
      await container
          .read(supplierAccountControllerProvider.notifier)
          .updateLocation(
            fullAddress: 'Rue 789, Bamako',
            pickupPoint: null,
            deliveryZones: const ['Bamako'],
          );
      final apresLocalisation = await container.read(
        supplierDetailProvider(DemoIds.supplierBogolanBamako).future,
      );
      expect(apresLocalisation.fullAddress, 'Rue 789, Bamako');
      // Et la vitrine n'a pas été perdue au passage.
      expect(
        apresLocalisation.description,
        'Une description que le fournisseur vient de taper.',
      );
    },
  );

  // « Le profil doit être visible chez le client. »
  //
  // Il l'est — `supplier_profile_screen.dart` affiche bannière, description,
  // adresse, horaires, téléphones et zones. Ce qui manquait, c'était que la
  // modification y parvienne : tant que la fiche en cache n'était pas
  // relue, le fournisseur voyait son ancien profil et concluait que rien
  // n'avait été enregistré.
  //
  // Ce test suit le chemin complet, d'une session à l'autre.
  test('ce que le fournisseur enregistre, le client le lit', () async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: 'fournisseur1', password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await container
        .read(supplierAccountControllerProvider.notifier)
        .updateStorefront(
          businessName: 'Bogolan Bamako',
          description: 'Tissés main, teinture végétale.',
          bannerUrl: null,
          publicPhoneNumbers: const ['+22376000000'],
          openingHoursLabel: 'Lun-Sam 8h-18h',
        );
    await container
        .read(supplierAccountControllerProvider.notifier)
        .updateLocation(
          fullAddress: 'Marché de Médine, Bamako',
          pickupPoint: null,
          deliveryZones: const ['Bamako', 'Kati'],
        );

    // Une autre session, un autre rôle : c'est ce que voit un visiteur.
    final visiteur = createTestSupabaseClient();
    addTearDown(visiteur.dispose);
    final vu = await SupabaseSupplierRepository(
      SupabaseSupplierDatasource(visiteur),
    ).getById(DemoIds.supplierBogolanBamako);

    expect(vu.description, 'Tissés main, teinture végétale.');
    expect(vu.fullAddress, 'Marché de Médine, Bamako');
    expect(vu.openingHoursLabel, 'Lun-Sam 8h-18h');
    expect(vu.publicPhoneNumbers, ['+22376000000']);
    expect(vu.deliveryZones, ['Bamako', 'Kati']);
  });
}
