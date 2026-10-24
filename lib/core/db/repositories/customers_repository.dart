import 'package:drift/drift.dart';

import '../../../features/customers/domain/customer_details.dart';
import '../../../features/customers/domain/customer_summary.dart';
import '../../errors/app_exceptions.dart';
import '../../money/money.dart';
import '../../utils/formatters.dart';
import '../database.dart';

abstract interface class CustomersRepository {
  Future<Customer> getById(int id);
  Future<Customer?> getByPhone(String phone);
  Future<List<Customer>> getAll({bool onlyActive = false});
  Future<List<Customer>> search(String query);
  Future<CustomerSummary> getCustomerSummary(int customerId);
  Future<CustomerDetails> getCustomerDetails(int customerId);
  Future<List<CustomerSummary>> getAllWithSummaries({
    bool onlyActive = false,
    String? search,
  });
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
  Future<Customer?> getByPhone(String phone) async {
    final normalized = MoneyUtils.normalizeDigits(phone.trim());
    if (normalized.isEmpty) return null;
    return (_db.select(_db.customers)..where((t) => t.phone.equals(normalized))).getSingleOrNull();
  }

  @override
  Future<List<Customer>> getAll({bool onlyActive = false}) {
    final query = _db.select(_db.customers);
    if (onlyActive) {
      query.where((t) => t.isActive.equals(true));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    return query.get();
  }

  @override
  Future<List<Customer>> search(String query) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) {
      return getAll(onlyActive: true);
    }

    final normalizedDigits = MoneyUtils.normalizeDigits(cleaned);
    final normalizedPlate = Formatters.normalizePlateNumber(cleaned);

    // 1. Search directly in customers by name or phone
    final directCustomers = await (_db.select(_db.customers)
          ..where(
            (t) =>
                t.name.contains(cleaned) |
                t.name.contains(normalizedDigits) |
                t.phone.contains(cleaned) |
                t.phone.contains(normalizedDigits),
          ))
        .get();

    // 2. Search vehicles by plate to find matching customer IDs
    final matchingVehicles = await (_db.select(_db.vehicles)
          ..where(
            (t) =>
                t.plateNumber.contains(cleaned) |
                t.plateNumber.contains(normalizedPlate) |
                t.plateNumber.contains(normalizedDigits),
          ))
        .get();

    final vehicleCustomerIds = matchingVehicles.map((v) => v.customerId).toSet();

    // 3. Fetch any additional customers found via vehicle plate
    final existingIds = directCustomers.map((c) => c.id).toSet();
    final missingIds = vehicleCustomerIds.difference(existingIds);

    final additionalCustomers = <Customer>[];
    if (missingIds.isNotEmpty) {
      additionalCustomers.addAll(
        await (_db.select(_db.customers)..where((t) => t.id.isIn(missingIds))).get(),
      );
    }

    final combined = <Customer>[...directCustomers, ...additionalCustomers];
    combined.sort((a, b) => a.name.compareTo(b.name));
    return combined;
  }

  @override
  Future<CustomerSummary> getCustomerSummary(int customerId) async {
    final customer = await getById(customerId);

    // Vehicles count
    final vehiclesCountRow = await (_db.selectOnly(_db.vehicles)
          ..addColumns([_db.vehicles.id.count()])
          ..where(_db.vehicles.customerId.equals(customerId) & _db.vehicles.isActive.equals(true)))
        .getSingle();
    final vehiclesCount = vehiclesCountRow.read(_db.vehicles.id.count()) ?? 0;

    // Work orders count
    final workOrdersCountRow = await (_db.selectOnly(_db.workOrders)
          ..addColumns([_db.workOrders.id.count()])
          ..where(_db.workOrders.customerId.equals(customerId)))
        .getSingle();
    final workOrdersCount = workOrdersCountRow.read(_db.workOrders.id.count()) ?? 0;

    // Invoices summary (only issued invoices, status == 0)
    final invoices = await (_db.select(_db.invoices)
          ..where((t) => t.customerId.equals(customerId) & t.status.equals(InvoiceStatus.issued.index)))
        .get();

    int totalInvoiced = 0;
    int totalPaid = 0;
    for (final inv in invoices) {
      totalInvoiced += inv.totalAmount;
      totalPaid += inv.paidAmount;
    }

    final balance = totalInvoiced - totalPaid;

    return CustomerSummary(
      customer: customer,
      vehiclesCount: vehiclesCount,
      balance: balance,
      totalInvoiced: totalInvoiced,
      totalPaid: totalPaid,
      invoicesCount: invoices.length,
      workOrdersCount: workOrdersCount,
    );
  }

  @override
  Future<CustomerDetails> getCustomerDetails(int customerId) async {
    final summary = await getCustomerSummary(customerId);

    // Vehicles list
    final vehicles = await (_db.select(_db.vehicles)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();

    // Work orders list (latest 15)
    final workOrders = await (_db.select(_db.workOrders)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
          ..limit(15))
        .get();

    // Invoices list (latest 15)
    final invoices = await (_db.select(_db.invoices)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm(expression: t.issuedAt, mode: OrderingMode.desc)])
          ..limit(15))
        .get();

    return CustomerDetails(
      customer: summary.customer,
      summary: summary,
      vehicles: vehicles,
      workOrders: workOrders,
      invoices: invoices,
    );
  }

  @override
  Future<List<CustomerSummary>> getAllWithSummaries({
    bool onlyActive = false,
    String? search,
  }) async {
    List<Customer> customerList;
    if (search != null && search.trim().isNotEmpty) {
      customerList = await this.search(search);
      if (onlyActive) {
        customerList = customerList.where((c) => c.isActive).toList();
      }
    } else {
      customerList = await getAll(onlyActive: onlyActive);
    }

    final summaries = <CustomerSummary>[];
    for (final customer in customerList) {
      final summary = await getCustomerSummary(customer.id);
      summaries.add(summary);
    }
    return summaries;
  }

  @override
  Future<int> insertCustomer(CustomersCompanion customer) async {
    final name = customer.name.value.trim();
    if (name.isEmpty) {
      throw const ValidationException('اسم العميل مطلوب.');
    }

    String? normalizedPhone;
    if (customer.phone.present && customer.phone.value != null) {
      final p = MoneyUtils.normalizeDigits(customer.phone.value!.trim());
      if (p.isNotEmpty) {
        final existing = await getByPhone(p);
        if (existing != null) {
          throw ValidationException('رقم الهاتف ($p) مسجل بالفعل لعميل آخر باسم (${existing.name}).');
        }
        normalizedPhone = p;
      }
    }

    return _db.into(_db.customers).insert(
          customer.copyWith(
            name: Value(name),
            phone: Value(normalizedPhone),
          ),
        );
  }

  @override
  Future<bool> updateCustomer(Customer customer) async {
    final name = customer.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('اسم العميل مطلوب.');
    }

    String? normalizedPhone;
    if (customer.phone != null) {
      final p = MoneyUtils.normalizeDigits(customer.phone!.trim());
      if (p.isNotEmpty) {
        final existing = await getByPhone(p);
        if (existing != null && existing.id != customer.id) {
          throw ValidationException('رقم الهاتف ($p) مسجل بالفعل لعميل آخر باسم (${existing.name}).');
        }
        normalizedPhone = p;
      }
    }

    return _db.update(_db.customers).replace(
          customer.copyWith(
            name: name,
            phone: Value(normalizedPhone),
          ),
        );
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
