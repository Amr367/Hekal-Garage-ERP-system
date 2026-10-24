import 'package:drift/drift.dart';

import '../../errors/app_exceptions.dart';
import '../../strings.dart';
import '../../utils/formatters.dart';
import '../database.dart';
import '../services/stock_service.dart';
import '../../../features/work_orders/domain/work_order_line_item.dart';
import '../../../features/work_orders/domain/work_order_summary.dart';
import '../../../features/work_orders/domain/work_order_with_details.dart';

abstract interface class WorkOrdersRepository {
  Future<List<WorkOrderWithDetails>> getWorkOrders({
    String? query,
    WorkOrderStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<WorkOrderWithDetails> getWorkOrderById(int id);

  Future<WorkOrderWithDetails> createWorkOrder({
    required int customerId,
    required int vehicleId,
    int? odometer,
    String? complaint,
    String? mechanicName,
    String? notes,
    List<WorkOrderLineItem> lines = const [],
  });

  Future<WorkOrderWithDetails> updateWorkOrder({
    required int id,
    int? odometer,
    String? complaint,
    String? mechanicName,
    String? notes,
    List<WorkOrderLineItem>? lines,
  });

  Future<void> updateStatus({
    required int id,
    required WorkOrderStatus status,
    String? cancellationReason,
  });

  Future<WorkOrderWithDetails> deliverWorkOrder({
    required int id,
    required PaymentMethod paymentMethod,
    int? paidAmountPiasters,
    int? discountAmountPiasters,
    String? paymentReference,
    String? deliveryNotes,
  });

  Future<void> deleteWorkOrder(int id);

  Future<WorkOrderSummary> getWorkOrderSummary();
}

class DriftWorkOrdersRepository implements WorkOrdersRepository {
  DriftWorkOrdersRepository(this._db, [StockService? stockService])
      : _stockService = stockService ?? StockService(_db);

  final AppDatabase _db;
  final StockService _stockService;

  @override
  Future<List<WorkOrderWithDetails>> getWorkOrders({
    String? query,
    WorkOrderStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final queryBuilder = _db.select(_db.workOrders).join([
      innerJoin(_db.customers, _db.customers.id.equalsExp(_db.workOrders.customerId)),
      innerJoin(_db.vehicles, _db.vehicles.id.equalsExp(_db.workOrders.vehicleId)),
    ]);

    if (status != null) {
      queryBuilder.where(_db.workOrders.status.equals(status.index));
    }

    if (fromDate != null) {
      queryBuilder.where(_db.workOrders.createdAt.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      queryBuilder.where(_db.workOrders.createdAt.isSmallerOrEqualValue(toDate));
    }

    if (query != null && query.trim().isNotEmpty) {
      final trimmed = query.trim();
      if (trimmed.startsWith('#')) {
        final numPart = int.tryParse(trimmed.substring(1));
        if (numPart != null) {
          queryBuilder.where(_db.workOrders.orderNumber.equals(numPart));
        }
      } else {
        final normalizedPlate = Formatters.normalizePlateNumber(trimmed);
        final asInt = int.tryParse(trimmed);

        queryBuilder.where(
          _db.customers.name.like('%$trimmed%') |
              _db.customers.phone.like('%$trimmed%') |
              _db.vehicles.plateNumber.like('%$trimmed%') |
              _db.vehicles.plateNumber.like('%$normalizedPlate%') |
              (asInt != null ? _db.workOrders.orderNumber.equals(asInt) : const Constant(false)),
        );
      }
    }

    queryBuilder.orderBy([
      OrderingTerm.desc(_db.workOrders.createdAt),
      OrderingTerm.desc(_db.workOrders.id),
    ]);

    final rows = await queryBuilder.get();
    if (rows.isEmpty) return <WorkOrderWithDetails>[];

    final workOrderIds = rows.map((r) => r.readTable(_db.workOrders).id).toList();

    // Fetch lines for all returned work orders
    final linesQuery = _db.select(_db.workOrderLines).join([
      leftOuterJoin(_db.items, _db.items.id.equalsExp(_db.workOrderLines.itemId)),
    ])..where(_db.workOrderLines.workOrderId.isIn(workOrderIds));

    final lineRows = await linesQuery.get();

    // Group lines by workOrderId
    final linesByOrder = <int, List<WorkOrderLineItem>>{};
    for (final lRow in lineRows) {
      final line = lRow.readTable(_db.workOrderLines);
      final item = lRow.readTableOrNull(_db.items);
      final lineItem = WorkOrderLineItem.fromDb(line, unit: item?.unit);
      linesByOrder.putIfAbsent(line.workOrderId, () => <WorkOrderLineItem>[]).add(lineItem);
    }

    // Fetch issued invoices for these work orders
    final invoiceRows = await (_db.select(_db.invoices)
          ..where((t) => t.workOrderId.isIn(workOrderIds)))
        .get();
    final invoicesByOrder = <int, Invoice>{};
    final invoiceIds = <int>[];
    for (final inv in invoiceRows) {
      if (inv.workOrderId != null) {
        invoicesByOrder[inv.workOrderId!] = inv;
        invoiceIds.add(inv.id);
      }
    }

    // Fetch payments for these invoices
    final paymentRows = invoiceIds.isNotEmpty
        ? await (_db.select(_db.payments)..where((t) => t.invoiceId.isIn(invoiceIds))).get()
        : <Payment>[];
    final paymentsByInvoice = <int, List<Payment>>{};
    for (final p in paymentRows) {
      paymentsByInvoice.putIfAbsent(p.invoiceId, () => <Payment>[]).add(p);
    }

    final result = <WorkOrderWithDetails>[];
    for (final row in rows) {
      final order = row.readTable(_db.workOrders);
      final customer = row.readTable(_db.customers);
      final vehicle = row.readTable(_db.vehicles);
      final lines = linesByOrder[order.id] ?? <WorkOrderLineItem>[];
      final invoice = invoicesByOrder[order.id];
      final payments = invoice != null ? (paymentsByInvoice[invoice.id] ?? <Payment>[]) : const <Payment>[];

      result.add(
        WorkOrderWithDetails(
          workOrder: order,
          customer: customer,
          vehicle: vehicle,
          lines: lines,
          hasInvoice: invoice != null,
          invoice: invoice,
          payments: payments,
        ),
      );
    }

    return result;
  }

  @override
  Future<WorkOrderWithDetails> getWorkOrderById(int id) async {
    final queryBuilder = _db.select(_db.workOrders).join([
      innerJoin(_db.customers, _db.customers.id.equalsExp(_db.workOrders.customerId)),
      innerJoin(_db.vehicles, _db.vehicles.id.equalsExp(_db.workOrders.vehicleId)),
    ])..where(_db.workOrders.id.equals(id));

    final row = await queryBuilder.getSingleOrNull();
    if (row == null) {
      throw NotFoundException('أمر الشغل برقم ($id) غير موجود.');
    }

    final order = row.readTable(_db.workOrders);
    final customer = row.readTable(_db.customers);
    final vehicle = row.readTable(_db.vehicles);

    // Fetch lines with items info & onHand stock
    final linesQuery = _db.select(_db.workOrderLines).join([
      leftOuterJoin(_db.items, _db.items.id.equalsExp(_db.workOrderLines.itemId)),
    ])..where(_db.workOrderLines.workOrderId.equals(id));

    final lineRows = await linesQuery.get();
    final lines = <WorkOrderLineItem>[];

    for (final lRow in lineRows) {
      final line = lRow.readTable(_db.workOrderLines);
      final item = lRow.readTableOrNull(_db.items);
      double? onHand;
      if (line.itemId != null) {
        onHand = await _db.stockOf(line.itemId!);
      }
      lines.add(WorkOrderLineItem.fromDb(line, unit: item?.unit, stock: onHand));
    }

    // Check if an invoice exists and load its payments
    final invoice = await (_db.select(_db.invoices)..where((t) => t.workOrderId.equals(id))).getSingleOrNull();
    final payments = invoice != null
        ? await (_db.select(_db.payments)..where((t) => t.invoiceId.equals(invoice.id))).get()
        : const <Payment>[];

    return WorkOrderWithDetails(
      workOrder: order,
      customer: customer,
      vehicle: vehicle,
      lines: lines,
      hasInvoice: invoice != null,
      invoice: invoice,
      payments: payments,
    );
  }

  @override
  Future<WorkOrderWithDetails> createWorkOrder({
    required int customerId,
    required int vehicleId,
    int? odometer,
    String? complaint,
    String? mechanicName,
    String? notes,
    List<WorkOrderLineItem> lines = const [],
  }) async {
    return _db.transaction(() async {
      // Validate customer and vehicle exist
      final customer = await (_db.select(_db.customers)..where((t) => t.id.equals(customerId))).getSingleOrNull();
      if (customer == null) {
        throw const NotFoundException('العميل المحدد غير موجود.');
      }

      final vehicle = await (_db.select(_db.vehicles)..where((t) => t.id.equals(vehicleId))).getSingleOrNull();
      if (vehicle == null) {
        throw const NotFoundException('السيارة المحددة غير موجودة.');
      }

      // Generate next sequential order number (Rule R6)
      final nextOrderNumber = await _db.nextWorkOrderNumber();

      final workOrderId = await _db.into(_db.workOrders).insert(
        WorkOrdersCompanion(
          orderNumber: Value(nextOrderNumber),
          customerId: Value(customerId),
          vehicleId: Value(vehicleId),
          status: const Value(WorkOrderStatus.open),
          odometer: Value(odometer),
          complaint: Value(complaint),
          mechanicName: Value(mechanicName),
          notes: Value(notes),
          createdAt: Value(DateTime.now()),
        ),
      );

      // Insert line items
      for (final line in lines) {
        await _db.into(_db.workOrderLines).insert(
          WorkOrderLinesCompanion(
            workOrderId: Value(workOrderId),
            lineType: Value(line.lineType),
            serviceId: Value(line.serviceId),
            itemId: Value(line.itemId),
            description: Value(line.description),
            quantity: Value(line.quantity),
            unitPrice: Value(line.unitPrice),
            totalPrice: Value(line.totalPrice),
          ),
        );
      }

      // Update vehicle's current odometer if new reading is higher
      if (odometer != null && (vehicle.lastOdometer == null || odometer > vehicle.lastOdometer!)) {
        await (_db.update(_db.vehicles)..where((t) => t.id.equals(vehicleId))).write(
          VehiclesCompanion(lastOdometer: Value(odometer)),
        );
      }

      return getWorkOrderById(workOrderId);
    });
  }

  @override
  Future<WorkOrderWithDetails> updateWorkOrder({
    required int id,
    int? odometer,
    String? complaint,
    String? mechanicName,
    String? notes,
    List<WorkOrderLineItem>? lines,
  }) async {
    return _db.transaction(() async {
      final existing = await (_db.select(_db.workOrders)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        throw NotFoundException('أمر الشغل برقم ($id) غير موجود.');
      }

      if (existing.status == WorkOrderStatus.delivered || existing.status == WorkOrderStatus.cancelled) {
        throw const BusinessRuleException('لا يمكن تعديل أمر شغل في حالة مسلّم أو ملغي.');
      }

      // Check if invoice exists
      final invoice = await (_db.select(_db.invoices)..where((t) => t.workOrderId.equals(id))).getSingleOrNull();
      if (invoice != null) {
        throw const BusinessRuleException(AppStrings.cannotDeleteInvoicedOrder);
      }

      await (_db.update(_db.workOrders)..where((t) => t.id.equals(id))).write(
        WorkOrdersCompanion(
          odometer: Value(odometer),
          complaint: Value(complaint),
          mechanicName: Value(mechanicName),
          notes: Value(notes),
        ),
      );

      if (lines != null) {
        // Replace existing lines
        await (_db.delete(_db.workOrderLines)..where((t) => t.workOrderId.equals(id))).go();

        for (final line in lines) {
          await _db.into(_db.workOrderLines).insert(
            WorkOrderLinesCompanion(
              workOrderId: Value(id),
              lineType: Value(line.lineType),
              serviceId: Value(line.serviceId),
              itemId: Value(line.itemId),
              description: Value(line.description),
              quantity: Value(line.quantity),
              unitPrice: Value(line.unitPrice),
              totalPrice: Value(line.totalPrice),
            ),
          );
        }
      }

      // Update vehicle odometer if higher
      if (odometer != null) {
        final vehicle = await (_db.select(_db.vehicles)..where((t) => t.id.equals(existing.vehicleId))).getSingleOrNull();
        if (vehicle != null && (vehicle.lastOdometer == null || odometer > vehicle.lastOdometer!)) {
          await (_db.update(_db.vehicles)..where((t) => t.id.equals(existing.vehicleId))).write(
            VehiclesCompanion(lastOdometer: Value(odometer)),
          );
        }
      }

      return getWorkOrderById(id);
    });
  }

  @override
  Future<void> updateStatus({
    required int id,
    required WorkOrderStatus status,
    String? cancellationReason,
  }) async {
    final existing = await (_db.select(_db.workOrders)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw NotFoundException('أمر الشغل برقم ($id) غير موجود.');
    }

    if (existing.status == WorkOrderStatus.cancelled) {
      throw const BusinessRuleException('أمر الشغل ملغي بالفعل ولا يمكن تعديل حالته.');
    }

    if (existing.status == WorkOrderStatus.delivered && status == WorkOrderStatus.cancelled) {
      throw const BusinessRuleException(AppStrings.cannotCancelDeliveredOrder);
    }

    final isClosing = status == WorkOrderStatus.ready || status == WorkOrderStatus.delivered;
    final closedAt = isClosing ? DateTime.now() : existing.closedAt;

    await (_db.update(_db.workOrders)..where((t) => t.id.equals(id))).write(
      WorkOrdersCompanion(
        status: Value(status),
        closedAt: Value(closedAt),
        cancellationReason: status == WorkOrderStatus.cancelled
            ? Value(cancellationReason)
            : const Value.absent(),
      ),
    );
  }

  @override
  Future<WorkOrderWithDetails> deliverWorkOrder({
    required int id,
    required PaymentMethod paymentMethod,
    int? paidAmountPiasters,
    int? discountAmountPiasters,
    String? paymentReference,
    String? deliveryNotes,
  }) async {
    return _db.transaction(() async {
      final existing = await (_db.select(_db.workOrders)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        throw NotFoundException('أمر الشغل برقم ($id) غير موجود.');
      }

      if (existing.status == WorkOrderStatus.cancelled) {
        throw const BusinessRuleException('لا يمكن تسليم أمر شغل ملغي.');
      }

      // 1. Check or issue invoice
      var invoice = await (_db.select(_db.invoices)..where((t) => t.workOrderId.equals(id))).getSingleOrNull();
      int invoiceId;
      int invoiceTotal;

      if (invoice == null) {
        final lines = await (_db.select(_db.workOrderLines)..where((t) => t.workOrderId.equals(id))).get();

        int subtotal = 0;
        for (final l in lines) {
          subtotal += l.totalPrice;
        }

        final discount = discountAmountPiasters ?? 0;
        invoiceTotal = (subtotal - discount).clamp(0, double.maxFinite.toInt());
        final paid = (paidAmountPiasters ?? invoiceTotal).clamp(0, double.maxFinite.toInt());

        final invoiceNumber = await _db.nextInvoiceNumber();

        invoiceId = await _db.into(_db.invoices).insert(
          InvoicesCompanion(
            invoiceNumber: Value(invoiceNumber),
            workOrderId: Value(id),
            customerId: Value(existing.customerId),
            subtotal: Value(subtotal),
            discountAmount: Value(discount),
            totalAmount: Value(invoiceTotal),
            paidAmount: Value(paid),
            status: const Value(InvoiceStatus.issued),
            notes: Value(deliveryNotes),
            issuedAt: Value(DateTime.now()),
          ),
        );

        // Record invoice lines and deduct parts from warehouse stock (Rules R2, R3, R4, R8)
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
                notes: Value('صرف لمركبة أمر شغل #${existing.orderNumber}'),
              ),
            );
          }

          await _db.into(_db.invoiceLines).insert(
            InvoiceLinesCompanion(
              invoiceId: Value(invoiceId),
              lineType: Value(line.lineType),
              serviceId: Value(line.serviceId),
              itemId: Value(line.itemId),
              description: Value(line.description),
              quantity: Value(line.quantity),
              unitPrice: Value(line.unitPrice),
              unitCost: Value(unitCost),
              totalPrice: Value(line.totalPrice),
            ),
          );
        }
      } else {
        invoiceId = invoice.id;
        invoiceTotal = invoice.totalAmount;
        final additionalPaid = (paidAmountPiasters ?? (invoice.totalAmount - invoice.paidAmount)).clamp(0, double.maxFinite.toInt());
        if (additionalPaid > 0) {
          await (_db.update(_db.invoices)..where((t) => t.id.equals(invoiceId))).write(
            InvoicesCompanion(
              paidAmount: Value(invoice.paidAmount + additionalPaid),
            ),
          );
        }
      }

      // 2. Record Payment Entry
      final paymentAmount = (paidAmountPiasters ?? invoiceTotal).clamp(0, double.maxFinite.toInt());
      if (paymentAmount > 0) {
        await _db.into(_db.payments).insert(
          PaymentsCompanion(
            invoiceId: Value(invoiceId),
            amount: Value(paymentAmount),
            paymentMethod: Value(paymentMethod),
            notes: Value(paymentReference != null && paymentReference.trim().isNotEmpty ? paymentReference.trim() : null),
            paidAt: Value(DateTime.now()),
          ),
        );
      }

      // 3. Update Work Order status to delivered
      await (_db.update(_db.workOrders)..where((t) => t.id.equals(id))).write(
        WorkOrdersCompanion(
          status: const Value(WorkOrderStatus.delivered),
          closedAt: Value(DateTime.now()),
          notes: Value(deliveryNotes ?? existing.notes),
        ),
      );

      return getWorkOrderById(id);
    });
  }

