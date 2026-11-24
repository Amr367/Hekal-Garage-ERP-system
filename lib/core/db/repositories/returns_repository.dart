import 'package:drift/drift.dart';

import '../../../../features/returns/domain/return_with_details.dart';
import '../../../../features/returns/domain/returns_summary.dart';
import '../database.dart';
import '../services/stock_service.dart';

class ReturnLineEntry {
  const ReturnLineEntry({
    this.itemId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  final int? itemId;
  final String description;
  final double quantity;
  final int unitPrice; // in piasters

  int get totalPrice => (quantity * unitPrice).round();
}

abstract class ReturnsRepository {
  Future<ReturnWithDetails> createSaleReturn({
    int? invoiceId,
    int? customerId,
    String? customerName,
    required PaymentMethod refundMethod,
    String? reason,
    required List<ReturnLineEntry> lines,
  });

  Future<ReturnWithDetails> createPurchaseReturn({
    int? purchaseInvoiceId,
    int? supplierId,
    String? supplierName,
    required PaymentMethod refundMethod,
    String? reason,
    required List<ReturnLineEntry> lines,
  });

  Future<List<ReturnWithDetails>> getAll({
    ReturnType? type,
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<ReturnWithDetails?> getById(int id);

  Future<ReturnsSummary> getSummary({
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<void> deleteReturn(int id);
}

class DriftReturnsRepository implements ReturnsRepository {
  DriftReturnsRepository(this._db, this._stockService);

  final AppDatabase _db;
  final StockService _stockService;

  @override
  Future<ReturnWithDetails> createSaleReturn({
    int? invoiceId,
    int? customerId,
    String? customerName,
    required PaymentMethod refundMethod,
    String? reason,
    required List<ReturnLineEntry> lines,
  }) async {
    if (lines.isEmpty) {
      throw Exception('لا يمكن حفظ مرتجع بدون بنود');
    }

    return _db.transaction(() async {
      final returnNum = await _db.nextReturnNumber(ReturnType.saleReturn);
      final totalAmount = lines.fold<int>(0, (sum, l) => sum + l.totalPrice);

      final returnId = await _db.into(_db.returns).insert(
            ReturnsCompanion(
              returnNumber: Value(returnNum),
              returnType: const Value(ReturnType.saleReturn),
              invoiceId: Value(invoiceId),
              customerId: Value(customerId),
              customerName: Value(customerName),
              totalAmount: Value(totalAmount),
              refundMethod: Value(refundMethod),
              reason: Value(reason),
              createdAt: Value(DateTime.now()),
            ),
          );

      for (final line in lines) {
        await _db.into(_db.returnLines).insert(
              ReturnLinesCompanion(
                returnId: Value(returnId),
                itemId: Value(line.itemId),
                description: Value(line.description),
                quantity: Value(line.quantity),
                unitPrice: Value(line.unitPrice),
                totalPrice: Value(line.totalPrice),
              ),
            );

        // Return stock back to inventory
        if (line.itemId != null && line.quantity > 0) {
          await _stockService.addMovement(
            StockMovementsCompanion(
              itemId: Value(line.itemId!),
              movementType: const Value(StockMovementType.saleReturn),
              qty: Value(line.quantity),
              unitCost: Value(line.unitPrice),
              refType: const Value('return'),
              refId: Value(returnId),
              notes: Value('مرتجع مبيعات عميل #$returnNum: ${line.description}'),
            ),
          );
        }
      }

      final created = await getById(returnId);
      return created!;
    });
  }

  @override
  Future<ReturnWithDetails> createPurchaseReturn({
    int? purchaseInvoiceId,
    int? supplierId,
    String? supplierName,
    required PaymentMethod refundMethod,
    String? reason,
    required List<ReturnLineEntry> lines,
  }) async {
    if (lines.isEmpty) {
      throw Exception('لا يمكن حفظ مرتجع بدون بنود');
    }

    return _db.transaction(() async {
      final returnNum = await _db.nextReturnNumber(ReturnType.purchaseReturn);
      final totalAmount = lines.fold<int>(0, (sum, l) => sum + l.totalPrice);

      final returnId = await _db.into(_db.returns).insert(
            ReturnsCompanion(
              returnNumber: Value(returnNum),
              returnType: const Value(ReturnType.purchaseReturn),
              purchaseInvoiceId: Value(purchaseInvoiceId),
              supplierId: Value(supplierId),
              supplierName: Value(supplierName),
              totalAmount: Value(totalAmount),
              refundMethod: Value(refundMethod),
              reason: Value(reason),
              createdAt: Value(DateTime.now()),
            ),
          );

      for (final line in lines) {
        await _db.into(_db.returnLines).insert(
              ReturnLinesCompanion(
                returnId: Value(returnId),
                itemId: Value(line.itemId),
                description: Value(line.description),
                quantity: Value(line.quantity),
                unitPrice: Value(line.unitPrice),
                totalPrice: Value(line.totalPrice),
              ),
            );

        // Deduct returned goods from warehouse
        if (line.itemId != null && line.quantity > 0) {
          await _stockService.addMovement(
            StockMovementsCompanion(
              itemId: Value(line.itemId!),
              movementType: const Value(StockMovementType.adjustment),
              qty: Value(-line.quantity),
              unitCost: Value(line.unitPrice),
              refType: const Value('purchase_return'),
              refId: Value(returnId),
              notes: Value('مرتجع مشتريات للمورد #$returnNum: ${line.description}'),
            ),
          );
        }
      }

      final created = await getById(returnId);
      return created!;
    });
  }

  @override
  Future<List<ReturnWithDetails>> getAll({
    ReturnType? type,
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final selectQuery = _db.select(_db.returns);

    if (type != null) {
      selectQuery.where((t) => t.returnType.equals(type.index));
    }

    if (fromDate != null) {
      selectQuery.where((t) => t.createdAt.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      selectQuery.where((t) => t.createdAt.isSmallerOrEqualValue(toDate));
    }

    selectQuery.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    final rows = await selectQuery.get();
    final results = <ReturnWithDetails>[];

    for (final entry in rows) {
      final lines = await (_db.select(_db.returnLines)..where((l) => l.returnId.equals(entry.id))).get();

      Customer? customer;
      if (entry.customerId != null) {
        customer = await (_db.select(_db.customers)..where((c) => c.id.equals(entry.customerId!))).getSingleOrNull();
      }

      Supplier? supplier;
      if (entry.supplierId != null) {
        supplier = await (_db.select(_db.suppliers)..where((s) => s.id.equals(entry.supplierId!))).getSingleOrNull();
      }

      Invoice? invoice;
      if (entry.invoiceId != null) {
        invoice = await (_db.select(_db.invoices)..where((i) => i.id.equals(entry.invoiceId!))).getSingleOrNull();
      }

      PurchaseInvoice? purchaseInvoice;
      if (entry.purchaseInvoiceId != null) {
        purchaseInvoice = await (_db.select(_db.purchaseInvoices)..where((p) => p.id.equals(entry.purchaseInvoiceId!))).getSingleOrNull();
      }

      final withDetails = ReturnWithDetails(
        entry: entry,
        lines: lines,
        customer: customer,
        supplier: supplier,
        invoice: invoice,
        purchaseInvoice: purchaseInvoice,
      );

      // Search filter in memory
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final match = withDetails.returnNumber.toString().contains(q) ||
            withDetails.partyName.toLowerCase().contains(q) ||
            (withDetails.entry.reason?.toLowerCase().contains(q) ?? false) ||
            withDetails.lines.any((l) => l.description.toLowerCase().contains(q));
        if (!match) continue;
      }

      results.add(withDetails);
    }

    return results;
  }

  @override
  Future<ReturnWithDetails?> getById(int id) async {
    final entry = await (_db.select(_db.returns)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entry == null) return null;

    final lines = await (_db.select(_db.returnLines)..where((l) => l.returnId.equals(entry.id))).get();

    Customer? customer;
    if (entry.customerId != null) {
      customer = await (_db.select(_db.customers)..where((c) => c.id.equals(entry.customerId!))).getSingleOrNull();
    }

    Supplier? supplier;
    if (entry.supplierId != null) {
      supplier = await (_db.select(_db.suppliers)..where((s) => s.id.equals(entry.supplierId!))).getSingleOrNull();
    }

    Invoice? invoice;
    if (entry.invoiceId != null) {
      invoice = await (_db.select(_db.invoices)..where((i) => i.id.equals(entry.invoiceId!))).getSingleOrNull();
    }

    PurchaseInvoice? purchaseInvoice;
    if (entry.purchaseInvoiceId != null) {
      purchaseInvoice = await (_db.select(_db.purchaseInvoices)..where((p) => p.id.equals(entry.purchaseInvoiceId!))).getSingleOrNull();
    }

    return ReturnWithDetails(
      entry: entry,
      lines: lines,
      customer: customer,
      supplier: supplier,
      invoice: invoice,
      purchaseInvoice: purchaseInvoice,
    );
  }

  @override
  Future<ReturnsSummary> getSummary({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final selectQuery = _db.select(_db.returns);
    if (fromDate != null) {
      selectQuery.where((t) => t.createdAt.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      selectQuery.where((t) => t.createdAt.isSmallerOrEqualValue(toDate));
    }

    final rows = await selectQuery.get();

    int salesCount = 0;
    int purchaseCount = 0;
    int salesAmount = 0;
    int purchaseAmount = 0;

    for (final r in rows) {
      if (r.returnType == ReturnType.saleReturn) {
        salesCount++;
        salesAmount += r.totalAmount;
      } else {
        purchaseCount++;
        purchaseAmount += r.totalAmount;
      }
    }

    return ReturnsSummary(
      totalReturnsCount: rows.length,
      totalSalesReturnsCount: salesCount,
      totalPurchaseReturnsCount: purchaseCount,
      totalSalesReturnsAmount: salesAmount,
      totalPurchaseReturnsAmount: purchaseAmount,
    );
  }

  @override
  Future<void> deleteReturn(int id) async {
    await _db.transaction(() async {
      final entry = await (_db.select(_db.returns)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (entry == null) return;

      final lines = await (_db.select(_db.returnLines)..where((l) => l.returnId.equals(id))).get();

      // Reverse stock effects
      for (final line in lines) {
        if (line.itemId != null && line.quantity > 0) {
          if (entry.returnType == ReturnType.saleReturn) {
            // Re-deduct from stock
            await _stockService.addMovement(
              StockMovementsCompanion(
                itemId: Value(line.itemId!),
                movementType: const Value(StockMovementType.adjustment),
                qty: Value(-line.quantity),
                unitCost: Value(line.unitPrice),
                refType: const Value('delete_return'),
                refId: Value(id),
                notes: Value('إلغاء مرتجع مبيعات #${entry.returnNumber}'),
              ),
            );
          } else {
            // Re-add to stock
            await _stockService.addMovement(
              StockMovementsCompanion(
                itemId: Value(line.itemId!),
                movementType: const Value(StockMovementType.adjustment),
                qty: Value(line.quantity),
                unitCost: Value(line.unitPrice),
                refType: const Value('delete_return'),
                refId: Value(id),
                notes: Value('إلغاء مرتجع مشتريات #${entry.returnNumber}'),
              ),
            );
          }
        }
      }

      await (_db.delete(_db.returnLines)..where((l) => l.returnId.equals(id))).go();
      await (_db.delete(_db.returns)..where((t) => t.id.equals(id))).go();
    });
  }
}
