import 'package:drift/drift.dart';

import '../../errors/app_exceptions.dart';
import '../database.dart';

abstract interface class ServicesRepository {
  Future<Service> getById(int id);
  Future<List<Service>> getAll({bool onlyActive = false});
  Future<int> insertService(ServicesCompanion service);
  Future<bool> updateService(Service service);
  Future<void> updatePrice(int id, int newPricePiasters);
  Future<void> deactivate(int id);
}

class DriftServicesRepository implements ServicesRepository {
  const DriftServicesRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Service> getById(int id) async {
    final service = await (_db.select(_db.services)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (service == null) {
      throw NotFoundException('الخدمة برقم ($id) غير موجودة.');
    }
    return service;
  }

  @override
  Future<List<Service>> getAll({bool onlyActive = false}) {
    final query = _db.select(_db.services);
    if (onlyActive) {
      query.where((t) => t.isActive.equals(true));
    }
    return query.get();
  }

  @override
  Future<int> insertService(ServicesCompanion service) {
    return _db.into(_db.services).insert(service);
  }

  @override
  Future<bool> updateService(Service service) {
    return _db.update(_db.services).replace(service);
  }

  @override
  Future<void> updatePrice(int id, int newPricePiasters) async {
    final updated = await (_db.update(_db.services)..where((t) => t.id.equals(id))).write(
      ServicesCompanion(defaultPrice: Value(newPricePiasters)),
    );
    if (updated == 0) {
      throw NotFoundException('الخدمة برقم ($id) غير موجودة لتحديث سعرها.');
    }
  }

  @override
  Future<void> deactivate(int id) async {
    final updated = await (_db.update(_db.services)..where((t) => t.id.equals(id))).write(
      const ServicesCompanion(isActive: Value(false)),
    );
    if (updated == 0) {
      throw NotFoundException('الخدمة برقم ($id) غير موجودة لتعطيلها.');
    }
  }
}