  @override
  Future<void> deleteWorkOrder(int id) async {
    return _db.transaction(() async {
      final existing = await (_db.select(_db.workOrders)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        throw NotFoundException('أمر الشغل برقم ($id) غير موجود.');
      }

      // Check for invoices per Domain Rule R10
      final invoice = await (_db.select(_db.invoices)..where((t) => t.workOrderId.equals(id))).getSingleOrNull();
      if (invoice != null) {
        throw const BusinessRuleException(AppStrings.cannotDeleteInvoicedOrder);
      }

      await (_db.delete(_db.workOrderLines)..where((t) => t.workOrderId.equals(id))).go();
      await (_db.delete(_db.workOrders)..where((t) => t.id.equals(id))).go();
    });
  }

  @override
  Future<WorkOrderSummary> getWorkOrderSummary() async {
    final allOrders = await _db.select(_db.workOrders).get();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    int openCount = 0;
    int inProgressCount = 0;
    int readyCount = 0;
    int todayCount = 0;
    final activeOrderIds = <int>[];

    for (final o in allOrders) {
      if (o.status == WorkOrderStatus.open) {
        openCount++;
        activeOrderIds.add(o.id);
      } else if (o.status == WorkOrderStatus.inProgress) {
        inProgressCount++;
        activeOrderIds.add(o.id);
      } else if (o.status == WorkOrderStatus.ready) {
        readyCount++;
        activeOrderIds.add(o.id);
      }

      if (o.createdAt.isAfter(todayStart) && o.createdAt.isBefore(tomorrowStart)) {
        todayCount++;
      }
    }

    int openValuePiasters = 0;
    if (activeOrderIds.isNotEmpty) {
      final sumQuery = _db.selectOnly(_db.workOrderLines)
        ..addColumns([_db.workOrderLines.totalPrice.sum()])
        ..where(_db.workOrderLines.workOrderId.isIn(activeOrderIds));
      final sumRow = await sumQuery.getSingle();
      openValuePiasters = sumRow.read(_db.workOrderLines.totalPrice.sum()) ?? 0;
    }

    return WorkOrderSummary(
      openOrdersCount: openCount,
      inProgressOrdersCount: inProgressCount,
      readyOrdersCount: readyCount,
      todayOrdersCount: todayCount,
      estimatedOpenValuePiasters: openValuePiasters,
    );
  }
}
