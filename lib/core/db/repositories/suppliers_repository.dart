import 'package:drift/drift.dart';

import '../../errors/app_exceptions.dart';
import '../database.dart';

abstract interface class SuppliersRepository {
  Future<Supplier> getById(int id);
  Future<List<Supplier>> getAll({bool onlyActive = false});
  Future<int> insertSupplier(SuppliersCompanion supplier);
  Future<bool> updateSupplier(Supplier supplier);
  Future<void> deactivate(int id);
}

class DriftSuppliersRepository implements SuppliersRepository {
  const DriftSuppliersRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Supplier> getById(int id) async {
    final supplier = await (_db.select(_db.suppliers)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (supplier == null) {
      throw NotFoundException('المورد برقم ($id) غير موجود.');
    }
    return supplier;
  }

  @override
  Future<List<Supplier>> getAll({bool onlyActive = false}) {
    final query = _db.select(_db.suppliers);
    if (onlyActive) {
      query.where((t) => t.isActive.equals(true));
    }
    return query.get();
  }

  @override
  Future<int> insertSupplier(SuppliersCompanion supplier) async {
    final name = supplier.name.value.trim();
    if (name.isEmpty) {
      throw const ValidationException('اسم المورد مطلوب.');
    }
    return _db.into(_db.suppliers).insert(supplier);
  }

  @override
  Future<bool> updateSupplier(Supplier supplier) {
    return _db.update(_db.suppliers).replace(supplier);
  }

  @override
  Future<void> deactivate(int id) async {
    final updated = await (_db.update(_db.suppliers)..where((t) => t.id.equals(id))).write(
      const SuppliersCompanion(isActive: Value(false)),
    );
    if (updated == 0) {
      throw NotFoundException('المورد برقم ($id) غير موجود لتعطيله.');
    }
  }
}
