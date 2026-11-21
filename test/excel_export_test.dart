import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/repositories/expenses_repository.dart';
import 'package:garage_erp/core/services/excel_export_service.dart';
import 'package:garage_erp/features/inventory/domain/item_with_stock.dart';
import 'package:garage_erp/features/invoices/domain/invoice_line_entry.dart';
import 'package:garage_erp/features/invoices/domain/invoice_with_details.dart';
import 'package:garage_erp/features/purchases/domain/purchase_invoice_with_details.dart';
import 'package:garage_erp/features/purchases/domain/purchase_line_item.dart';
import 'package:garage_erp/features/reports/domain/debts_report_data.dart';
import 'package:garage_erp/features/reports/domain/inventory_report_data.dart';
import 'package:garage_erp/features/reports/domain/report_date_range.dart';
import 'package:garage_erp/features/reports/domain/sales_report_data.dart';

void main() {
  group('ExcelExportService Unit Tests', () {
    test('exportInventoryItemsToExcel generates valid Excel with sheet and rows', () {
      final now = DateTime.now();
      final item1 = Item(
        id: 1,
        categoryId: 1,
        name: 'تيل فرامل أمامي سيراميك',
        sku: 'BRK-001',
        barcode: '6221234567890',
        unit: 'طقم',
        costPrice: 45000, // 450 EGP
        salePrice: 65000, // 650 EGP
        minQuantity: 5.0,
        isActive: true,
        createdAt: now,
      );

      final itemWithStock1 = ItemWithStock(
        item: item1,
        categoryName: 'فرامل',
        stockOnHand: 12.0,
      );

      final bytes = ExcelExportService.exportInventoryItemsToExcel([itemWithStock1]);
      expect(bytes, isNotEmpty);

      final decoded = Excel.decodeBytes(bytes);
      expect(decoded.sheets.containsKey('أصناف المخزن'), isTrue);

      final sheet = decoded.sheets['أصناف المخزن']!;
      expect(sheet.maxRows, greaterThanOrEqualTo(5));

      // Find row containing the item name
      bool foundItem = false;
      for (final row in sheet.rows) {
        for (final cell in row) {
          if (cell?.value != null && cell!.value.toString().contains('تيل فرامل')) {
            foundItem = true;
            break;
          }
        }
      }
      expect(foundItem, isTrue);
    });

    test('exportExpensesToExcel generates valid Excel with expenses details', () {
      final now = DateTime.now();
      final exp = Expense(
        id: 1,
        category: 'كهرباء ومياه',
        amount: 85000, // 850 EGP
        expenseDate: now,
        description: 'فاتورة كهرباء ورشة شهر أكتوبر',
        paidTo: 'شركة الكهرباء',
        paymentMethod: PaymentMethod.cash,
        receiptNumber: 'REC-9988',
        notes: 'تم الدفع نقداً',
        createdAt: now,
      );

      final expWithDetails = ExpenseWithDetails(expense: exp);
      final bytes = ExcelExportService.exportExpensesToExcel([expWithDetails]);
      expect(bytes, isNotEmpty);

      final decoded = Excel.decodeBytes(bytes);
      expect(decoded.sheets.containsKey('المصروفات'), isTrue);
    });

    test('exportPurchasesToExcel generates valid Excel with purchase invoices', () {
      final now = DateTime.now();
      final supplier = Supplier(
        id: 1,
        name: 'الشركة الهندسية للتجارة',
        phone: '01099887766',
        notes: null,
        isActive: true,
        createdAt: now,
      );

      final invoice = PurchaseInvoice(
        id: 1,
        supplierId: 1,
        supplierInvoiceNumber: 'INV-SUPP-123',
        invoiceDate: now,
        totalAmount: 1500000, // 15,000 EGP
        paidAmount: 1000000, // 10,000 EGP
        notes: 'دفعة نقدية ومتبقي آجل',
        createdAt: now,
      );

      const line = PurchaseLineItem(
        itemId: 1,
        itemName: 'زيت محرك 5W-40',
        itemUnit: 'جركن',
        quantity: 10.0,
        unitCostPiasters: 150000,
        totalAmountPiasters: 1500000,
      );

      final purchase = PurchaseInvoiceWithDetails(
        invoice: invoice,
        supplier: supplier,
        lines: [line],
      );

      final bytes = ExcelExportService.exportPurchasesToExcel([purchase]);
      expect(bytes, isNotEmpty);

      final decoded = Excel.decodeBytes(bytes);
      expect(decoded.sheets.containsKey('المشتريات والتوريدات'), isTrue);
    });

    test('exportInvoicesToExcel generates valid Excel with sales invoices', () {
      final now = DateTime.now();
      final customer = Customer(
        id: 1,
        name: 'عمرو حسام',
        phone: '01234567890',
        notes: null,
        isActive: true,
        createdAt: now,
      );

      final vehicle = Vehicle(
        id: 1,
        customerId: 1,
        plateNumber: 'ق ص د 5544',
        make: 'هيونداي',
        model: 'إلنترا',
        year: 2021,
        color: 'فضي',
        chassisNumber: null,
        lastOdometer: 45000,
        isActive: true,
        createdAt: now,
      );

      final invoice = Invoice(
        id: 1,
        invoiceNumber: 2001,
        workOrderId: null,
        customerId: 1,
        subtotal: 120000, // 1200 EGP
        discountAmount: 10000, // 100 EGP
        totalAmount: 110000, // 1100 EGP
        paidAmount: 110000,
        status: InvoiceStatus.issued,
        notes: 'صيانة دورية',
        cancellationReason: null,
        issuedAt: now,
        cancelledAt: null,
      );

      final payment = Payment(
        id: 1,
        invoiceId: 1,
        amount: 110000,
        paymentMethod: PaymentMethod.instapay,
        notes: null,
        paidAt: now,
      );

      final invoiceWithDetails = InvoiceWithDetails(
        invoice: invoice,
        customer: customer,
        vehicle: vehicle,
        lines: const <InvoiceLineEntry>[],
        payments: [payment],
      );

      final bytes = ExcelExportService.exportInvoicesToExcel([invoiceWithDetails]);
      expect(bytes, isNotEmpty);

      final decoded = Excel.decodeBytes(bytes);
      expect(decoded.sheets.containsKey('فواتير المبيعات'), isTrue);
    });

    test(
        'exportComprehensiveFinancialReportToExcel generates master workbook with all 7 financial sheets',
        () {
      final now = DateTime.now();
      final range = ReportDateRange.thisMonth();

      final salesData = SalesReportData(
        totalInvoices: 25,
        partsRevenuePiasters: 3000000, // 30,000 EGP
        servicesRevenuePiasters: 1500000, // 15,000 EGP
        totalRevenuePiasters: 4500000, // 45,000 EGP
        partsCostPiasters: 1800000, // 18,000 EGP
        grossProfitPiasters: 2700000, // 27,000 EGP
        totalPaidPiasters: 4000000, // 40,000 EGP
        totalRemainingPiasters: 500000, // 5,000 EGP
        paymentBreakdown: {
          PaymentMethod.cash: 2500000,
          PaymentMethod.instapay: 1500000,
        },
        invoices: [
          SalesReportInvoiceRow(
            invoiceId: 1,
            invoiceNumber: 101,
            date: now,
            customerName: 'كريم محمود',
            plateNumber: 'ب ر ق 7711',
            totalAmountPiasters: 250000,
            paidAmountPiasters: 250000,
            paymentMethod: PaymentMethod.instapay,
            status: InvoiceStatus.issued,
          ),
        ],
        operatingExpensesPiasters: 300000, // 3,000 EGP
        salariesPaidPiasters: 1200000, // 12,000 EGP
      );

      final exp = Expense(
        id: 1,
        category: 'إيجار الورشة',
        amount: 800000,
        expenseDate: now,
        description: 'إيجار شهر أكتوبر',
        paidTo: 'صاحب العقار',
        paymentMethod: PaymentMethod.cash,
        receiptNumber: 'RENT-01',
        notes: null,
        createdAt: now,
      );

      final supplier = Supplier(
        id: 1,
        name: 'مؤسسة الأهرام لقطع الغيار',
        phone: '01122334455',
        notes: null,
        isActive: true,
        createdAt: now,
      );

      final purchInvoice = PurchaseInvoice(
        id: 1,
        supplierId: 1,
        supplierInvoiceNumber: 'AHRAM-554',
        invoiceDate: now,
        totalAmount: 1200000,
        paidAmount: 800000,
        notes: null,
        createdAt: now,
      );

      final purchase = PurchaseInvoiceWithDetails(
        invoice: purchInvoice,
        supplier: supplier,
        lines: const [],
      );

      const debtsData = DebtsReportData(
        totalCustomersDebtPiasters: 850000,
        totalSuppliersDebtPiasters: 400000,
        customersCountWithDebt: 4,
        suppliersCountWithDebt: 1,
        customerDebts: [
          CustomerDebtRow(
            customerId: 1,
            name: 'طارق سامي',
            phone: '01011112222',
            balancePiasters: 350000,
            lastVisit: null,
          ),
        ],
        supplierDebts: [
          SupplierDebtRow(
            supplierId: 1,
            name: 'مؤسسة الأهرام لقطع الغيار',
            phone: '01122334455',
            balancePiasters: 400000,
            totalInvoicesCount: 3,
          ),
        ],
      );

      const inventoryData = InventoryReportData(
        totalItemsCount: 45,
        totalQuantityOnHand: 250.0,
        totalValuationCostPiasters: 9500000,
        totalValuationSalePiasters: 14200000,
        lowStockCount: 3,
        outOfStockCount: 1,
        stagnantItems: [],
        items: [
          InventoryReportItemRow(
            itemId: 1,
            name: 'طقم بوجيهات NGK إيريديوم',
            categoryName: 'كهرباء وإشعال',
            sku: 'NGK-IR-04',
            unit: 'طقم',
            quantityOnHand: 8.0,
            costPricePiasters: 35000,
            salePricePiasters: 55000,
            minQuantity: 2.0,
          ),
        ],
        topMovingItems: [],
      );

      final bytes = ExcelExportService.exportComprehensiveFinancialReportToExcel(
        salesData: salesData,
        expenses: [ExpenseWithDetails(expense: exp)],
        purchases: [purchase],
        debtsData: debtsData,
        inventoryData: inventoryData,
        range: range,
      );

      expect(bytes, isNotEmpty);

      final decoded = Excel.decodeBytes(bytes);

      // Verify all 7 core sheets exist
      expect(decoded.sheets.containsKey('الملخص المالي الشامل'), isTrue);
      expect(decoded.sheets.containsKey('المبيعات والإيرادات'), isTrue);
      expect(decoded.sheets.containsKey('المصروفات والمنصرفات'), isTrue);
      expect(decoded.sheets.containsKey('المشتريات والتوريدات'), isTrue);
      expect(decoded.sheets.containsKey('ديون العملاء'), isTrue);
      expect(decoded.sheets.containsKey('مستحقات الموردين'), isTrue);
      expect(decoded.sheets.containsKey('تقييم المخزون'), isTrue);

      // Verify summary sheet contains financial sections
      final summarySheet = decoded.sheets['الملخص المالي الشامل']!;
      expect(summarySheet.maxRows, greaterThanOrEqualTo(10));
    });

    test('exportInventoryTemplateToExcel and parseInventoryItemsFromExcel round-trip', () {
      final templateBytes = ExcelExportService.exportInventoryTemplateToExcel();
      expect(templateBytes, isNotEmpty);

      final parsed = ExcelExportService.parseInventoryItemsFromExcel(templateBytes);
      expect(parsed, isNotEmpty);
      expect(parsed.length, 2); // 2 sample items in template
      expect(parsed[0].name, 'فلتر زيت أصلي');
      expect(parsed[0].categoryName, 'فلاتر');
      expect(parsed[0].costPrice, 18000); // 180 EGP in piasters
      expect(parsed[0].salePrice, 25000); // 250 EGP in piasters
      expect(parsed[0].openingStock, 10.0);
      expect(parsed[0].isValid, isTrue);

      expect(parsed[1].name, 'تيل فرامل أمامي');
      expect(parsed[1].isValid, isTrue);
    });
  });
}
