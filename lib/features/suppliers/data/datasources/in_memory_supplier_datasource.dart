import 'dart:async';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';

import '../../domain/entities/supplier_profile.dart';

class InMemorySupplierDatasource {
  InMemorySupplierDatasource() {
    _suppliers.addAll(_seed());
  }

  final List<SupplierProfile> _suppliers = [];
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<List<SupplierProfile>> watchAll() {
    return Stream<void>.multi(
      (controller) {
        controller.add(null);
        final subscription = _changesController.stream.listen(controller.add);
        controller.onCancel = subscription.cancel;
      },
      isBroadcast: true,
    ).map((_) => List<SupplierProfile>.unmodifiable(_suppliers));
  }

  SupplierProfile getById(String id) {
    return _suppliers.firstWhere(
      (s) => s.id == id,
      orElse: () => throw NotFoundException('Fournisseur introuvable : $id'),
    );
  }

  void updateVerificationStatus(String supplierId, VerificationStatus status) {
    final index = _suppliers.indexWhere((s) => s.id == supplierId);
    if (index == -1) {
      throw NotFoundException('Fournisseur introuvable : $supplierId');
    }
    _suppliers[index] = _suppliers[index].copyWith(verificationStatus: status);
    _changesController.add(null);
  }

  void adjustProductCount(String supplierId, int delta) {
    final index = _suppliers.indexWhere((s) => s.id == supplierId);
    if (index == -1) {
      throw NotFoundException('Fournisseur introuvable : $supplierId');
    }
    final supplier = _suppliers[index];
    _suppliers[index] = supplier.copyWith(
      productCount: supplier.productCount + delta,
    );
    _changesController.add(null);
  }

  SupplierProfile add(SupplierProfile profile) {
    if (_suppliers.any((s) => s.id == profile.id)) {
      throw ValidationException('Fournisseur déjà existant : ${profile.id}');
    }
    _suppliers.add(profile);
    _changesController.add(null);
    return profile;
  }

  ({double average, int count}) recordReview(String supplierId, int stars) {
    final index = _suppliers.indexWhere((s) => s.id == supplierId);
    if (index == -1) {
      throw NotFoundException('Fournisseur introuvable : $supplierId');
    }

    final supplier = _suppliers[index];
    final newCount = supplier.ratingCount + 1;
    final newAverage =
        ((supplier.ratingAverage * supplier.ratingCount) + stars) / newCount;

    _suppliers[index] = supplier.copyWith(
      ratingAverage: newAverage,
      ratingCount: newCount,
    );
    _changesController.add(null);

    return (average: newAverage, count: newCount);
  }

  List<SupplierProfile> _seed() {
    return const [
      SupplierProfile(
        id: DemoIds.supplierBogolanBamako,
        businessName: 'Bogolan Bamako',
        supplierType: SupplierType.tiers,
        city: 'Bamako',
        ratingAverage: 4.6,
        ratingCount: 132,
        productCount: 4,
        verificationStatus: VerificationStatus.verified,
        legalType: SupplierLegalType.company,
      ),
      SupplierProfile(
        id: DemoIds.supplierTissusMopti,
        businessName: 'Tissus Mopti',
        supplierType: SupplierType.tiers,
        city: 'Mopti',
        ratingAverage: 4.4,
        ratingCount: 76,
        productCount: 3,
        verificationStatus: VerificationStatus.verified,
        legalType: SupplierLegalType.company,
      ),
      SupplierProfile(
        id: DemoIds.supplierArtisanatSikasso,
        businessName: 'Artisanat Sikasso',
        supplierType: SupplierType.tiers,
        city: 'Sikasso',
        ratingAverage: 0,
        ratingCount: 0,
        productCount: 3,
        verificationStatus: VerificationStatus.pending,
        legalType: SupplierLegalType.company,
      ),
      SupplierProfile(
        id: DemoIds.supplierElectroBamako,
        businessName: 'Electro Bamako',
        supplierType: SupplierType.tiers,
        city: 'Bamako',
        ratingAverage: 4.2,
        ratingCount: 54,
        productCount: 4,
        verificationStatus: VerificationStatus.verified,
        legalType: SupplierLegalType.company,
      ),
      SupplierProfile(
        id: DemoIds.supplierAlimentationSegou,
        businessName: 'Alimentation Ségou',
        supplierType: SupplierType.tiers,
        city: 'Ségou',
        ratingAverage: 4.8,
        ratingCount: 210,
        productCount: 4,
        verificationStatus: VerificationStatus.verified,
        legalType: SupplierLegalType.company,
      ),
      SupplierProfile(
        id: DemoIds.supplierMateriauxKoutiala,
        businessName: 'Matériaux Koutiala',
        supplierType: SupplierType.tiers,
        city: 'Koutiala',
        ratingAverage: 3.9,
        ratingCount: 41,
        productCount: 3,
        verificationStatus: VerificationStatus.verified,
        legalType: SupplierLegalType.company,
      ),
      SupplierProfile(
        id: DemoIds.supplierCoutureKayes,
        businessName: 'Couture Kayes',
        supplierType: SupplierType.tiers,
        city: 'Kayes',
        ratingAverage: 0,
        ratingCount: 0,
        productCount: 0,
        verificationStatus: VerificationStatus.unverified,
        legalType: SupplierLegalType.individual,
      ),
      SupplierProfile(
        id: DemoIds.supplierFruitsNiono,
        businessName: 'Fruits Niono',
        supplierType: SupplierType.tiers,
        city: 'Niono',
        ratingAverage: 0,
        ratingCount: 0,
        productCount: 0,
        verificationStatus: VerificationStatus.rejected,
        legalType: SupplierLegalType.company,
      ),
      SupplierProfile(
        id: DemoIds.supplierMtcOfficiel,
        businessName: 'MTC Officiel',
        supplierType: SupplierType.principal,
        city: 'Bamako',
        ratingAverage: 4.9,
        ratingCount: 340,
        productCount: 4,
      ),
    ];
  }
}
