import 'package:drift/drift.dart';

import '../../errors/app_exceptions.dart';
import '../../utils/formatters.dart';
import '../database.dart';

abstract interface class VehiclesRepository {
  Future<Vehicle> getById(int id);
  Future<Vehicle?> getByPlate(String plateNumber);
  Future<List<Vehicle>> getByCustomerId(int customerId);
  Future<List<Vehicle>> searchByPlate(String partialPlate);
  Future<int> insertVehicle(VehiclesCompanion vehicle);
  Future<bool> updateVehicle(Vehicle vehicle);
  Future<void> transferOwnership(int vehicleId, int newCustomerId);
  Future<void> deleteVehicle(int id);
}

class DriftVehiclesRepository implements VehiclesRepository {
  const DriftVehiclesRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Vehicle> getById(int id) async {
    final vehicle = await (_db.select(_db.vehicles)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (vehicle == null) {
      throw NotFoundException('السيارة برقم ($id) غير موجودة.');
    }
    return vehicle;
  }

  @override
  Future<Vehicle?> getByPlate(String plateNumber) {
    final normalized = Formatters.normalizePlateNumber(plateNumber);
    return (_db.select(_db.vehicles)..where((t) => t.plateNumber.equals(normalized))).getSingleOrNull();
  }

  @override
  Future<List<Vehicle>> getByCustomerId(int customerId) {
    return (_db.select(_db.vehicles)..where((t) => t.customerId.equals(customerId))).get();
  }

  @override
  Future<List<Vehicle>> searchByPlate(String partialPlate) {
    final normalized = Formatters.normalizePlateNumber(partialPlate);
    if (normalized.isEmpty) {
      return _db.select(_db.vehicles).get();
    }
    return (_db.select(_db.vehicles)..where((t) => t.plateNumber.contains(normalized))).get();
  }

  @override
  Future<int> insertVehicle(VehiclesCompanion vehicle) async {
    // Normalize plate before saving (Rule R13)
    final plate = Formatters.normalizePlateNumber(vehicle.plateNumber.value);
    if (plate.isEmpty) {
      throw const ValidationException('رقم اللوحة مطلوب.');
    }

    final existing = await getByPlate(plate);
    if (existing != null) {
      final owner = await (_db.select(_db.customers)..where((t) => t.id.equals(existing.customerId))).getSingleOrNull();
      final ownerName = owner?.name ?? 'عميل آخر';
      throw ValidationException('رقم اللوحة ($plate) مسجل بالفعل باسم العميل ($ownerName).');
    }

    return _db.into(_db.vehicles).insert(
          vehicle.copyWith(plateNumber: Value(plate)),
        );
  }

  @override
  Future<bool> updateVehicle(Vehicle vehicle) async {
    final normalizedPlate = Formatters.normalizePlateNumber(vehicle.plateNumber);
    return _db.update(_db.vehicles).replace(
          vehicle.copyWith(plateNumber: normalizedPlate),
        );
  }

  @override
  Future<void> transferOwnership(int vehicleId, int newCustomerId) async {
    // Verify target customer exists
    final customer = await (_db.select(_db.customers)..where((t) => t.id.equals(newCustomerId))).getSingleOrNull();
    if (customer == null) {
      throw NotFoundException('العميل المنقول إليه برقم ($newCustomerId) غير موجود.');
    }

    final updated = await (_db.update(_db.vehicles)..where((t) => t.id.equals(vehicleId))).write(
      VehiclesCompanion(customerId: Value(newCustomerId)),
    );
    if (updated == 0) {
      throw NotFoundException('السيارة برقم ($vehicleId) غير موجودة لنقل ملكيتها.');
    }
  }

  @override
  Future<void> deleteVehicle(int id) async {
    // Rule R10: Check work orders
    final workOrderCount = await (_db.selectOnly(_db.workOrders)
          ..addColumns([_db.workOrders.id.count()])
          ..where(_db.workOrders.vehicleId.equals(id)))
        .getSingle();

    final int orders = workOrderCount.read(_db.workOrders.id.count()) ?? 0;
    if (orders > 0) {
      throw const BusinessRuleException(
        'لا يمكن حذف السيارة لوجود أوامر شغل سابقة مسجلة لها. يمكنك إلغاء تفعيلها بدلاً من الحذف.',
      );
    }

    final deleted = await (_db.delete(_db.vehicles)..where((t) => t.id.equals(id))).go();
    if (deleted == 0) {
      throw NotFoundException('السيارة برقم ($id) غير موجودة لحذفها.');
    }
  }
}
