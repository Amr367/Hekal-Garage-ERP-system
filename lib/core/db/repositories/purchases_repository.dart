import 'package:drift/drift.dart';

import '../../../features/purchases/domain/purchase_invoice_with_details.dart';
import '../../../features/purchases/domain/purchase_line_item.dart';
import '../../../features/purchases/domain/purchases_summary.dart';
import '../../errors/app_exceptions.dart';
import '../../money/money.dart';
import '../database.dart';
import '../services/stock_service.dart';

/// Line item input for creating a purchase invoice.
class PurchaseLineInput {
  const PurchaseLineInput({
    required this.itemId,
    required this.quantity,
    required this.unitCostPiasters,
  });

  final int itemId;
  final double quantity;
  final int unitCostPiasters;
}

abstract interface class PurchasesRepository {
  Future<PurchaseInvoiceWithDetails> createPurchaseInvoice({
    required int supplierId,
    String? supplierInvoiceNumber,
    required DateTime invoiceDate,
    required int paidAmountPiasters,
    String? notes,
    required List<PurchaseLineInput> lines,
  });

  Future<List<PurchaseInvoiceWithDetails>> getPurchaseInvoices({
    String? searchQuery,
    int? supplierId,
  });

  Future<PurchaseInvoiceWithDetails> getPurchaseInvoiceById(int id);

  Future<PurchasesSummary> getPurchasesSummary();
}

class DriftPurchasesRepository implements PurchasesRepository {
  const DriftPurchasesRepository(this._db, this._stockService);

  final AppDatabase _db;
  final StockService _stockService;

  @override
  Future<PurchaseInvoiceWithDetails> createPurchaseInvoice({
    required int supplierId,
    String? supplierInvoiceNumber,
    required DateTime invoiceDate,
    required int paidAmountPiasters,
    String? notes,
    required List<PurchaseLineInput> lines,
  }) async {
    if (lines.isEmpty) {
      throw const ValidationException('يرجى إضافة صنف واحد على الأقل لفاتورة الشراء.');
    }

    // Verify supplier exists and is active
    final supplier = await (_db.select(_db.suppliers)..where((t) => t.id.equals(supplierId))).getSingleOrNull();
    if (supplier == null) {
      throw const NotFoundException('المورد المحدد غير مسجل بقاعدة البيانات.');
    }

    // Calculate total
    int totalPiasters = 0;
    for (final line in lines) {
      if (line.quantity <= 0) {
        throw const ValidationException('كمية الصنف يجب أن تكون أكبر من صفر.');
      }
      if (line.unitCostPiasters < 0) {
        throw const ValidationException('سعر شراء الوحدة لا يمكن أن يكون سالباً.');
      }
      final lineTotal = (line.quantity * line.unitCostPiasters).round();
      totalPiasters += lineTotal;
    }

    if (paidAmountPiasters < 0) {
      throw const ValidationException('المبلغ المدفوع لا يمكن أن يكون سالباً.');
    }

    return _db.transaction(() async {
      // 1. Insert Purchase Invoice
      final invoiceId = await _db.into(_db.purchaseInvoices).insert(
        PurchaseInvoicesCompanion(
          supplierId: Value(supplierId),
          supplierInvoiceNumber: Value(supplierInvoiceNumber?.trim()),
          invoiceDate: Value(invoiceDate),
          totalAmount: Value(totalPiasters),
          paidAmount: Value(paidAmountPiasters),
          notes: Value(notes?.trim()),
          createdAt: Value(DateTime.now()),
        ),
      );

      final List<PurchaseLineItem> createdLines = [];

      // 2. Insert lines, record stock movements, and update items cost price
      for (final line in lines) {
        final lineTotal = (line.quantity * line.unitCostPiasters).round();

        // Query item details
        final item = await (_db.select(_db.items)..where((t) => t.id.equals(line.itemId))).getSingle();

        await _db.into(_db.purchaseInvoiceLines).insert(
          PurchaseInvoiceLinesCompanion(
            purchaseInvoiceId: Value(invoiceId),
            itemId: Value(line.itemId),
            quantity: Value(line.quantity),
            unitCost: Value(line.unitCostPiasters),
            totalAmount: Value(lineTotal),
          ),
        );

        // Record stock in movement (Rule R2, R3)
        await _stockService.addMovement(
          StockMovementsCompanion(
            itemId: Value(line.itemId),
            movementType: const Value(StockMovementType.purchaseIn),
            qty: Value(line.quantity),
            unitCost: Value(line.unitCostPiasters),
            refType: const Value('purchase'),
            refId: Value(invoiceId),
            notes: Value(supplierInvoiceNumber != null && supplierInvoiceNumber.isNotEmpty
                ? 'فاتورة شراء $supplierInvoiceNumber من ${supplier.name}'
                : 'فاتورة شراء من ${supplier.name}'),
          ),
        );

        // Update item's latest cost price (Rule R8)
        if (line.unitCostPiasters > 0) {
          await (_db.update(_db.items)..where((t) => t.id.equals(line.itemId))).write(
            ItemsCompanion(
              costPrice: Value(line.unitCostPiasters),
            ),
          );
        }

        createdLines.add(
          PurchaseLineItem(
            itemId: item.id,
            itemName: item.name,
            itemSku: item.sku,
            itemUnit: item.unit,
            quantity: line.quantity,
            unitCostPiasters: line.unitCostPiasters,
            totalAmountPiasters: lineTotal,
          ),
        );
      }

      final insertedInvoice = await (_db.select(_db.purchaseInvoices)..where((t) => t.id.equals(invoiceId))).getSingle();

      return PurchaseInvoiceWithDetails(
        invoice: insertedInvoice,
        supplier: supplier,
        lines: createdLines,
      );
    });
  }

