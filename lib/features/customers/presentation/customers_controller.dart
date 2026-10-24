import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../domain/customer_details.dart';
import '../domain/customer_summary.dart';

/// Filter toggle: only active customers or all customers.
class CustomersFilterActiveOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool val) => state = val;
}

final customersFilterActiveOnlyProvider =
    NotifierProvider<CustomersFilterActiveOnlyNotifier, bool>(
  CustomersFilterActiveOnlyNotifier.new,
);

/// Search query string for customers/vehicles.
class CustomersSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String val) => state = val;
}

final customersSearchQueryProvider =
    NotifierProvider<CustomersSearchQueryNotifier, String>(
  CustomersSearchQueryNotifier.new,
);

/// Selected customer ID in the master list.
class SelectedCustomerIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? id) => state = id;
}

final selectedCustomerIdProvider =
    NotifierProvider<SelectedCustomerIdNotifier, int?>(
  SelectedCustomerIdNotifier.new,
);

/// AsyncNotifier for the list of customer summaries with search and filter.
class CustomersListNotifier extends AsyncNotifier<List<CustomerSummary>> {
  @override
  Future<List<CustomerSummary>> build() async {
    final onlyActive = ref.watch(customersFilterActiveOnlyProvider);
    final search = ref.watch(customersSearchQueryProvider);
    final repo = ref.watch(customersRepositoryProvider);

    final list = await repo.getAllWithSummaries(
      onlyActive: onlyActive,
      search: search.trim().isEmpty ? null : search.trim(),
    );

    // If currently selected customer is not in the list or null, auto-select first
    final currentSelected = ref.read(selectedCustomerIdProvider);
    if (list.isNotEmpty) {
      if (currentSelected == null || !list.any((c) => c.customer.id == currentSelected)) {
        Future.microtask(() {
          ref.read(selectedCustomerIdProvider.notifier).set(list.first.customer.id);
        });
      }
    } else {
      Future.microtask(() {
        ref.read(selectedCustomerIdProvider.notifier).set(null);
      });
    }

    return list;
  }

  Future<void> refreshList() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final onlyActive = ref.read(customersFilterActiveOnlyProvider);
      final search = ref.read(customersSearchQueryProvider);
      final repo = ref.read(customersRepositoryProvider);
      return repo.getAllWithSummaries(
        onlyActive: onlyActive,
        search: search.trim().isEmpty ? null : search.trim(),
      );
    });
  }

  Future<int> addCustomer(CustomersCompanion companion) async {
    final repo = ref.read(customersRepositoryProvider);
    final id = await repo.insertCustomer(companion);
    ref.read(selectedCustomerIdProvider.notifier).set(id);
    await refreshList();
    return id;
  }

  Future<void> updateCustomer(Customer customer) async {
    final repo = ref.read(customersRepositoryProvider);
    await repo.updateCustomer(customer);
    await refreshList();
  }

  Future<void> deleteCustomer(int id) async {
    final repo = ref.read(customersRepositoryProvider);
    await repo.deleteCustomer(id);
    if (ref.read(selectedCustomerIdProvider) == id) {
      ref.read(selectedCustomerIdProvider.notifier).set(null);
    }
    await refreshList();
  }
}

final customersListProvider =
    AsyncNotifierProvider<CustomersListNotifier, List<CustomerSummary>>(
  CustomersListNotifier.new,
);

/// Detailed view for the currently selected customer.
final selectedCustomerDetailsProvider =
    FutureProvider.autoDispose<CustomerDetails?>((ref) async {
  final customerId = ref.watch(selectedCustomerIdProvider);
  if (customerId == null) return null;

  // Re-fetch when customers list refreshes
  ref.watch(customersListProvider);

  final repo = ref.watch(customersRepositoryProvider);
  return repo.getCustomerDetails(customerId);
});

/// Vehicles management controller for adding, updating, deleting, and transferring.
class VehiclesController {
  const VehiclesController(this._ref);

  final Ref _ref;

  Future<int> addVehicle(VehiclesCompanion companion) async {
    final repo = _ref.read(vehiclesRepositoryProvider);
    final id = await repo.insertVehicle(companion);
    _ref.invalidate(selectedCustomerDetailsProvider);
    _ref.invalidate(customersListProvider);
    return id;
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    final repo = _ref.read(vehiclesRepositoryProvider);
    await repo.updateVehicle(vehicle);
    _ref.invalidate(selectedCustomerDetailsProvider);
    _ref.invalidate(customersListProvider);
  }

  Future<void> deleteVehicle(int id) async {
    final repo = _ref.read(vehiclesRepositoryProvider);
    await repo.deleteVehicle(id);
    _ref.invalidate(selectedCustomerDetailsProvider);
    _ref.invalidate(customersListProvider);
  }

  Future<void> transferVehicle(int vehicleId, int newCustomerId, {String? notes}) async {
    final repo = _ref.read(vehiclesRepositoryProvider);
    await repo.transferOwnership(vehicleId, newCustomerId, notes: notes);
    _ref.invalidate(selectedCustomerDetailsProvider);
    _ref.invalidate(customersListProvider);
  }

  Future<List<String>> getOwnershipHistory(int vehicleId) {
    final repo = _ref.read(vehiclesRepositoryProvider);
    return repo.getOwnershipHistory(vehicleId);
  }
}

final vehiclesControllerProvider = Provider<VehiclesController>((ref) {
  return VehiclesController(ref);
});
