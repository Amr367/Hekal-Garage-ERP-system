import 'package:drift/drift.dart';

import '../../../features/invoices/domain/invoice_line_entry.dart';
import '../../../features/invoices/domain/invoice_with_details.dart';
import '../../../features/invoices/domain/invoices_summary.dart';
import '../database.dart';
import '../services/stock_service.dart';

/// Abstract contract for managing invoices, payments, and sales.
abstract class InvoicesRepository {
  Future<List<InvoiceWithDetails>> getAll({
    String? query,
    InvoiceStatus? statusFilter,
    DateTime? start,
    DateTime? end,
  });

  Future<InvoiceWithDetails?> getById(int id);

  Future<InvoiceWithDetails> createDirectSale({
    int? customerId,
    required List<InvoiceLineEntry> lines,
    int discountAmountPiasters = 0,
    int paidAmountPiasters = 0,
    required PaymentMethod paymentMethod,
    String? paymentNotes,
    String? notes,
  });

  Future<void> recordPayment({
    required int invoiceId,
    required int amountPiasters,
    required PaymentMethod method,
    String? notes,
  });

  Future<void> cancelInvoice({
    required int invoiceId,
    required String reason,
  });

  Future<InvoicesSummary> getSummary();
}

/// Drift implementation of [InvoicesRepository].
class DriftInvoicesRepository implements InvoicesRepository {
  DriftInvoicesRepository(this._db, this._stockService);

  final AppDatabase _db;
  final StockService _stockService;

