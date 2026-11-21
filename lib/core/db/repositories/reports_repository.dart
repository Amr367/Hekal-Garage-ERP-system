import 'package:drift/drift.dart';
import 'package:excel/excel.dart';

import '../../../features/reports/domain/debts_report_data.dart';
import '../../../features/reports/domain/inventory_report_data.dart';
import '../../../features/reports/domain/report_date_range.dart';
import '../../../features/reports/domain/sales_report_data.dart';
import '../database.dart';
import '../services/stock_service.dart';

abstract class ReportsRepository {
  Future<SalesReportData> getSalesReport(DateTime start, DateTime end);
  Future<InventoryReportData> getInventoryReport();
  Future<DebtsReportData> getDebtsReport();

  List<int> exportSalesReportToExcel(SalesReportData data, ReportDateRange range);
  List<int> exportProfitReportToExcel(SalesReportData data, ReportDateRange range);
  List<int> exportInventoryReportToExcel(InventoryReportData data);
  List<int> exportDebtsReportToExcel(DebtsReportData data);
}

class DriftReportsRepository implements ReportsRepository {
  const DriftReportsRepository(this._db, this._stockService);

  final AppDatabase _db;
  final StockService _stockService;

  @override
  Future<SalesReportData> getSalesReport(DateTime start, DateTime end) async {
    // 1. Fetch issued invoices within date range
    final invoiceQuery = _db.select(_db.invoices).join([
      leftOuterJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.invoices.customerId),
      ),
      leftOuterJoin(
        _db.workOrders,
        _db.workOrders.id.equalsExp(_db.invoices.workOrderId),
      ),
      leftOuterJoin(
        _db.vehicles,
        _db.vehicles.id.equalsExp(_db.workOrders.vehicleId),
      ),
    ]);

    invoiceQuery.where(
      _db.invoices.status.equals(InvoiceStatus.issued.index) &
          _db.invoices.issuedAt.isBiggerOrEqualValue(start) &
          _db.invoices.issuedAt.isSmallerOrEqualValue(end),
    );
    invoiceQuery.orderBy([OrderingTerm.desc(_db.invoices.issuedAt)]);

    final rows = await invoiceQuery.get();

    final invoiceIds = <int>[];
    for (final row in rows) {
      invoiceIds.add(row.readTable(_db.invoices).id);
    }

    // 2. Query all lines for these invoices to calculate parts vs services and parts cost
    int partsRevenue = 0;
    int servicesRevenue = 0;
    int partsCost = 0;

    if (invoiceIds.isNotEmpty) {
      final lines = await (_db.select(_db.invoiceLines)
            ..where((t) => t.invoiceId.isIn(invoiceIds)))
          .get();

      for (final line in lines) {
        if (line.lineType == LineType.part) {
          partsRevenue += line.totalPrice;
          partsCost += (line.quantity * line.unitCost).round();
        } else {
          servicesRevenue += line.totalPrice;
        }
      }
    }

    // 3. Query all payments for these invoices to compute payment method breakdown
    final paymentBreakdown = <PaymentMethod, int>{
      PaymentMethod.cash: 0,
      PaymentMethod.wallet: 0,
      PaymentMethod.instapay: 0,
      PaymentMethod.card: 0,
      PaymentMethod.transfer: 0,
    };

    if (invoiceIds.isNotEmpty) {
      final payments = await (_db.select(_db.payments)
            ..where((t) => t.invoiceId.isIn(invoiceIds)))
          .get();

      for (final p in payments) {
        paymentBreakdown[p.paymentMethod] =
            (paymentBreakdown[p.paymentMethod] ?? 0) + p.amount;
      }
    }

    // 4. Build invoice list rows
    final invoiceRows = <SalesReportInvoiceRow>[];
    int totalInvoiced = 0;
    int totalPaid = 0;

    for (final row in rows) {
      final inv = row.readTable(_db.invoices);
      final cust = row.readTableOrNull(_db.customers);
      final veh = row.readTableOrNull(_db.vehicles);

      totalInvoiced += inv.totalAmount;
      totalPaid += inv.paidAmount;

      // Find primary payment method for this invoice
      PaymentMethod method = PaymentMethod.cash;
      final paymentsForInv = await (_db.select(_db.payments)
            ..where((t) => t.invoiceId.equals(inv.id))
            ..limit(1))
          .get();
      if (paymentsForInv.isNotEmpty) {
        method = paymentsForInv.first.paymentMethod;
      }

      invoiceRows.add(
        SalesReportInvoiceRow(
          invoiceId: inv.id,
          invoiceNumber: inv.invoiceNumber,
          date: inv.issuedAt,
          customerName: cust?.name ?? 'عميل نقدي / غير مسجل',
          plateNumber: veh?.plateNumber ?? '-',
          totalAmountPiasters: inv.totalAmount,
          paidAmountPiasters: inv.paidAmount,
          paymentMethod: method,
          status: inv.status,
        ),
      );
    }

    // 5. Operating expenses and paid salaries within date range
    final expenseRows = await (_db.select(_db.expenses)
          ..where((t) =>
              t.expenseDate.isBiggerOrEqualValue(start) &
              t.expenseDate.isSmallerOrEqualValue(end)))
        .get();
    int totalOperatingExpenses = 0;
    for (final exp in expenseRows) {
      totalOperatingExpenses += exp.amount;
    }

    final salaryRows = await (_db.select(_db.salaryPayments)
          ..where((t) =>
              t.paymentDate.isBiggerOrEqualValue(start) &
              t.paymentDate.isSmallerOrEqualValue(end)))
        .get();
    int totalSalariesPaid = 0;
    for (final sal in salaryRows) {
      totalSalariesPaid += sal.netPaid;
    }

    final grossProfit = totalInvoiced - partsCost;

    return SalesReportData(
      totalInvoices: rows.length,
      partsRevenuePiasters: partsRevenue,
      servicesRevenuePiasters: servicesRevenue,
      totalRevenuePiasters: totalInvoiced,
      partsCostPiasters: partsCost,
      grossProfitPiasters: grossProfit,
      totalPaidPiasters: totalPaid,
      totalRemainingPiasters: totalInvoiced - totalPaid,
      paymentBreakdown: paymentBreakdown,
      invoices: invoiceRows,
      operatingExpensesPiasters: totalOperatingExpenses,
      salariesPaidPiasters: totalSalariesPaid,
    );
  }

  @override
  Future<InventoryReportData> getInventoryReport() async {
    // 1. Fetch all items with categories
    final query = _db.select(_db.items).join([
      innerJoin(
        _db.itemCategories,
        _db.itemCategories.id.equalsExp(_db.items.categoryId),
      ),
    ]);
    query.where(_db.items.isActive.equals(true));
    query.orderBy([OrderingTerm.asc(_db.items.name)]);

    final rows = await query.get();
    final stockMap = await _stockService.onHandMap();

    final reportItems = <InventoryReportItemRow>[];
    double totalOnHand = 0.0;
    int totalValuationCost = 0;
    int totalValuationSale = 0;
    int lowStock = 0;
    int outOfStock = 0;

    for (final row in rows) {
      final item = row.readTable(_db.items);
      final cat = row.readTable(_db.itemCategories);
      final qty = stockMap[item.id] ?? 0.0;

      totalOnHand += qty;
      totalValuationCost += (qty * item.costPrice).round();
      totalValuationSale += (qty * item.salePrice).round();

      if (qty <= 0) {
        outOfStock++;
      } else if (qty <= item.minQuantity) {
        lowStock++;
      }

      reportItems.add(
        InventoryReportItemRow(
          itemId: item.id,
          name: item.name,
          categoryName: cat.name,
          sku: item.sku,
          unit: item.unit,
          quantityOnHand: qty,
          costPricePiasters: item.costPrice,
          salePricePiasters: item.salePrice,
          minQuantity: item.minQuantity,
        ),
      );
    }

    // 2. Top moving items (most sold quantities)
    final topMovementsQuery = _db.selectOnly(_db.stockMovements)
      ..addColumns([
        _db.stockMovements.itemId,
        _db.stockMovements.qty.sum(),
      ])
      ..where(_db.stockMovements.movementType.equals(StockMovementType.saleOut.index))
      ..groupBy([_db.stockMovements.itemId])
      ..orderBy([OrderingTerm.asc(_db.stockMovements.qty.sum())]) // negative sum
      ..limit(10);

    final topRows = await topMovementsQuery.get();
    final topMoving = <TopMovingItemRow>[];

    for (final tr in topRows) {
      final itemId = tr.read(_db.stockMovements.itemId);
      final qtySum = tr.read(_db.stockMovements.qty.sum());
      if (itemId != null && qtySum != null) {
        final itemRow = reportItems.where((i) => i.itemId == itemId).firstOrNull;
        if (itemRow != null) {
          final soldQty = qtySum.abs();
          topMoving.add(
            TopMovingItemRow(
              itemId: itemId,
              name: itemRow.name,
              categoryName: itemRow.categoryName,
              totalSoldQty: soldQty,
              totalRevenuePiasters: (soldQty * itemRow.salePricePiasters).round(),
            ),
          );
        }
      }
    }

    // 3. Stagnant items (stock on hand > 0, but no movements in last 90 days)
    final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));
    final activeItemIdsQuery = _db.selectOnly(_db.stockMovements)
      ..addColumns([_db.stockMovements.itemId])
      ..where(_db.stockMovements.createdAt.isBiggerOrEqualValue(ninetyDaysAgo))
      ..groupBy([_db.stockMovements.itemId]);

    final activeItemRows = await activeItemIdsQuery.get();
    final recentActiveIds = <int>{};
    for (final r in activeItemRows) {
      final id = r.read(_db.stockMovements.itemId);
      if (id != null) recentActiveIds.add(id);
    }

    final stagnant = reportItems
        .where((i) => i.quantityOnHand > 0 && !recentActiveIds.contains(i.itemId))
        .toList();

    return InventoryReportData(
      totalItemsCount: reportItems.length,
      totalQuantityOnHand: totalOnHand,
      totalValuationCostPiasters: totalValuationCost,
      totalValuationSalePiasters: totalValuationSale,
      lowStockCount: lowStock,
      outOfStockCount: outOfStock,
      topMovingItems: topMoving,
      stagnantItems: stagnant,
      items: reportItems,
    );
  }

  @override
  Future<DebtsReportData> getDebtsReport() async {
    // 1. Customers with unpaid issued invoices
    final custInvoices = await (_db.select(_db.invoices).join([
      innerJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.invoices.customerId),
      ),
    ])
          ..where(_db.invoices.status.equals(InvoiceStatus.issued.index)))
        .get();

    final customerBalances = <int, int>{};
    final customerDetails = <int, Customer>{};

    for (final row in custInvoices) {
      final inv = row.readTable(_db.invoices);
      final cust = row.readTable(_db.customers);
      customerDetails[cust.id] = cust;

      final remaining = inv.totalAmount - inv.paidAmount;
      customerBalances[cust.id] = (customerBalances[cust.id] ?? 0) + remaining;
    }

    final customerDebts = <CustomerDebtRow>[];
    int totalCustomerDebt = 0;

    for (final entry in customerBalances.entries) {
      if (entry.value > 0) {
        totalCustomerDebt += entry.value;
        final cust = customerDetails[entry.key]!;
        customerDebts.add(
          CustomerDebtRow(
            customerId: cust.id,
            name: cust.name,
            phone: cust.phone ?? '-',
            balancePiasters: entry.value,
            lastVisit: null,
          ),
        );
      }
    }
    customerDebts.sort((a, b) => b.balancePiasters.compareTo(a.balancePiasters));

    // 2. Suppliers with unpaid purchases
    final purchases = await (_db.select(_db.purchaseInvoices).join([
      innerJoin(
        _db.suppliers,
        _db.suppliers.id.equalsExp(_db.purchaseInvoices.supplierId),
      ),
    ]))
        .get();

    final supplierBalances = <int, int>{};
    final supplierDetails = <int, Supplier>{};
    final supplierInvoicesCount = <int, int>{};

    for (final row in purchases) {
      final p = row.readTable(_db.purchaseInvoices);
      final s = row.readTable(_db.suppliers);
      supplierDetails[s.id] = s;
      supplierInvoicesCount[s.id] = (supplierInvoicesCount[s.id] ?? 0) + 1;

      final remaining = p.totalAmount - p.paidAmount;
      supplierBalances[s.id] = (supplierBalances[s.id] ?? 0) + remaining;
    }

    final supplierDebts = <SupplierDebtRow>[];
    int totalSupplierDebt = 0;

    for (final entry in supplierBalances.entries) {
      if (entry.value > 0) {
        totalSupplierDebt += entry.value;
        final s = supplierDetails[entry.key]!;
        supplierDebts.add(
          SupplierDebtRow(
            supplierId: s.id,
            name: s.name,
            phone: s.phone ?? '-',
            balancePiasters: entry.value,
            totalInvoicesCount: supplierInvoicesCount[s.id] ?? 0,
          ),
        );
      }
    }
    supplierDebts.sort((a, b) => b.balancePiasters.compareTo(a.balancePiasters));

    return DebtsReportData(
      totalCustomersDebtPiasters: totalCustomerDebt,
      totalSuppliersDebtPiasters: totalSupplierDebt,
      customersCountWithDebt: customerDebts.length,
      suppliersCountWithDebt: supplierDebts.length,
      customerDebts: customerDebts,
      supplierDebts: supplierDebts,
    );
  }

  @override
  List<int> exportSalesReportToExcel(SalesReportData data, ReportDateRange range) {
    final excel = Excel.createExcel();
    final sheet = excel['المبيعات'];
    excel.setDefaultSheet('المبيعات');
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Title & Header info
    sheet.appendRow([TextCellValue('تقرير المبيعات والإيرادات — ${range.label}')]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('إجمالي الفواتير'),
      IntCellValue(data.totalInvoices),
      TextCellValue('إجمالي الإيرادات'),
      DoubleCellValue(data.totalRevenuePiasters / 100),
      TextCellValue('إجمالي الأرباح'),
      DoubleCellValue(data.grossProfitPiasters / 100),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // Invoices table header
    sheet.appendRow([
      TextCellValue('رقم الفاتورة'),
      TextCellValue('التاريخ'),
      TextCellValue('اسم العميل'),
      TextCellValue('رقم اللوحة'),
      TextCellValue('الإجمالي (ج.م)'),
      TextCellValue('المدفوع (ج.م)'),
      TextCellValue('المتبقي (ج.م)'),
      TextCellValue('طريقة السداد'),
    ]);

    for (final inv in data.invoices) {
      sheet.appendRow([
        TextCellValue('#${inv.invoiceNumber}'),
        TextCellValue(inv.date.toString().split(' ')[0]),
        TextCellValue(inv.customerName),
        TextCellValue(inv.plateNumber),
        DoubleCellValue(inv.totalAmountPiasters / 100),
        DoubleCellValue(inv.paidAmountPiasters / 100),
        DoubleCellValue(inv.remainingPiasters / 100),
        TextCellValue(inv.paymentMethodLabel),
      ]);
    }

    return excel.encode()!;
  }

  @override
  List<int> exportProfitReportToExcel(SalesReportData data, ReportDateRange range) {
    final excel = Excel.createExcel();
    final sheet = excel['الأرباح'];
    excel.setDefaultSheet('الأرباح');
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    sheet.appendRow([TextCellValue('تقرير الأرباح وهوامش الربح — ${range.label}')]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('إجمالي المبيعات (ج.م)'),
      DoubleCellValue(data.totalRevenuePiasters / 100),
      TextCellValue('تكلفة قطع الغيار (ج.م)'),
      DoubleCellValue(data.partsCostPiasters / 100),
      TextCellValue('إجمالي الربح (Gross Profit) (ج.م)'),
      DoubleCellValue(data.grossProfitPiasters / 100),
      TextCellValue('هامش الربح الإجمالي %'),
      TextCellValue(data.formattedProfitMargin),
    ]);
    sheet.appendRow([
      TextCellValue('إيراد القطع (ج.م)'),
      DoubleCellValue(data.partsRevenuePiasters / 100),
      TextCellValue('إيراد المصنعيات (ج.م)'),
      DoubleCellValue(data.servicesRevenuePiasters / 100),
      TextCellValue('مصروفات المركز التشغيلية (ج.م)'),
      DoubleCellValue(data.operatingExpensesPiasters / 100),
      TextCellValue('الرواتب المنصرفة (ج.م)'),
      DoubleCellValue(data.salariesPaidPiasters / 100),
    ]);
    sheet.appendRow([
      TextCellValue('صافي الربح التشغيلي (Net Profit) (ج.م)'),
      DoubleCellValue(data.netOperatingProfitPiasters / 100),
      TextCellValue('هامش صافي الربح %'),
      TextCellValue(data.formattedNetProfitMargin),
    ]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('رقم الفاتورة'),
      TextCellValue('التاريخ'),
      TextCellValue('اسم العميل'),
      TextCellValue('الإجمالي (ج.م)'),
      TextCellValue('المدفوع (ج.م)'),
      TextCellValue('المتبقي (ج.م)'),
    ]);

    for (final inv in data.invoices) {
      sheet.appendRow([
        TextCellValue('#${inv.invoiceNumber}'),
        TextCellValue(inv.date.toString().split(' ')[0]),
        TextCellValue(inv.customerName),
        DoubleCellValue(inv.totalAmountPiasters / 100),
        DoubleCellValue(inv.paidAmountPiasters / 100),
        DoubleCellValue(inv.remainingPiasters / 100),
      ]);
    }

    return excel.encode()!;
  }

  @override
  List<int> exportInventoryReportToExcel(InventoryReportData data) {
    final excel = Excel.createExcel();
    final sheet = excel['المخزون'];
    excel.setDefaultSheet('المخزون');
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    sheet.appendRow([TextCellValue('تقرير تقييم وحركة المخزون')]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('عدد الأصناف'),
      IntCellValue(data.totalItemsCount),
      TextCellValue('قيمة التكلفة (ج.م)'),
      DoubleCellValue(data.totalValuationCostPiasters / 100),
      TextCellValue('قيمة البيع (ج.م)'),
      DoubleCellValue(data.totalValuationSalePiasters / 100),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('اسم الصنف'),
      TextCellValue('القسم'),
      TextCellValue('الباركود / SKU'),
      TextCellValue('الوحدة'),
      TextCellValue('الرصيد المتاح'),
      TextCellValue('سعر الشراء (ج.م)'),
      TextCellValue('سعر البيع (ج.م)'),
      TextCellValue('إجمالي التكلفة (ج.م)'),
      TextCellValue('إجمالي البيع (ج.م)'),
    ]);

    for (final item in data.items) {
      sheet.appendRow([
        TextCellValue(item.name),
        TextCellValue(item.categoryName),
        TextCellValue(item.sku ?? '-'),
        TextCellValue(item.unit),
        DoubleCellValue(item.quantityOnHand),
        DoubleCellValue(item.costPricePiasters / 100),
        DoubleCellValue(item.salePricePiasters / 100),
        DoubleCellValue(item.totalCostValuePiasters / 100),
        DoubleCellValue(item.totalSaleValuePiasters / 100),
      ]);
    }

    return excel.encode()!;
  }

  @override
  List<int> exportDebtsReportToExcel(DebtsReportData data) {
    final excel = Excel.createExcel();

    // Sheet 1: Customers Debt
    final custSheet = excel['ديون العملاء'];
    excel.setDefaultSheet('ديون العملاء');
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    custSheet.appendRow([TextCellValue('تقرير مديونيات العملاء')]);
    custSheet.appendRow([
      TextCellValue('إجمالي ديون العملاء'),
      DoubleCellValue(data.totalCustomersDebtPiasters / 100),
    ]);
    custSheet.appendRow([TextCellValue('')]);
    custSheet.appendRow([
      TextCellValue('اسم العميل'),
      TextCellValue('رقم الهاتف'),
      TextCellValue('الرصيد المستحق (ج.م)'),
    ]);

    for (final c in data.customerDebts) {
      custSheet.appendRow([
        TextCellValue(c.name),
        TextCellValue(c.phone),
        DoubleCellValue(c.balancePiasters / 100),
      ]);
    }

    // Sheet 2: Suppliers Debt
    final supSheet = excel['مستحقات الموردين'];
    supSheet.appendRow([TextCellValue('تقرير مستحقات الموردين')]);
    supSheet.appendRow([
      TextCellValue('إجمالي مستحقات الموردين'),
      DoubleCellValue(data.totalSuppliersDebtPiasters / 100),
    ]);
    supSheet.appendRow([TextCellValue('')]);
    supSheet.appendRow([
      TextCellValue('اسم المورد'),
      TextCellValue('رقم الهاتف'),
      TextCellValue('عدد الفواتير'),
      TextCellValue('الرصيد المتبقي (ج.م)'),
    ]);

    for (final s in data.supplierDebts) {
      supSheet.appendRow([
        TextCellValue(s.name),
        TextCellValue(s.phone),
        IntCellValue(s.totalInvoicesCount),
        DoubleCellValue(s.balancePiasters / 100),
      ]);
    }

    return excel.encode()!;
  }
}
