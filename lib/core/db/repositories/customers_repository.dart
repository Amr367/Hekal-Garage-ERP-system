import 'package:drift/drift.dart';

import '../../errors/app_exceptions.dart';
import '../database.dart';

abstract interface class CustomersRepository {
  Future<Customer> getById(int id);
  Future<List<Customer>> getAll({bool onlyActive = false});
  Future<List<Customer>> search(String query);
  Future<int> insertCustomer(CustomersCompanion customer);
  Future<bool> updateCustomer(Customer customer);
  Future<void> deleteCustomer(int id);
}

class DriftCustomersRepository implements CustomersRepository {
  const DriftCustomersRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Customer> getById(int id) async {
    final customer = await (_db.select(_db.customers)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (customer == null) {
      throw NotFoundException('العميل برقم ($id) غير موجود.');
    }
    return customer;
  }

  @override
  Future<List<Customer>> getAll({bool onlyActive = false}) {
    final query = _db.select(_db.customers);
    if (onlyActive) {
      query.where((t) => t.isActive.equals(true));
    }
    return query.get();
  }

  @override
  Future<List<Customer>> search(String query) {
    final cleaned = query.trim();
    if (cleaned.isEmpty) {
      return getAll(onlyActive: true);
    }
    return (_db.select(_db.customers)
          ..where((t) => t.name.contains(cleaned) | t.phone.contains(cleaned)))
        .get();
  }

  @override
  Future<int> insertCustomer(CustomersCompanion customer) {
    return _db.into(_db.customers).insert(customer);
  }

  @override
  Future<bool> updateCustomer(Customer customer) {
    return _db.update(_db.customers).replace(customer);
  }

  @override
  Future<void> deleteCustomer(int id) async {
    // Rule R10: Check if customer has work orders or invoices
    final workOrderCount = await (_db.selectOnly(_db.workOrders)
          ..addColumns([_db.workOrders.id.count()])
          ..where(_db.workOrders.customerId.equals(id)))
        .getSingle();

    final int orders = workOrderCount.read(_db.workOrders.id.count()) ?? 0;
    if (orders > 0) {
      throw const BusinessRuleException(
        'لا يمكن حذف العميل لوجود أوامر شغل مسجلة باسمه. يمكنك تعطيل حسابه بدلاً من ذلك.',
      );
    }

    final invoiceCount = await (_db.selectOnly(_db.invoices)
          ..addColumns([_db.invoices.id.count()])
          ..where(_db.invoices.customerId.equals(id)))
        .getSingle();

    final int invs = invoiceCount.read(_db.invoices.id.count()) ?? 0;
    if (invs > 0) {
      throw const BusinessRuleException(
        'لا يمكن حذف العميل لوجود فواتير مسجلة باسمه. يمكنك تعطيل حسابه بدلاً من ذلك.',
      );
    }

    // Delete customer's vehicles if they also have no history
    await (_db.delete(_db.vehicles)..where((t) => t.customerId.equals(id))).go();
    final deleted = await (_db.delete(_db.customers)..where((t) => t.id.equals(id))).go();
    if (deleted == 0) {
      throw NotFoundException('العميل برقم ($id) غير موجود لحذفه.');
    }
  }
}
