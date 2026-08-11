import 'dart:async';

import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/core/mock_data/malian_locations.dart';
import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/address.dart';

class InMemoryAddressDatasource {
  InMemoryAddressDatasource() {
    final bamako = MalianCity.bamako.coordinates;
    _addresses.addAll([
      Address(
        id: IdGenerator.next(),
        userId: DemoIds.clientAwa,
        label: 'Domicile',
        city: 'Bamako',
        details: 'Hippodrome, Rue 12, Porte 34',
        latitude: bamako.latitude + 0.01,
        longitude: bamako.longitude + 0.01,
      ),
      Address(
        id: IdGenerator.next(),
        userId: DemoIds.clientMoussa,
        label: 'Domicile',
        city: 'Bamako',
        details: 'Badalabougou, Porte 45',
        latitude: bamako.latitude - 0.015,
        longitude: bamako.longitude - 0.008,
      ),
    ]);
  }

  final List<Address> _addresses = [];
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<List<Address>> watchAll() {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changesController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map((_) => List<Address>.unmodifiable(_addresses));
  }

  void add(Address address) {
    _addresses.add(address);
    _changesController.add(null);
  }

  void remove(String addressId) {
    _addresses.removeWhere((a) => a.id == addressId);
    _changesController.add(null);
  }
}
