import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repositories/expenses_repository.dart';
import '../widgets/state_views.dart';
import '../../features/inventory/domain/item_with_stock.dart';
import '../../features/invoices/domain/invoice_with_details.dart';
import '../../features/purchases/domain/purchase_invoice_with_details.dart';
import '../../features/reports/domain/debts_report_data.dart';
import '../../features/reports/domain/inventory_report_data.dart';
import '../../features/reports/domain/report_date_range.dart';
import '../../features/reports/domain/sales_report_data.dart';

/// Centralized service for generating and exporting Excel (.xlsx) files
/// for inventory (المخزن), financial accounts (المصروفات، الإيرادات، المشتريات، الديون),
/// and comprehensive reports (التقرير المالي الشامل).
abstract final class ExcelExportService {
  /// Prompts the user with a Windows save dialog and writes the Excel bytes to disk.
  static Future<bool> saveExcelFile({
    required BuildContext context,
    required List<int> bytes,
    required String defaultFileName,
    required String dialogTitle,
    String successMessage = 'تم تصدير ملف الإكسيل بنجاح',
  }) async {
    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: defaultFileName.endsWith('.xlsx')
            ? defaultFileName
            : '$defaultFileName.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (savePath == null) return false;

      final fullPath =
          savePath.endsWith('.xlsx') ? savePath : '$savePath.xlsx';
      final file = File(fullPath);
      await file.writeAsBytes(Uint8List.fromList(bytes));

      if (context.mounted) {
        AppSnackbar.showSuccess(context, successMessage);
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'فشل حفظ ملف الإكسيل: $e');
      }
      return false;
    }
  }

  // ── 1. Inventory Export (تصدير كشف أصناف المخزن) ───────────────────────────

  /// Exports warehouse items list to an Excel workbook with complete valuation,
  /// quantities, prices, barcodes, and profit margins.
  static List<int> exportInventoryItemsToExcel(
    List<ItemWithStock> items, {
    String? categoryFilterName,
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'أصناف المخزن';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Computed summary metrics
    int totalCostValuation = 0;
    int totalSaleValuation = 0;
    int lowStockCount = 0;
    int outOfStockCount = 0;

    for (final item in items) {
      totalCostValuation += item.stockValueCost;
      totalSaleValuation += item.stockValueSale;
      if (item.isOutOfStock) {
        outOfStockCount++;
      } else if (item.isLowStock) {
        lowStockCount++;
      }
    }

    final now = DateTime.now();
    final dateStr =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    // Title & Meta
    sheet.appendRow([
      TextCellValue(
        'كشف جرد وتقييم أصناف المخزن — تاريخ التصدير: $dateStr'
        '${categoryFilterName != null ? " (قسم: $categoryFilterName)" : ""}',
      ),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // KPI Summary Row
    sheet.appendRow([
      TextCellValue('إجمالي عدد الأصناف:'),
      IntCellValue(items.length),
      TextCellValue('إجمالي التكلفة (ج.م):'),
      DoubleCellValue(totalCostValuation / 100),
      TextCellValue('إجمالي البيع (ج.م):'),
      DoubleCellValue(totalSaleValuation / 100),
      TextCellValue('منخفض الرصيد:'),
      IntCellValue(lowStockCount),
      TextCellValue('نافد الرصيد:'),
      IntCellValue(outOfStockCount),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // Table Header
    sheet.appendRow([
      TextCellValue('م'),
      TextCellValue('اسم الصنف'),
      TextCellValue('القسم'),
      TextCellValue('كود الصنف (SKU)'),
      TextCellValue('الباركود'),
      TextCellValue('الوحدة'),
      TextCellValue('الرصيد المتاح'),
      TextCellValue('حد الطلب الأدنى'),
      TextCellValue('سعر الشراء (ج.م)'),
      TextCellValue('سعر البيع (ج.م)'),
      TextCellValue('إجمالي التكلفة (ج.م)'),
      TextCellValue('إجمالي البيع (ج.م)'),
      TextCellValue('هامش الربح %'),
      TextCellValue('حالة المخزون'),
      TextCellValue('الحالة'),
    ]);

    // Data rows
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final statusLabel = item.isOutOfStock
          ? 'نافد'
          : item.isLowStock
              ? 'منخفض'
              : 'متوفر';
      final activeLabel = item.isActive ? 'نشط' : 'معطل';
      final marginStr =
          '${item.profitMarginPercentage.toStringAsFixed(1)}%';

      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(item.name),
        TextCellValue(item.categoryName),
        TextCellValue(item.sku ?? '-'),
        TextCellValue(item.barcode ?? '-'),
        TextCellValue(item.unit),
        DoubleCellValue(item.stockOnHand),
        DoubleCellValue(item.item.minQuantity),
        DoubleCellValue(item.costPrice / 100),
        DoubleCellValue(item.salePrice / 100),
        DoubleCellValue(item.stockValueCost / 100),
        DoubleCellValue(item.stockValueSale / 100),
        TextCellValue(marginStr),
        TextCellValue(statusLabel),
        TextCellValue(activeLabel),
      ]);
    }

    return excel.encode()!;
  }

  // ── 2. Expenses Export (تصدير المصروفات) ───────────────────────────────────

  /// Exports list of expenses to Excel.
  static List<int> exportExpensesToExcel(
    List<ExpenseWithDetails> expenses, {
    String? categoryFilter,
    DateTime? start,
    DateTime? end,
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'المصروفات';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    int totalPiasters = 0;
    for (final e in expenses) {
      totalPiasters += e.amountPiasters;
    }

    final now = DateTime.now();
    final dateStr =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    sheet.appendRow([
      TextCellValue(
        'كشف المصروفات والمنصرفات — تاريخ التصدير: $dateStr'
        '${categoryFilter != null && categoryFilter != "الكل" ? " (تصنيف: $categoryFilter)" : ""}',
      ),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('إجمالي عدد الإيصالات:'),
      IntCellValue(expenses.length),
      TextCellValue('إجمالي المصروفات (ج.م):'),
      DoubleCellValue(totalPiasters / 100),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('م'),
      TextCellValue('التاريخ'),
      TextCellValue('البند / التصنيف'),
      TextCellValue('البيان / الوصف'),
      TextCellValue('المدفوع له'),
      TextCellValue('طريقة الدفع'),
      TextCellValue('رقم الإيصال'),
      TextCellValue('المبلغ (ج.م)'),
      TextCellValue('ملاحظات'),
    ]);

    for (int i = 0; i < expenses.length; i++) {
      final exp = expenses[i];
      final expDate = exp.expenseDate;
      final dateFormatted =
          '${expDate.year}/${expDate.month.toString().padLeft(2, '0')}/${expDate.day.toString().padLeft(2, '0')}';

      final methodLabel = switch (exp.paymentMethod) {
        PaymentMethod.cash => 'خزنة / كاش',
        PaymentMethod.wallet => 'محفظة إلكترونية',
        PaymentMethod.instapay => 'انستاباي',
        PaymentMethod.card => 'فيزا / كارت',
        PaymentMethod.transfer => 'تحويل بنكي',
      };

      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(dateFormatted),
        TextCellValue(exp.category),
        TextCellValue(exp.description),
        TextCellValue(exp.paidTo ?? '-'),
        TextCellValue(methodLabel),
        TextCellValue(exp.receiptNumber ?? '-'),
        DoubleCellValue(exp.amountPiasters / 100),
        TextCellValue(exp.notes ?? '-'),
      ]);
    }

    return excel.encode()!;
  }

  // ── 3. Purchases Export (تصدير المشتريات) ──────────────────────────────────

  /// Exports purchase invoices to Excel.
  static List<int> exportPurchasesToExcel(
    List<PurchaseInvoiceWithDetails> purchases,
  ) {
    final excel = Excel.createExcel();
    const sheetName = 'المشتريات والتوريدات';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    int totalPurchases = 0;
    int totalPaid = 0;
    int totalRemaining = 0;

    for (final p in purchases) {
      totalPurchases += p.totalAmountPiasters;
      totalPaid += p.paidAmountPiasters;
      totalRemaining += p.remainingAmountPiasters;
    }

    final now = DateTime.now();
    final dateStr =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    sheet.appendRow([
      TextCellValue('كشف فواتير المشتريات والتوريدات — تاريخ: $dateStr'),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('عدد الفواتير:'),
      IntCellValue(purchases.length),
      TextCellValue('إجمالي المشتريات (ج.م):'),
      DoubleCellValue(totalPurchases / 100),
      TextCellValue('المسدد للموردين (ج.م):'),
      DoubleCellValue(totalPaid / 100),
      TextCellValue('المتبقي للموردين (ج.م):'),
      DoubleCellValue(totalRemaining / 100),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('م'),
      TextCellValue('رقم الفاتورة'),
      TextCellValue('رقم فاتورة المورد'),
      TextCellValue('التاريخ'),
      TextCellValue('اسم المورد'),
      TextCellValue('هاتف المورد'),
      TextCellValue('إجمالي الفاتورة (ج.م)'),
      TextCellValue('المدفوع (ج.م)'),
      TextCellValue('المتبقي (ج.م)'),
      TextCellValue('حالة السداد'),
      TextCellValue('عدد البنود'),
      TextCellValue('ملاحظات'),
    ]);

    for (int i = 0; i < purchases.length; i++) {
      final p = purchases[i];
      final d = p.invoiceDate;
      final dateFormatted =
          '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue('#${p.id}'),
        TextCellValue(p.supplierInvoiceNumber ?? '-'),
        TextCellValue(dateFormatted),
        TextCellValue(p.supplier.name),
        TextCellValue(p.supplier.phone ?? '-'),
        DoubleCellValue(p.totalAmountPiasters / 100),
        DoubleCellValue(p.paidAmountPiasters / 100),
        DoubleCellValue(p.remainingAmountPiasters / 100),
        TextCellValue(p.paymentStatusArabic),
        IntCellValue(p.lines.length),
        TextCellValue(p.notes ?? '-'),
      ]);
    }

    return excel.encode()!;
  }

  // ── 4. Invoices Export (تصدير فواتير المبيعات) ─────────────────────────────

  /// Exports sales invoices to Excel.
  static List<int> exportInvoicesToExcel(
    List<InvoiceWithDetails> invoices,
  ) {
    final excel = Excel.createExcel();
    const sheetName = 'فواتير المبيعات';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    int totalAmount = 0;
    int totalPaid = 0;
    int totalRemaining = 0;

    for (final inv in invoices) {
      if (!inv.isCancelled) {
        totalAmount += inv.totalPiasters;
        totalPaid += inv.paidPiasters;
        totalRemaining += inv.remainingPiasters;
      }
    }

    final now = DateTime.now();
    final dateStr =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    sheet.appendRow([
      TextCellValue('كشف فواتير المبيعات والإيرادات — تاريخ: $dateStr'),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('عدد الفواتير:'),
      IntCellValue(invoices.length),
      TextCellValue('إجمالي المبيعات (ج.م):'),
      DoubleCellValue(totalAmount / 100),
      TextCellValue('إجمالي المحصل (ج.م):'),
      DoubleCellValue(totalPaid / 100),
      TextCellValue('إجمالي الآجل (ج.م):'),
      DoubleCellValue(totalRemaining / 100),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('م'),
      TextCellValue('رقم الفاتورة'),
      TextCellValue('التاريخ'),
      TextCellValue('اسم العميل'),
      TextCellValue('هاتف العميل'),
      TextCellValue('السيارة / اللوحة'),
      TextCellValue('المبلغ قبل الخصم (ج.م)'),
      TextCellValue('الخصم (ج.م)'),
      TextCellValue('الإجمالي (ج.م)'),
      TextCellValue('المدفوع (ج.م)'),
      TextCellValue('المتبقي (ج.م)'),
      TextCellValue('طريقة السداد'),
      TextCellValue('حالة الفاتورة'),
    ]);

    for (int i = 0; i < invoices.length; i++) {
      final inv = invoices[i];
      final d = inv.invoice.issuedAt;
      final dateFormatted =
          '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

      final statusLabel = inv.isCancelled
          ? 'ملغاة'
          : inv.isPaid
              ? 'مدفوعة بالكامل'
              : inv.isPartiallyPaid
                  ? 'سداد جزئي'
                  : 'آجل / غير مسددة';

      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue('#${inv.invoiceNumber}'),
        TextCellValue(dateFormatted),
        TextCellValue(inv.customerName),
        TextCellValue(inv.customerPhone),
        TextCellValue(inv.vehicleTitle),
        DoubleCellValue(inv.subtotalPiasters / 100),
        DoubleCellValue(inv.discountPiasters / 100),
        DoubleCellValue(inv.totalPiasters / 100),
        DoubleCellValue(inv.paidPiasters / 100),
        DoubleCellValue(inv.remainingPiasters / 100),
        TextCellValue(inv.paymentMethodLabel),
        TextCellValue(statusLabel),
      ]);
    }

    return excel.encode()!;
  }

  // ── 5. Comprehensive Financial Report (التقرير المالي الشامل المجمع) ────────

  /// Exports ALL financial data into a single master Excel workbook with multiple sheets:
  /// - Sheet 1: الملخص المالي الشامل (Executive Summary & Profit/Loss)
  /// - Sheet 2: المبيعات والإيرادات (Sales Invoices)
  /// - Sheet 3: المصروفات والمنصرفات (Expenses)
  /// - Sheet 4: المشتريات والتوريدات (Purchases)
  /// - Sheet 5: ديون العملاء (Customer Debts)
  /// - Sheet 6: مستحقات الموردين (Supplier Payables)
  /// - Sheet 7: تقييم المخزون (Inventory Valuation)
  static List<int> exportComprehensiveFinancialReportToExcel({
    required SalesReportData salesData,
    required List<ExpenseWithDetails> expenses,
    required List<PurchaseInvoiceWithDetails> purchases,
    required DebtsReportData debtsData,
    required InventoryReportData inventoryData,
    required ReportDateRange range,
  }) {
    final excel = Excel.createExcel();

    // ── Sheet 1: الملخص المالي الشامل ──────────────────────────────────────
    const summarySheetName = 'الملخص المالي الشامل';
    final summarySheet = excel[summarySheetName];
    excel.setDefaultSheet(summarySheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final now = DateTime.now();
    final dateStr =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    summarySheet.appendRow([
      TextCellValue('التقرير المالي الشامل — مركز الصيانة والمستودع'),
    ]);
    summarySheet.appendRow([
      TextCellValue('الفترة: ${range.label} | تاريخ استخراج التقرير: $dateStr'),
    ]);
    summarySheet.appendRow([TextCellValue('')]);

    // Section 1: المبيعات والإيرادات
    summarySheet.appendRow([TextCellValue('== 1. المبيعات والإيرادات ==')]);
    summarySheet.appendRow([
      TextCellValue('إجمالي عدد الفواتير'),
      IntCellValue(salesData.totalInvoices),
      TextCellValue('إجمالي المبيعات (ج.م)'),
      DoubleCellValue(salesData.totalRevenuePiasters / 100),
    ]);
    summarySheet.appendRow([
      TextCellValue('إيرادات مبيعات قطع الغيار (ج.م)'),
      DoubleCellValue(salesData.partsRevenuePiasters / 100),
      TextCellValue('إيرادات أجور المصنعيات والخدمات (ج.م)'),
      DoubleCellValue(salesData.servicesRevenuePiasters / 100),
    ]);
    summarySheet.appendRow([
      TextCellValue('إجمالي المحصل نقداً وبنكياً (ج.م)'),
      DoubleCellValue(salesData.totalPaidPiasters / 100),
      TextCellValue('إجمالي الآجل المتبقي على العملاء بالفترة (ج.م)'),
      DoubleCellValue(salesData.totalRemainingPiasters / 100),
    ]);
    summarySheet.appendRow([TextCellValue('')]);

    // Section 2: تكلفة البضاعة المباعة ومجمل الربح
    summarySheet.appendRow([TextCellValue('== 2. تكلفة المبيعات ومجمل الربح ==')]);
    summarySheet.appendRow([
      TextCellValue('تكلفة قطع الغيار المباعة (ج.م)'),
      DoubleCellValue(salesData.partsCostPiasters / 100),
      TextCellValue('مجمل الربح التجاري (Gross Profit) (ج.م)'),
      DoubleCellValue(salesData.grossProfitPiasters / 100),
      TextCellValue('هامش مجمل الربح %'),
      TextCellValue(salesData.formattedProfitMargin),
    ]);
    summarySheet.appendRow([TextCellValue('')]);

    // Section 3: المصروفات والرواتب
    int totalOperatingExpenses = 0;
    for (final e in expenses) {
      totalOperatingExpenses += e.amountPiasters;
    }
    final totalExpensesAndSalaries =
        totalOperatingExpenses + salesData.salariesPaidPiasters;
    final netOperatingProfit =
        salesData.grossProfitPiasters - totalExpensesAndSalaries;
    final netMarginPercent = salesData.totalRevenuePiasters > 0
        ? (netOperatingProfit / salesData.totalRevenuePiasters) * 100
        : 0.0;

    summarySheet.appendRow([TextCellValue('== 3. المصروفات التشغيلية والرواتب ==')]);
    summarySheet.appendRow([
      TextCellValue('مصروفات المركز والتشغيل (ج.م)'),
      DoubleCellValue(totalOperatingExpenses / 100),
      TextCellValue('الرواتب والأجور المنصرفة (ج.م)'),
      DoubleCellValue(salesData.salariesPaidPiasters / 100),
      TextCellValue('إجمالي المصروفات والنفقات (ج.م)'),
      DoubleCellValue(totalExpensesAndSalaries / 100),
    ]);
    summarySheet.appendRow([TextCellValue('')]);

    // Section 4: صافي الربح التشغيلي
    summarySheet.appendRow([TextCellValue('== 4. صافي الأرباح (Net Profit) ==')]);
    summarySheet.appendRow([
      TextCellValue('صافي الربح التشغيلي (ج.م)'),
      DoubleCellValue(netOperatingProfit / 100),
      TextCellValue('هامش صافي الربح %'),
      TextCellValue('${netMarginPercent.toStringAsFixed(1)}%'),
    ]);
    summarySheet.appendRow([TextCellValue('')]);

    // Section 5: المشتريات والتوريدات
    int totalPurchasesPiasters = 0;
    int totalPurchasesPaidPiasters = 0;
    for (final p in purchases) {
      totalPurchasesPiasters += p.totalAmountPiasters;
      totalPurchasesPaidPiasters += p.paidAmountPiasters;
    }
    summarySheet.appendRow([TextCellValue('== 5. المشتريات والتوريدات ==')]);
    summarySheet.appendRow([
      TextCellValue('إجمالي مشتريات الفترة (ج.م)'),
      DoubleCellValue(totalPurchasesPiasters / 100),
      TextCellValue('المسدد للموردين بالفترة (ج.م)'),
      DoubleCellValue(totalPurchasesPaidPiasters / 100),
      TextCellValue('المتبقي للموردين بالفترة (ج.م)'),
      DoubleCellValue(
        (totalPurchasesPiasters - totalPurchasesPaidPiasters) / 100,
      ),
    ]);
    summarySheet.appendRow([TextCellValue('')]);

    // Section 6: مديونيات العملاء ومستحقات الموردين القائمة
    summarySheet.appendRow([TextCellValue('== 6. الذمم والمديونيات القائمة ==')]);
    summarySheet.appendRow([
      TextCellValue('إجمالي ديون العملاء المستحقة (ج.م)'),
      DoubleCellValue(debtsData.totalCustomersDebtPiasters / 100),
      TextCellValue('عدد العملاء المدينين'),
      IntCellValue(debtsData.customersCountWithDebt),
    ]);
    summarySheet.appendRow([
      TextCellValue('إجمالي مستحقات الموردين القائمة (ج.م)'),
      DoubleCellValue(debtsData.totalSuppliersDebtPiasters / 100),
      TextCellValue('عدد الموردين المستحق لهم'),
      IntCellValue(debtsData.suppliersCountWithDebt),
    ]);
    summarySheet.appendRow([TextCellValue('')]);

    // Section 7: تقييم بضاعة المخزن
    summarySheet.appendRow([TextCellValue('== 7. تقييم بضاعة المخزن الحالي ==')]);
    summarySheet.appendRow([
      TextCellValue('عدد الأصناف بالمخزن'),
      IntCellValue(inventoryData.totalItemsCount),
      TextCellValue('قيمة المخزون بسعر الشراء (التكلفة) (ج.م)'),
      DoubleCellValue(inventoryData.totalValuationCostPiasters / 100),
      TextCellValue('قيمة المخزون بسعر البيع (ج.م)'),
      DoubleCellValue(inventoryData.totalValuationSalePiasters / 100),
      TextCellValue('الأرباح المتوقعة بالمخزن (ج.م)'),
      DoubleCellValue(
        (inventoryData.totalValuationSalePiasters -
                inventoryData.totalValuationCostPiasters) /
            100,
      ),
    ]);

    // ── Sheet 2: المبيعات والإيرادات ─────────────────────────────────────────
    final salesSheet = excel['المبيعات والإيرادات'];
    salesSheet.appendRow([TextCellValue('سجل فواتير المبيعات والإيرادات')]);
    salesSheet.appendRow([TextCellValue('')]);
    salesSheet.appendRow([
      TextCellValue('م'),
      TextCellValue('رقم الفاتورة'),
      TextCellValue('التاريخ'),
      TextCellValue('اسم العميل'),
      TextCellValue('رقم اللوحة'),
      TextCellValue('الإجمالي (ج.م)'),
      TextCellValue('المدفوع (ج.م)'),
      TextCellValue('المتبقي (ج.م)'),
      TextCellValue('طريقة السداد'),
    ]);
    for (int i = 0; i < salesData.invoices.length; i++) {
      final inv = salesData.invoices[i];
      final d = inv.date;
      final dateFormatted =
          '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
      salesSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue('#${inv.invoiceNumber}'),
        TextCellValue(dateFormatted),
        TextCellValue(inv.customerName),
        TextCellValue(inv.plateNumber),
        DoubleCellValue(inv.totalAmountPiasters / 100),
        DoubleCellValue(inv.paidAmountPiasters / 100),
        DoubleCellValue(inv.remainingPiasters / 100),
        TextCellValue(inv.paymentMethodLabel),
      ]);
    }

    // ── Sheet 3: المصروفات والمنصرفات ─────────────────────────────────────────
    final expSheet = excel['المصروفات والمنصرفات'];
    expSheet.appendRow([TextCellValue('سجل المصروفات والمنصرفات')]);
    expSheet.appendRow([TextCellValue('')]);
    expSheet.appendRow([
      TextCellValue('م'),
      TextCellValue('التاريخ'),
      TextCellValue('التصنيف'),
      TextCellValue('البيان / الوصف'),
      TextCellValue('المدفوع له'),
      TextCellValue('المبلغ (ج.م)'),
      TextCellValue('رقم الإيصال'),
      TextCellValue('ملاحظات'),
    ]);
    for (int i = 0; i < expenses.length; i++) {
      final exp = expenses[i];
      final d = exp.expenseDate;
      final dateFormatted =
          '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
      expSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(dateFormatted),
        TextCellValue(exp.category),
        TextCellValue(exp.description),
        TextCellValue(exp.paidTo ?? '-'),
        DoubleCellValue(exp.amountPiasters / 100),
        TextCellValue(exp.receiptNumber ?? '-'),
        TextCellValue(exp.notes ?? '-'),
      ]);
    }

    // ── Sheet 4: المشتريات والتوريدات ─────────────────────────────────────────
    final purchSheet = excel['المشتريات والتوريدات'];
    purchSheet.appendRow([TextCellValue('سجل فواتير المشتريات والتوريدات')]);
    purchSheet.appendRow([TextCellValue('')]);
    purchSheet.appendRow([
      TextCellValue('م'),
      TextCellValue('رقم الفاتورة'),
      TextCellValue('رقم فاتورة المورد'),
      TextCellValue('التاريخ'),
      TextCellValue('اسم المورد'),
      TextCellValue('هاتف المورد'),
      TextCellValue('الإجمالي (ج.م)'),
      TextCellValue('المدفوع (ج.م)'),
      TextCellValue('المتبقي (ج.م)'),
      TextCellValue('حالة السداد'),
    ]);
    for (int i = 0; i < purchases.length; i++) {
      final p = purchases[i];
      final d = p.invoiceDate;
      final dateFormatted =
          '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
      purchSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue('#${p.id}'),
        TextCellValue(p.supplierInvoiceNumber ?? '-'),
        TextCellValue(dateFormatted),
        TextCellValue(p.supplier.name),
        TextCellValue(p.supplier.phone ?? '-'),
        DoubleCellValue(p.totalAmountPiasters / 100),
        DoubleCellValue(p.paidAmountPiasters / 100),
        DoubleCellValue(p.remainingAmountPiasters / 100),
        TextCellValue(p.paymentStatusArabic),
      ]);
    }

    // ── Sheet 5: ديون العملاء ─────────────────────────────────────────────────
    final custSheet = excel['ديون العملاء'];
    custSheet.appendRow([TextCellValue('كشف مديونيات وحسابات العملاء')]);
    custSheet.appendRow([TextCellValue('')]);
    custSheet.appendRow([
      TextCellValue('م'),
      TextCellValue('اسم العميل'),
      TextCellValue('رقم الهاتف'),
      TextCellValue('الرصيد المدين المستحق (ج.م)'),
      TextCellValue('تاريخ آخر تعامل'),
    ]);
    for (int i = 0; i < debtsData.customerDebts.length; i++) {
      final c = debtsData.customerDebts[i];
      final lastVisitStr = c.lastVisit != null
          ? '${c.lastVisit!.year}/${c.lastVisit!.month.toString().padLeft(2, '0')}/${c.lastVisit!.day.toString().padLeft(2, '0')}'
          : '-';
      custSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(c.name),
        TextCellValue(c.phone),
        DoubleCellValue(c.balancePiasters / 100),
        TextCellValue(lastVisitStr),
      ]);
    }

    // ── Sheet 6: مستحقات الموردين ─────────────────────────────────────────────
    final supSheet = excel['مستحقات الموردين'];
    supSheet.appendRow([TextCellValue('كشف مستحقات وحسابات الموردين')]);
    supSheet.appendRow([TextCellValue('')]);
    supSheet.appendRow([
      TextCellValue('م'),
      TextCellValue('اسم المورد'),
      TextCellValue('رقم الهاتف'),
      TextCellValue('المبلغ المستحق للمورد (ج.م)'),
      TextCellValue('عدد فواتير الشراء'),
    ]);
    for (int i = 0; i < debtsData.supplierDebts.length; i++) {
      final s = debtsData.supplierDebts[i];
      supSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(s.name),
        TextCellValue(s.phone),
        DoubleCellValue(s.balancePiasters / 100),
        IntCellValue(s.totalInvoicesCount),
      ]);
    }

    // ── Sheet 7: تقييم المخزون ─────────────────────────────────────────────────
    final invSheet = excel['تقييم المخزون'];
    invSheet.appendRow([TextCellValue('كشف تقييم أصناف المخزن')]);
    invSheet.appendRow([TextCellValue('')]);
    invSheet.appendRow([
      TextCellValue('م'),
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
    for (int i = 0; i < inventoryData.items.length; i++) {
      final it = inventoryData.items[i];
      invSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(it.name),
        TextCellValue(it.categoryName),
        TextCellValue(it.sku ?? '-'),
        TextCellValue(it.unit),
        DoubleCellValue(it.quantityOnHand),
        DoubleCellValue(it.costPricePiasters / 100),
        DoubleCellValue(it.salePricePiasters / 100),
        DoubleCellValue(it.totalCostValuePiasters / 100),
        DoubleCellValue(it.totalSaleValuePiasters / 100),
      ]);
    }

    return excel.encode()!;
  }

  // ── 6. Inventory Template & Import Helpers ─────────────────────────────────

  /// Generates a blank Excel template for importing items into the inventory warehouse.
  static List<int> exportInventoryTemplateToExcel() {
    final excel = Excel.createExcel();
    const sheetName = 'نموذج إدخال أصناف';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    sheet.appendRow([
      TextCellValue(
        'نموذج استيراد أصناف إلى مخزن الورشة — املأ البيانات واحفظ الملف بصيغة .xlsx',
      ),
    ]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue('م'),
      TextCellValue('اسم الصنف * (مطلوب)'),
      TextCellValue('القسم / التصنيف'),
      TextCellValue('كود الصنف (SKU)'),
      TextCellValue('الباركود'),
      TextCellValue('الوحدة'),
      TextCellValue('سعر التكلفة (ج.م)'),
      TextCellValue('سعر البيع (ج.م)'),
      TextCellValue('الرصيد الافتتاحي بالمخزن'),
      TextCellValue('حد الطلب الأدنى'),
    ]);

    // Example sample rows
    sheet.appendRow([
      const IntCellValue(1),
      TextCellValue('فلتر زيت أصلي'),
      TextCellValue('فلاتر'),
      TextCellValue('FLT-001'),
      TextCellValue('6221000111222'),
      TextCellValue('قطعة'),
      const DoubleCellValue(180.0),
      const DoubleCellValue(250.0),
      const DoubleCellValue(10.0),
      const DoubleCellValue(3.0),
    ]);
    sheet.appendRow([
      const IntCellValue(2),
      TextCellValue('تيل فرامل أمامي'),
      TextCellValue('فرامل وتيل'),
      TextCellValue('BRK-002'),
      TextCellValue('6221000333444'),
      TextCellValue('طقم'),
      const DoubleCellValue(350.0),
      const DoubleCellValue(500.0),
      const DoubleCellValue(6.0),
      const DoubleCellValue(2.0),
    ]);

    return excel.encode()!;
  }

  /// Parses items from an Excel file to prepare them for importing into the inventory.
  static List<ParsedInventoryExcelRow> parseInventoryItemsFromExcel(
    List<int> bytes,
  ) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];

    final sheet = excel.tables.values.first;
    final results = <ParsedInventoryExcelRow>[];

    int startRow = 1;
    if (sheet.maxRows > 1 &&
        sheet.rows[0].where((c) => c != null && c.value != null).length <= 2) {
      startRow = 2;
    }
    if (sheet.maxRows > startRow) {
      final candidate = sheet.rows[startRow - 1]
          .map((c) => c?.value?.toString().trim() ?? '')
          .toList();
      if (!candidate.any((h) => h.contains('اسم') || h.contains('الصنف'))) {
        if (sheet.rows[startRow]
            .map((c) => c?.value?.toString().trim() ?? '')
            .any((h) => h.contains('اسم') || h.contains('الصنف'))) {
          startRow++;
        }
      }
    }

    for (int r = startRow; r < sheet.maxRows; r++) {
      final row = sheet.rows[r];
      if (row.isEmpty) continue;

      String getCellText(int col) {
        if (col >= row.length) return '';
        final val = row[col]?.value;
        if (val == null) return '';
        return val.toString().trim();
      }

      double getCellNum(int col) {
        if (col >= row.length) return 0.0;
        final val = row[col]?.value;
        if (val == null) return 0.0;
        if (val is DoubleCellValue) return val.value;
        if (val is IntCellValue) return val.value.toDouble();
        return double.tryParse(val.toString().replaceAll(',', '').trim()) ?? 0.0;
      }

      int colOffset = 0;
      final col0Text = getCellText(0);
      final col1Text = getCellText(1);
      if (int.tryParse(col0Text) != null && col1Text.isNotEmpty) {
        colOffset = 1;
      }

      final name = getCellText(colOffset + 0);
      if (name.isEmpty) continue;

      final category = getCellText(colOffset + 1);
      final sku = getCellText(colOffset + 2);
      final barcode = getCellText(colOffset + 3);
      final unit = getCellText(colOffset + 4);
      final costPounds = getCellNum(colOffset + 5);
      final salePounds = getCellNum(colOffset + 6);
      final stockQty = getCellNum(colOffset + 7);
      final minQty = getCellNum(colOffset + 8);

      results.add(
        ParsedInventoryExcelRow(
          rowIndex: r + 1,
          name: name,
          categoryName: category.isNotEmpty ? category : null,
          sku: sku.isNotEmpty ? sku : null,
          barcode: barcode.isNotEmpty ? barcode : null,
          unit: unit.isNotEmpty ? unit : 'قطعة',
          costPrice: (costPounds * 100).round(),
          salePrice: (salePounds * 100).round(),
          openingStock: stockQty,
          minQuantity: minQty,
        ),
      );
    }

    return results;
  }
}

/// Helper model representing a parsed row from an Excel inventory import sheet.
class ParsedInventoryExcelRow {
  const ParsedInventoryExcelRow({
    required this.rowIndex,
    required this.name,
    this.categoryName,
    this.sku,
    this.barcode,
    this.unit = 'قطعة',
    this.costPrice = 0,
    this.salePrice = 0,
    this.openingStock = 0.0,
    this.minQuantity = 0.0,
    this.error,
  });

  final int rowIndex;
  final String name;
  final String? categoryName;
  final String? sku;
  final String? barcode;
  final String unit;
  final int costPrice;
  final int salePrice;
  final double openingStock;
  final double minQuantity;
  final String? error;

  bool get isValid =>
      (error == null || error!.isEmpty) && name.trim().isNotEmpty;
}

