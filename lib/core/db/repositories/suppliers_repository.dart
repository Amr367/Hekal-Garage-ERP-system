import 'package:drift/drift.dart';

import '../../../features/purchases/domain/supplier_with_balance.dart';
import '../../errors/app_exceptions.dart';
import '../../money/money.dart';
import '../database.dart';

abstract interface class SuppliersRepository {
  Future<Supplier> getById(int id);
  Future<List<Supplier>> getAll({bool onlyActive = false});
  Future<List<SupplierWithBalance>> getSuppliersWithBalances({
    String? searchQuery,
    bool onlyActive = false,
  });
  Future<int> insertSupplier(SuppliersCompanion supplier);
  Future<bool> updateSupplier(Supplier supplier);
  Future<void> deactivate(int id);
  Future<void> reactivate(int id);
  Future<void> recordPayment({
    required int supplierId,
    required int amountPiasters,
    String? notes,
  });
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
    query.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    return query.get();
  }

  @override
  Future<List<SupplierWithBalance>> getSuppliersWithBalances({
    String? searchQuery,
    bool onlyActive = false,
  }) async {
    final suppliersQuery = _db.select(_db.suppliers);
    if (onlyActive) {
      suppliersQuery.where((t) => t.isActive.equals(true));
    }

    final trimmed = searchQuery?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      final normalized = MoneyUtils.normalizeDigits(trimmed);
      suppliersQuery.where((t) =>
          t.name.like('%$trimmed%') |
          t.phone.like('%$normalized%') |
          t.notes.like('%$trimmed%'));
    }

    suppliersQuery.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    final suppliers = await suppliersQuery.get();

    // Query all purchase invoices to aggregate totals per supplier
    final invoices = await _db.select(_db.purchaseInvoices).get();

    final Map<int, List<PurchaseInvoice>> invoicesBySupplier = {};
    for (final inv in invoices) {
      invoicesBySupplier.putIfAbsent(inv.supplierId, () => []).add(inv);
    }

    return suppliers.map((s) {
      final supplierInvs = invoicesBySupplier[s.id] ?? const [];
      int totalPurchases = 0;
      int totalPaid = 0;

      for (final inv in supplierInvs) {
        totalPurchases += inv.totalAmount;
        totalPaid += inv.paidAmount;
      }

      final balanceDue = totalPurchases - totalPaid;

      return SupplierWithBalance(
        supplier: s,
        invoicesCount: supplierInvs.length,
        totalPurchasesPiasters: totalPurchases,
        totalPaidPiasters: totalPaid,
        balanceDuePiasters: balanceDue > 0 ? balanceDue : 0,
      );
    }).toList();
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

  @override
  Future<void> reactivate(int id) async {
    final updated = await (_db.update(_db.suppliers)..where((t) => t.id.equals(id))).write(
      const SuppliersCompanion(isActive: Value(true)),
    );
    if (updated == 0) {
      throw NotFoundException('المورد برقم ($id) غير موجود لتفعيله.');
    }
  }

  @override
  Future<void> recordPayment({
    required int supplierId,
    required int amountPiasters,
    String? notes,
  }) async {
    if (amountPiasters <= 0) {
      throw const ValidationException('قيمة الدفعة المسددة يجب أن تكون أكبر من صفر.');
    }

    await _db.transaction(() async {
      // Find unpaid purchase invoices for this supplier ordered by date asc
      final unpaidInvoices = await (_db.select(_db.purchaseInvoices)
            ..where((t) => t.supplierId.equals(supplierId) & (t.paidAmount.isSmallerThan(t.totalAmount)))
            ..orderBy([(t) => OrderingTerm(expression: t.invoiceDate, mode: OrderingMode.asc)]))
          .get();

      int remainingToDistribute = amountPiasters;

      for (final inv in unpaidInvoices) {
        if (remainingToDistribute <= 0) break;

        final invoiceRemaining = inv.totalAmount - inv.paidAmount;
        final paymentForThis = remainingToDistribute >= invoiceRemaining
            ? invoiceRemaining
            : remainingToDistribute;

        await (_db.update(_db.purchaseInvoices)..where((t) => t.id.equals(inv.id))).write(
          PurchaseInvoicesCompanion(
            paidAmount: Value(inv.paidAmount + paymentForThis),
          ),
        );

        remainingToDistribute -= paymentForThis;
      }
    });
  }
}