  @override
  Future<List<InvoiceWithDetails>> getAll({
    String? query,
    InvoiceStatus? statusFilter,
    DateTime? start,
    DateTime? end,
  }) async {
    final invoiceQuery = _db.select(_db.invoices).join([
      leftOuterJoin(_db.customers, _db.customers.id.equalsExp(_db.invoices.customerId)),
      leftOuterJoin(_db.workOrders, _db.workOrders.id.equalsExp(_db.invoices.workOrderId)),
      leftOuterJoin(_db.vehicles, _db.vehicles.id.equalsExp(_db.workOrders.vehicleId)),
    ]);

    if (statusFilter != null) {
      invoiceQuery.where(_db.invoices.status.equals(statusFilter.index));
    }

    if (start != null) {
      invoiceQuery.where(_db.invoices.issuedAt.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      invoiceQuery.where(_db.invoices.issuedAt.isSmallerOrEqualValue(end));
    }

    invoiceQuery.orderBy([OrderingTerm.desc(_db.invoices.issuedAt)]);

    final rows = await invoiceQuery.get();
    final invoiceIds = rows.map((r) => r.readTable(_db.invoices).id).toList();

    // Batch load lines and payments
    final allLines = invoiceIds.isEmpty
        ? <InvoiceLine>[]
        : await (_db.select(_db.invoiceLines)..where((t) => t.invoiceId.isIn(invoiceIds))).get();

    final allPayments = invoiceIds.isEmpty
        ? <Payment>[]
        : await (_db.select(_db.payments)..where((t) => t.invoiceId.isIn(invoiceIds))).get();

    final linesByInvoice = <int, List<InvoiceLineEntry>>{};
    for (final l in allLines) {
      linesByInvoice.putIfAbsent(l.invoiceId, () => []).add(
            InvoiceLineEntry(
              id: l.id,
              invoiceId: l.invoiceId,
              lineType: l.lineType,
              serviceId: l.serviceId,
              itemId: l.itemId,
              description: l.description,
              quantity: l.quantity,
              unitPricePiasters: l.unitPrice,
              unitCostPiasters: l.unitCost,
              totalPricePiasters: l.totalPrice,
            ),
          );
    }

    final paymentsByInvoice = <int, List<Payment>>{};
    for (final p in allPayments) {
      paymentsByInvoice.putIfAbsent(p.invoiceId, () => []).add(p);
    }

    final cleanQuery = query?.trim().toLowerCase();
    final results = <InvoiceWithDetails>[];

    for (final row in rows) {
      final inv = row.readTable(_db.invoices);
      final cust = row.readTableOrNull(_db.customers);
      final wo = row.readTableOrNull(_db.workOrders);
      final veh = row.readTableOrNull(_db.vehicles);

      final detail = InvoiceWithDetails(
        invoice: inv,
        customer: cust,
        workOrder: wo,
        vehicle: veh,
        lines: linesByInvoice[inv.id] ?? const <InvoiceLineEntry>[],
        payments: paymentsByInvoice[inv.id] ?? const <Payment>[],
      );

      if (cleanQuery != null && cleanQuery.isNotEmpty) {
        final matchesNumber = inv.invoiceNumber.toString().contains(cleanQuery) ||
            '#${inv.invoiceNumber}'.contains(cleanQuery);
        final matchesCustName = cust?.name.toLowerCase().contains(cleanQuery) ?? false;
        final matchesCustPhone = cust?.phone?.contains(cleanQuery) ?? false;
        final matchesPlate = veh?.plateNumber.toLowerCase().contains(cleanQuery) ?? false;

        if (!matchesNumber && !matchesCustName && !matchesCustPhone && !matchesPlate) {
          continue;
        }
      }

      results.add(detail);
    }

    return results;
  }

  @override
  Future<InvoiceWithDetails?> getById(int id) async {
    final row = await (_db.select(_db.invoices).join([
      leftOuterJoin(_db.customers, _db.customers.id.equalsExp(_db.invoices.customerId)),
      leftOuterJoin(_db.workOrders, _db.workOrders.id.equalsExp(_db.invoices.workOrderId)),
      leftOuterJoin(_db.vehicles, _db.vehicles.id.equalsExp(_db.workOrders.vehicleId)),
    ])..where(_db.invoices.id.equals(id))).getSingleOrNull();

    if (row == null) return null;

    final inv = row.readTable(_db.invoices);
    final cust = row.readTableOrNull(_db.customers);
    final wo = row.readTableOrNull(_db.workOrders);
    final veh = row.readTableOrNull(_db.vehicles);

    final lines = await (_db.select(_db.invoiceLines)..where((t) => t.invoiceId.equals(id))).get();
    final payments = await (_db.select(_db.payments)..where((t) => t.invoiceId.equals(id))).get();

    return InvoiceWithDetails(
      invoice: inv,
      customer: cust,
      workOrder: wo,
      vehicle: veh,
      lines: lines
          .map(
            (l) => InvoiceLineEntry(
              id: l.id,
              invoiceId: l.invoiceId,
              lineType: l.lineType,
              serviceId: l.serviceId,
              itemId: l.itemId,
              description: l.description,
              quantity: l.quantity,
              unitPricePiasters: l.unitPrice,
              unitCostPiasters: l.unitCost,
              totalPricePiasters: l.totalPrice,
            ),
          )
          .toList(),
      payments: payments,
    );
  }

  @override
  Future<InvoiceWithDetails> createDirectSale({
    int? customerId,
    required List<InvoiceLineEntry> lines,
    int discountAmountPiasters = 0,
    int paidAmountPiasters = 0,
    required PaymentMethod paymentMethod,
    String? paymentNotes,
    String? notes,
  }) async {
    return _db.transaction(() async {
      // 1. Verify stock availability for parts lines per Rule R4
      final partsMap = <int, double>{};
      for (final line in lines) {
        if (line.isPart && line.itemId != null) {
          partsMap[line.itemId!] = (partsMap[line.itemId!] ?? 0.0) + line.quantity;
        }
      }
      await _stockService.validateStockAvailability(partsMap);

      // 2. Compute financial totals
      int subtotal = 0;
      for (final l in lines) {
        subtotal += l.totalPricePiasters;
      }

      final discount = discountAmountPiasters.clamp(0, subtotal);
      final total = (subtotal - discount).clamp(0, double.maxFinite.toInt());
      final paid = paidAmountPiasters.clamp(0, total);

      // 3. Sequential numbering Rule R6
      final invoiceNumber = await _db.nextInvoiceNumber();

      final invoiceId = await _db.into(_db.invoices).insert(
            InvoicesCompanion(
              invoiceNumber: Value(invoiceNumber),
              customerId: Value(customerId),
              subtotal: Value(subtotal),
              discountAmount: Value(discount),
              totalAmount: Value(total),
              paidAmount: Value(paid),
              status: const Value(InvoiceStatus.issued),
              notes: Value(notes),
              issuedAt: Value(DateTime.now()),
            ),
          );

      // 4. Insert lines and deduct warehouse stock (Rules R2, R3, R8)
      final savedLines = <InvoiceLineEntry>[];
      for (final line in lines) {
        int unitCost = 0;
        if (line.itemId != null) {
          final item = await (_db.select(_db.items)..where((t) => t.id.equals(line.itemId!))).getSingleOrNull();
          unitCost = item?.costPrice ?? 0;

          await _stockService.addMovement(
            StockMovementsCompanion(
              itemId: Value(line.itemId!),
              movementType: const Value(StockMovementType.saleOut),
              qty: Value(-line.quantity),
              unitCost: Value(unitCost),
              refType: const Value('invoice'),
              refId: Value(invoiceId),
              notes: Value('بيع كاونتر مباشر - فاتورة #$invoiceNumber'),
            ),
          );
        }

        final lineId = await _db.into(_db.invoiceLines).insert(
              InvoiceLinesCompanion(
                invoiceId: Value(invoiceId),
                lineType: Value(line.lineType),
                serviceId: Value(line.serviceId),
                itemId: Value(line.itemId),
                description: Value(line.description),
                quantity: Value(line.quantity),
                unitPrice: Value(line.unitPricePiasters),
                unitCost: Value(unitCost),
                totalPrice: Value(line.totalPricePiasters),
              ),
            );

        savedLines.add(
          InvoiceLineEntry(
            id: lineId,
            invoiceId: invoiceId,
            lineType: line.lineType,
            serviceId: line.serviceId,
            itemId: line.itemId,
            description: line.description,
            quantity: line.quantity,
            unitPricePiasters: line.unitPricePiasters,
            unitCostPiasters: unitCost,
            totalPricePiasters: line.totalPricePiasters,
          ),
        );
      }

      // 5. Record initial payment if any
      final payments = <Payment>[];
      if (paid > 0) {
        final paymentId = await _db.into(_db.payments).insert(
              PaymentsCompanion(
                invoiceId: Value(invoiceId),
                amount: Value(paid),
                paymentMethod: Value(paymentMethod),
                notes: Value(paymentNotes),
                paidAt: Value(DateTime.now()),
              ),
            );

        payments.add(
          Payment(
            id: paymentId,
            invoiceId: invoiceId,
            amount: paid,
            paymentMethod: paymentMethod,
            notes: paymentNotes,
            paidAt: DateTime.now(),
          ),
        );
      }

      Customer? customer;
      if (customerId != null) {
        customer = await (_db.select(_db.customers)..where((t) => t.id.equals(customerId))).getSingleOrNull();
      }

      final invoice = await (_db.select(_db.invoices)..where((t) => t.id.equals(invoiceId))).getSingle();

      return InvoiceWithDetails(
        invoice: invoice,
        customer: customer,
        lines: savedLines,
        payments: payments,
      );
    });
  }

  @override
  Future<void> recordPayment({
    required int invoiceId,
    required int amountPiasters,
    required PaymentMethod method,
    String? notes,
  }) async {
    await _db.transaction(() async {
      final invoice = await (_db.select(_db.invoices)..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
      if (invoice == null) {
        throw Exception('الفاتورة غير موجودة');
      }

      if (invoice.status == InvoiceStatus.cancelled) {
        throw Exception('لا يمكن تسجيل دفعات لفاتورة ملغاة');
      }

      final remaining = invoice.totalAmount - invoice.paidAmount;
      final paymentAmount = amountPiasters.clamp(1, remaining > 0 ? remaining : amountPiasters);

      await (_db.update(_db.invoices)..where((t) => t.id.equals(invoiceId))).write(
        InvoicesCompanion(
          paidAmount: Value(invoice.paidAmount + paymentAmount),
        ),
      );

      await _db.into(_db.payments).insert(
            PaymentsCompanion(
              invoiceId: Value(invoiceId),
              amount: Value(paymentAmount),
              paymentMethod: Value(method),
              notes: Value(notes),
              paidAt: Value(DateTime.now()),
            ),
          );
    });
  }

  @override
  Future<void> cancelInvoice({
    required int invoiceId,
    required String reason,
  }) async {
    await _db.transaction(() async {
      final invoice = await (_db.select(_db.invoices)..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
      if (invoice == null) {
        throw Exception('الفاتورة غير موجودة');
      }

      if (invoice.status == InvoiceStatus.cancelled) {
        throw Exception('الفاتورة ملغاة بالفعل');
      }

      // 1. Mark invoice as cancelled
      await (_db.update(_db.invoices)..where((t) => t.id.equals(invoiceId))).write(
        InvoicesCompanion(
          status: const Value(InvoiceStatus.cancelled),
          cancellationReason: Value(reason),
          cancelledAt: Value(DateTime.now()),
        ),
      );

      // 2. Reverse stock deductions for parts sold in this invoice (Rules R2, R3)
      final lines = await (_db.select(_db.invoiceLines)..where((t) => t.invoiceId.equals(invoiceId))).get();
      for (final line in lines) {
        if (line.itemId != null && line.quantity > 0) {
          await _stockService.addMovement(
            StockMovementsCompanion(
              itemId: Value(line.itemId!),
              movementType: const Value(StockMovementType.saleReturn),
              qty: Value(line.quantity), // positive to return to warehouse stock
              unitCost: Value(line.unitCost),
              refType: const Value('invoice'),
              refId: Value(invoiceId),
              notes: Value('مرتجع إلغاء فاتورة #${invoice.invoiceNumber}: $reason'),
            ),
          );
        }
      }
    });
  }

  @override
  Future<InvoicesSummary> getSummary() async {
    final issuedInvoices = await (_db.select(_db.invoices)
          ..where((t) => t.status.equals(InvoiceStatus.issued.index)))
        .get();

    int totalSales = 0;
    int totalPaid = 0;
    int totalRemaining = 0;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    int todaySales = 0;
    int todayCount = 0;

    for (final inv in issuedInvoices) {
      totalSales += inv.totalAmount;
      totalPaid += inv.paidAmount;
      final rem = (inv.totalAmount - inv.paidAmount).clamp(0, double.maxFinite.toInt());
      totalRemaining += rem;

      if (inv.issuedAt.isAfter(startOfToday)) {
        todaySales += inv.totalAmount;
        todayCount++;
      }
    }

    return InvoicesSummary(
      totalSalesPiasters: totalSales,
      totalCollectedPiasters: totalPaid,
      totalRemainingPiasters: totalRemaining,
      todaySalesPiasters: todaySales,
      todayInvoicesCount: todayCount,
      totalInvoicesCount: issuedInvoices.length,
    );
  }
}
