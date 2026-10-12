import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_characteristic.dart';
import '../../domain/entities/product_status.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/stock_movement.dart';
import '../providers/catalog_providers.dart';
import '../providers/characteristic_type_providers.dart';

/// Drives every product-management action for the operating supplier (see
/// `operatingSupplierIdProvider` — the same controller serves both a
/// fournisseur tiers and MTC staff). Cross-repository orchestration
/// (`ProductRepository` + `SupplierRepository`'s product count) lives here,
/// never inside either repository.
class SupplierProductController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createProduct({
    required String name,
    required String description,
    required ProductCategory category,
    required int priceFcfa,
    required int stockQuantity,
    required double weightKg,
    required String city,
    required List<String> imageUrls,
    required bool allowsSelfDelivery,
    required bool allowsMtcDelivery,
    required List<String> sizes,
    required List<String> colors,
    required ProductRegion region,
    int? lowStockThreshold,
    int? compareAtPriceFcfa,
  }) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    final supplierId = ref.read(operatingSupplierIdProvider);
    if (user == null || supplierId == null) return false;

    final SupplierType supplierType;
    final bool isSupplierVerified;
    switch (user) {
      case SupplierTiersUser():
        supplierType = SupplierType.tiers;
        isSupplierVerified =
            user.verificationStatus == VerificationStatus.verified;
      case SupplierPrincipalUser():
        supplierType = SupplierType.principal;
        isSupplierVerified = true;
      case ClientUser():
      case CourierUser():
        // Route-guarded — ni un client ni un livreur n'atteint cet écran.
        return false;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final supplierProfile = await ref
          .read(supplierRepositoryProvider)
          .getById(supplierId);
      await ref
          .read(productRepositoryProvider)
          .createProduct(
            supplierId: supplierId,
            supplierName: supplierProfile.businessName,
            supplierType: supplierType,
            isSupplierVerified: isSupplierVerified,
            name: name,
            description: description,
            category: category,
            priceFcfa: priceFcfa,
            stockQuantity: stockQuantity,
            weightKg: weightKg,
            city: city,
            imageUrls: imageUrls,
            allowsSelfDelivery: allowsSelfDelivery,
            allowsMtcDelivery: allowsMtcDelivery,
            sizes: sizes,
            colors: colors,
            region: region,
            lowStockThreshold: lowStockThreshold,
            compareAtPriceFcfa: compareAtPriceFcfa,
          );
      await ref
          .read(supplierRepositoryProvider)
          .adjustProductCount(supplierId: supplierId, delta: 1);
    });
    return !state.hasError;
  }

  Future<bool> updateProduct(Product product) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(productRepositoryProvider).updateProduct(product),
    );
    return !state.hasError;
  }

  /// Takes the full [product] (not just its id) so a transition *to*
  /// `archived` can both apply it and, in the same guarded block, decrement
  /// the storefront's product count exactly once — comparing against the
  /// product's current status rather than assuming the caller never taps
  /// "archive" twice on an already-archived item.
  Future<bool> setStatus({
    required Product product,
    required ProductStatus status,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(productRepositoryProvider)
          .setStatus(id: product.id, status: status);
      if (status == ProductStatus.archived &&
          product.status != ProductStatus.archived) {
        await ref
            .read(supplierRepositoryProvider)
            .adjustProductCount(supplierId: product.supplierId, delta: -1);
      }
    });
    return !state.hasError;
  }

  Future<bool> adjustStock({
    required String productId,
    required int quantityDelta,
    required StockMovementReason reason,
    String? variantId,
    String? note,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final productRepository = ref.read(productRepositoryProvider);
      await productRepository.adjustStock(
        id: productId,
        quantityDelta: quantityDelta,
        reason: reason,
        variantId: variantId,
        note: note,
      );

      // `updated.stockQuantity` is correct whether this was a product- or
      // variant-level correction: the aggregate trigger
      // (`0018_product_variants.sql`) already folds a variant's stock back
      // into the product's own `stock_quantity` before this re-fetch runs.
      final updated = await productRepository.getById(productId);
      final threshold = updated.lowStockThreshold;
      if (threshold != null && updated.stockQuantity <= threshold) {
        await ref
            .read(notificationRepositoryProvider)
            .add(
              userId: updated.supplierId,
              type: NotificationType.lowStock,
              title: 'Stock faible',
              body: '${updated.name} : ${updated.stockQuantity} en stock',
            );
      }
    });
    return !state.hasError;
  }

  /// Full replace of [productId]'s characteristics/options/variants — see
  /// `ProductRepository.replaceCharacteristicsAndVariants`.
  Future<bool> saveCharacteristicsAndVariants({
    required String productId,
    required List<ProductCharacteristic> characteristics,
    required List<ProductVariant> variants,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(productRepositoryProvider)
          .replaceCharacteristicsAndVariants(
            productId: productId,
            characteristics: characteristics,
            variants: variants,
          ),
    );
    return !state.hasError;
  }

  /// Submits a new characteristic type proposal for staff to review — see
  /// `CharacteristicTypeReviewController` for the approve/reject side.
  Future<bool> proposeCharacteristicType(String label) async {
    final supplierId = ref.read(operatingSupplierIdProvider);
    if (supplierId == null) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(characteristicTypeRepositoryProvider)
          .propose(supplierId: supplierId, label: label),
    );
    return !state.hasError;
  }
}

final supplierProductControllerProvider =
    AsyncNotifierProvider<SupplierProductController, void>(
      SupplierProductController.new,
    );