  @override
  Future<List<PurchaseInvoiceWithDetails>> getPurchaseInvoices({
    String? searchQuery,
    int? supplierId,
  }) async {
    final query = _db.select(_db.purchaseInvoices).join([
      innerJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.purchaseInvoices.supplierId)),
    ]);

    if (supplierId != null) {
      query.where(_db.purchaseInvoices.supplierId.equals(supplierId));
    }

    final trimmed = searchQuery?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      final normalized = MoneyUtils.normalizeDigits(trimmed);
      query.where(
        _db.suppliers.name.like('%$trimmed%') |
        _db.suppliers.phone.like('%$normalized%') |
        _db.purchaseInvoices.supplierInvoiceNumber.like('%$trimmed%') |
        _db.purchaseInvoices.id.cast<String>().like('%$trimmed%'),
      );
    }

    query.orderBy([
      OrderingTerm(expression: _db.purchaseInvoices.invoiceDate, mode: OrderingMode.desc),
      OrderingTerm(expression: _db.purchaseInvoices.id, mode: OrderingMode.desc),
    ]);

    final rows = await query.get();

    // Query lines for each purchase invoice
    final List<PurchaseInvoiceWithDetails> results = [];

    for (final row in rows) {
      final invoice = row.readTable(_db.purchaseInvoices);
      final supplier = row.readTable(_db.suppliers);

      final linesQuery = _db.select(_db.purchaseInvoiceLines).join([
        innerJoin(_db.items, _db.items.id.equalsExp(_db.purchaseInvoiceLines.itemId)),
      ])..where(_db.purchaseInvoiceLines.purchaseInvoiceId.equals(invoice.id));

      final lineRows = await linesQuery.get();

      final lines = lineRows.map((lr) {
        final line = lr.readTable(_db.purchaseInvoiceLines);
        final item = lr.readTable(_db.items);
        return PurchaseLineItem(
          itemId: item.id,
          itemName: item.name,
          itemSku: item.sku,
          itemUnit: item.unit,
          quantity: line.quantity,
          unitCostPiasters: line.unitCost,
          totalAmountPiasters: line.totalAmount,
        );
      }).toList();

      results.add(
        PurchaseInvoiceWithDetails(
          invoice: invoice,
          supplier: supplier,
          lines: lines,
        ),
      );
    }

    return results;
  }

  @override
  Future<PurchaseInvoiceWithDetails> getPurchaseInvoiceById(int id) async {
    final query = _db.select(_db.purchaseInvoices).join([
      innerJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.purchaseInvoices.supplierId)),
    ])..where(_db.purchaseInvoices.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) {
      throw NotFoundException('فاتورة الشراء رقم ($id) غير موجودة.');
    }

    final invoice = row.readTable(_db.purchaseInvoices);
    final supplier = row.readTable(_db.suppliers);

    final linesQuery = _db.select(_db.purchaseInvoiceLines).join([
      innerJoin(_db.items, _db.items.id.equalsExp(_db.purchaseInvoiceLines.itemId)),
    ])..where(_db.purchaseInvoiceLines.purchaseInvoiceId.equals(invoice.id));

    final lineRows = await linesQuery.get();

    final lines = lineRows.map((lr) {
      final line = lr.readTable(_db.purchaseInvoiceLines);
      final item = lr.readTable(_db.items);
      return PurchaseLineItem(
        itemId: item.id,
        itemName: item.name,
        itemSku: item.sku,
        itemUnit: item.unit,
        quantity: line.quantity,
        unitCostPiasters: line.unitCost,
        totalAmountPiasters: line.totalAmount,
      );
    }).toList();

    return PurchaseInvoiceWithDetails(
      invoice: invoice,
      supplier: supplier,
      lines: lines,
    );
  }

  @override
  Future<PurchasesSummary> getPurchasesSummary() async {
    final invoices = await _db.select(_db.purchaseInvoices).get();

    int totalPurchases = 0;
    int totalPaid = 0;
    int thisMonthPurchases = 0;

    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    for (final inv in invoices) {
      totalPurchases += inv.totalAmount;
      totalPaid += inv.paidAmount;

      if (inv.invoiceDate.year == currentYear && inv.invoiceDate.month == currentMonth) {
        thisMonthPurchases += inv.totalAmount;
      }
    }

    final totalDebt = totalPurchases - totalPaid;

    final activeSuppliers = await (_db.select(_db.suppliers)
          ..where((t) => t.isActive.equals(true)))
        .get();

    return PurchasesSummary(
      totalPurchasesPiasters: totalPurchases,
      totalSuppliersDebtPiasters: totalDebt > 0 ? totalDebt : 0,
      activeSuppliersCount: activeSuppliers.length,
      thisMonthPurchasesPiasters: thisMonthPurchases,
    );
  }
}
