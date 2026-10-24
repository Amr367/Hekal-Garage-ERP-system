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
  Future<void> transferOwnership(int vehicleId, int newCustomerId, {String? notes});
  Future<void> deleteVehicle(int id);
  Future<List<String>> getOwnershipHistory(int vehicleId);
  Future<List<WorkOrder>> getVehicleWorkOrders(int vehicleId);
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
    if (normalized.isEmpty) return Future.value(null);
    return (_db.select(_db.vehicles)..where((t) => t.plateNumber.equals(normalized))).getSingleOrNull();
  }

  @override
  Future<List<Vehicle>> getByCustomerId(int customerId) {
    return (_db.select(_db.vehicles)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
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
    if (normalizedPlate.isEmpty) {
      throw const ValidationException('رقم اللوحة مطلوب.');
    }

    final existing = await getByPlate(normalizedPlate);
    if (existing != null && existing.id != vehicle.id) {
      final owner = await (_db.select(_db.customers)..where((t) => t.id.equals(existing.customerId))).getSingleOrNull();
      final ownerName = owner?.name ?? 'عميل آخر';
      throw ValidationException('رقم اللوحة ($normalizedPlate) مسجل بالفعل باسم العميل ($ownerName).');
    }

    return _db.update(_db.vehicles).replace(
          vehicle.copyWith(plateNumber: normalizedPlate),
        );
  }

  @override
  Future<void> transferOwnership(int vehicleId, int newCustomerId, {String? notes}) async {
    final vehicle = await getById(vehicleId);
    if (vehicle.customerId == newCustomerId) {
      throw const ValidationException('السيارة مسجلة بالفعل باسم هذا العميل.');
    }

    // Verify target customer exists
    final newCustomer = await (_db.select(_db.customers)..where((t) => t.id.equals(newCustomerId))).getSingleOrNull();
    if (newCustomer == null) {
      throw NotFoundException('العميل المنقول إليه برقم ($newCustomerId) غير موجود.');
    }

    final previousCustomer = await (_db.select(_db.customers)..where((t) => t.id.equals(vehicle.customerId))).getSingleOrNull();

    final updated = await (_db.update(_db.vehicles)..where((t) => t.id.equals(vehicleId))).write(
      VehiclesCompanion(customerId: Value(newCustomerId)),
    );
    if (updated == 0) {
      throw NotFoundException('السيارة برقم ($vehicleId) غير موجودة لنقل ملكيتها.');
    }

    // Rule R14: Log ownership transfer into AppSettings audit log
    final now = DateTime.now();
    final logKey = 'audit_transfer_${vehicleId}_${now.millisecondsSinceEpoch}';
    final notesText = (notes != null && notes.trim().isNotEmpty) ? ' | ملاحظات: ${notes.trim()}' : '';
    final prevOwnerName = previousCustomer?.name ?? 'عميل #${vehicle.customerId}';
    final logValue =
        'نقل ملكية السيارة [${vehicle.plateNumber}] من [$prevOwnerName] إلى [${newCustomer.name}] بتاريخ ${now.year}/${now.month}/${now.day}$notesText';

    await _db.into(_db.appSettings).insertOnConflictUpdate(
      AppSettingsCompanion(
        key: Value(logKey),
        value: Value(logValue),
      ),
    );
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

  @override
  Future<List<String>> getOwnershipHistory(int vehicleId) async {
    final prefix = 'audit_transfer_${vehicleId}_';
    final records = await (_db.select(_db.appSettings)
          ..where((t) => t.key.like('$prefix%'))
          ..orderBy([(t) => OrderingTerm(expression: t.key, mode: OrderingMode.desc)]))
        .get();

    return records.map((r) => r.value).toList();
  }

  @override
  Future<List<WorkOrder>> getVehicleWorkOrders(int vehicleId) {
    return (_db.select(_db.workOrders)
          ..where((t) => t.vehicleId.equals(vehicleId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }
}
