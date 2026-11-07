@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart'
    show SupplierType;
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

    // Settle the initial (signed-out) session before any test signs up.
    await container.read(currentUserProvider.future);
  });

  test(
    'registering as an individual (fournisseur libre) starts unverified, '
    'keeps its legal type, and gets a public SupplierProfile',
    () async {
      final success = await container
          .read(authControllerProvider.notifier)
          .signUpSupplierTiers(
            displayName: 'Aminata Diallo',
            usernameOrPhone: 'nouveau-libre',
            phoneNumber: '+22376009001',
            password: 'password123',
            businessName: 'Couture Aminata',
            city: 'Bamako',
            legalType: SupplierLegalType.individual,
          );

      expect(success, isTrue);

      // `currentUserProvider.future` only resolves once more after this
      // point if the underlying real `onAuthStateChange` event hasn't
      // already landed — reading it again right away can still return the
      // signed-out value it resolved to in `setUp`. A short real delay
      // lets that event propagate before reading the settled state.
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final user = container.read(currentUserProvider).valueOrNull;
      expect(user, isA<SupplierTiersUser>());
      final supplier = user! as SupplierTiersUser;
      expect(supplier.verificationStatus, VerificationStatus.unverified);
      expect(supplier.legalType, SupplierLegalType.individual);
      expect(supplier.businessName, 'Couture Aminata');

      final profile = await container
          .read(supplierRepositoryProvider)
          .getById(supplier.id);
      expect(profile.businessName, 'Couture Aminata');
      expect(profile.supplierType, SupplierType.tiers);
      expect(profile.legalType, SupplierLegalType.individual);
      expect(profile.verificationStatus, VerificationStatus.unverified);
      expect(profile.productCount, 0);
    },
  );

  test(
    'registering as a company keeps that legal type on both the account '
    'and its public profile',
    () async {
      await container
          .read(authControllerProvider.notifier)
          .signUpSupplierTiers(
            displayName: 'Oumar Sissoko',
            usernameOrPhone: 'nouvelle-societe',
            phoneNumber: '+22376009002',
            password: 'password123',
            businessName: 'Négoce Sissoko SARL',
            city: 'Kayes',
            legalType: SupplierLegalType.company,
          );

      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final user = container.read(currentUserProvider).valueOrNull;
      final supplier = user! as SupplierTiersUser;
      expect(supplier.legalType, SupplierLegalType.company);

      final profile = await container
          .read(supplierRepositoryProvider)
          .getById(supplier.id);
      expect(profile.legalType, SupplierLegalType.company);
    },
  );
}
