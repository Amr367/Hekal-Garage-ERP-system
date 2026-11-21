import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/providers.dart';
import 'package:garage_erp/core/db/repositories/categories_repository.dart';
import 'package:garage_erp/core/db/repositories/items_repository.dart';
import 'package:garage_erp/core/db/repositories/reports_repository.dart';
import 'package:garage_erp/core/db/services/stock_service.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/core/theme/app_theme.dart';
import 'package:garage_erp/features/reports/domain/report_date_range.dart';
import 'package:garage_erp/features/reports/reports_page.dart';

void main() {
  late AppDatabase db;
  late StockService stockService;
  late CategoriesRepository categoriesRepo;
  late ItemsRepository itemsRepo;
  late ReportsRepository reportsRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    stockService = StockService(db);
    categoriesRepo = DriftCategoriesRepository(db);
    itemsRepo = DriftItemsRepository(db);
    reportsRepo = DriftReportsRepository(db, stockService);
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftReportsRepository Repository Tests', () {
    test('getSalesReport calculates revenues, costs, margins and payment methods',
        () async {
      // 1. Create Customer and Vehicle
      final custId = await db.into(db.customers).insert(
            const CustomersCompanion(
              name: drift.Value('أحمد عثمان'),
              phone: drift.Value('01012345678'),
            ),
          );

      final vehId = await db.into(db.vehicles).insert(
            VehiclesCompanion(
              customerId: drift.Value(custId),
              plateNumber: const drift.Value('أ ب ج 1234'),
            ),
          );

      // 2. Create Category and Item (Cost: 200 EGP, Sale: 300 EGP)
      final catId = await categoriesRepo.insertCategory('فلاتر');
      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('فلتر زيت تويوتا أصلي'),
          costPrice: const drift.Value(20000), // 200.00 EGP
          salePrice: const drift.Value(30000), // 300.00 EGP
          sku: const drift.Value('FLT-TOY-01'),
        ),
      );

      // 3. Create Work Order
      final orderId = await db.into(db.workOrders).insert(
            WorkOrdersCompanion(
              orderNumber: const drift.Value(101),
              customerId: drift.Value(custId),
              vehicleId: drift.Value(vehId),
              status: const drift.Value(WorkOrderStatus.delivered),
            ),
          );

      // 4. Create Issued Invoice (Subtotal: 450 EGP = 300 parts + 150 labor)
      final now = DateTime.now();
      final invId = await db.into(db.invoices).insert(
            InvoicesCompanion(
              invoiceNumber: const drift.Value(1001),
              workOrderId: drift.Value(orderId),
              customerId: drift.Value(custId),
              subtotal: const drift.Value(45000),
              totalAmount: const drift.Value(45000),
              paidAmount: const drift.Value(45000),
              status: const drift.Value(InvoiceStatus.issued),
              issuedAt: drift.Value(now),
            ),
          );

      // Add parts line (300 EGP sale, 200 EGP cost)
      await db.into(db.invoiceLines).insert(
            InvoiceLinesCompanion(
              invoiceId: drift.Value(invId),
              lineType: const drift.Value(LineType.part),
              itemId: drift.Value(itemId),
              description: const drift.Value('فلتر زيت'),
              quantity: const drift.Value(1.0),
              unitPrice: const drift.Value(30000),
              unitCost: const drift.Value(20000),
              totalPrice: const drift.Value(30000),
            ),
          );

      // Add service line (150 EGP labor)
      await db.into(db.invoiceLines).insert(
            InvoiceLinesCompanion(
              invoiceId: drift.Value(invId),
              lineType: const drift.Value(LineType.service),
              description: const drift.Value('مصنعية غيار زيت وفلتر'),
              quantity: const drift.Value(1.0),
              unitPrice: const drift.Value(15000),
              unitCost: const drift.Value(0),
              totalPrice: const drift.Value(15000),
            ),
          );

      // Add payment with InstaPay
      await db.into(db.payments).insert(
            PaymentsCompanion(
              invoiceId: drift.Value(invId),
              amount: const drift.Value(45000),
              paymentMethod: const drift.Value(PaymentMethod.instapay),
              paidAt: drift.Value(now),
            ),
          );

      // Query sales report for today
      final todayRange = ReportDateRange.today();
      final report = await reportsRepo.getSalesReport(
        todayRange.start,
        todayRange.end,
      );

      expect(report.totalInvoices, equals(1));
      expect(report.totalRevenuePiasters, equals(45000));
      expect(report.partsRevenuePiasters, equals(30000));
      expect(report.servicesRevenuePiasters, equals(15000));
      expect(report.partsCostPiasters, equals(20000));
      // Gross profit = 45000 - 20000 = 25000 (250 EGP)
      expect(report.grossProfitPiasters, equals(25000));
      expect(report.totalPaidPiasters, equals(45000));
      expect(report.totalRemainingPiasters, equals(0));
      expect(report.amountFor(PaymentMethod.instapay), equals(45000));
      expect(report.invoices.length, equals(1));
      expect(report.invoices.first.customerName, equals('أحمد عثمان'));
    });

    test('getInventoryReport computes valuations and flags low stock', () async {
      final catId = await categoriesRepo.insertCategory('زيوت');
      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('زيت كاسترول 5W-30'),
          costPrice: const drift.Value(80000), // 800 EGP
          salePrice: const drift.Value(110000), // 1100 EGP
          minQuantity: const drift.Value(5.0),
        ),
      );

      // Add initial stock: 3 units (less than minQuantity 5.0 -> low stock)
      await stockService.addMovement(
        StockMovementsCompanion.insert(
          itemId: itemId,
          movementType: StockMovementType.opening,
          qty: 3.0,
        ),
      );

      final report = await reportsRepo.getInventoryReport();
      expect(report.totalItemsCount, equals(1));
      expect(report.totalQuantityOnHand, equals(3.0));
      expect(report.totalValuationCostPiasters, equals(3 * 80000));
      expect(report.totalValuationSalePiasters, equals(3 * 110000));
      expect(report.lowStockCount, equals(1));
      expect(report.outOfStockCount, equals(0));
    });

    test('getDebtsReport correctly captures unpaid customer invoices and supplier balances',
        () async {
      // 1. Customer with unpaid invoice (Total: 500 EGP, Paid: 200 EGP -> Debt: 300 EGP)
      final custId = await db.into(db.customers).insert(
            const CustomersCompanion(
              name: drift.Value('محمد علي'),
              phone: drift.Value('01223456789'),
            ),
          );

      await db.into(db.invoices).insert(
            InvoicesCompanion(
              invoiceNumber: const drift.Value(2001),
              customerId: drift.Value(custId),
              subtotal: const drift.Value(50000),
              totalAmount: const drift.Value(50000),
              paidAmount: const drift.Value(20000),
              status: const drift.Value(InvoiceStatus.issued),
            ),
          );

      // 2. Supplier with unpaid purchase (Total: 1000 EGP, Paid: 400 EGP -> Debt: 600 EGP)
      final supId = await db.into(db.suppliers).insert(
            const SuppliersCompanion(
              name: drift.Value('شركة الأهرام لقطع الغيار'),
              phone: drift.Value('01112223334'),
            ),
          );

      await db.into(db.purchaseInvoices).insert(
            PurchaseInvoicesCompanion(
              supplierId: drift.Value(supId),
              invoiceDate: drift.Value(DateTime.now()),
              totalAmount: const drift.Value(100000),
              paidAmount: const drift.Value(40000),
            ),
          );

      final debts = await reportsRepo.getDebtsReport();
      expect(debts.totalCustomersDebtPiasters, equals(30000));
      expect(debts.customersCountWithDebt, equals(1));
      expect(debts.customerDebts.first.name, equals('محمد علي'));
      expect(debts.customerDebts.first.balancePiasters, equals(30000));

      expect(debts.totalSuppliersDebtPiasters, equals(60000));
      expect(debts.suppliersCountWithDebt, equals(1));
      expect(debts.supplierDebts.first.name, equals('شركة الأهرام لقطع الغيار'));
      expect(debts.supplierDebts.first.balancePiasters, equals(60000));
    });

    test('Excel export functions return valid non-empty byte lists', () async {
      final range = ReportDateRange.thisMonth();
      final salesData = await reportsRepo.getSalesReport(range.start, range.end);
      final salesExcel = reportsRepo.exportSalesReportToExcel(salesData, range);
      expect(salesExcel, isNotEmpty);

      final invData = await reportsRepo.getInventoryReport();
      final invExcel = reportsRepo.exportInventoryReportToExcel(invData);
      expect(invExcel, isNotEmpty);

      final debtsData = await reportsRepo.getDebtsReport();
      final debtsExcel = reportsRepo.exportDebtsReportToExcel(debtsData);
      expect(debtsExcel, isNotEmpty);

      final profitExcel = reportsRepo.exportProfitReportToExcel(salesData, range);
      expect(profitExcel, isNotEmpty);
    });
  });

  group('Reports UI Widget Tests', () {
    Widget buildReportsApp() {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          stockServiceProvider.overrideWithValue(stockService),
          categoriesRepositoryProvider.overrideWithValue(categoriesRepo),
          itemsRepositoryProvider.overrideWithValue(itemsRepo),
          reportsRepositoryProvider.overrideWithValue(reportsRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ReportsPage(),
            ),
          ),
        ),
      );
    }

    testWidgets('ReportsPage renders header toolbar and switches between tabs',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildReportsApp());
      await tester.pumpAndSettle();

      // Top title and toolbar
      expect(find.text(AppStrings.reportsTitle), findsOneWidget);
      expect(find.text(AppStrings.exportExcel), findsOneWidget);
      expect(find.text('هذا الشهر'), findsAtLeastNWidgets(1));

      // Tab headers
      expect(find.text('تقرير المبيعات والإيرادات'), findsAtLeastNWidgets(1));
      expect(find.text('تقرير الأرباح وهوامش الربح'), findsOneWidget);
      expect(find.text('حركة المخزون والركود'), findsOneWidget);
      expect(find.text('مديونيات العملاء والموردين'), findsOneWidget);

      // Default tab: Sales KPI
      expect(find.text('توزيع طرق التحصيل والدفع'), findsOneWidget);
      expect(find.text('خزنة الفرع (كاش)'), findsOneWidget);
      expect(find.text('انستاباي (InstaPay)'), findsOneWidget);

      // Switch to Profit Tab
      await tester.tap(find.text('تقرير الأرباح وهوامش الربح'));
      await tester.pumpAndSettle();
      expect(find.text('هامش صافي الربح %'), findsOneWidget);
      expect(find.text('تحليل وتفصيل الإيرادات والمصروفات وصافي الأرباح'), findsOneWidget);

      // Switch to Inventory Tab
      await tester.tap(find.text('حركة المخزون والركود'));
      await tester.pumpAndSettle();
      expect(find.text('قيمة المخزون (بسعر الشراء)'), findsOneWidget);
      expect(find.text('الأصناف الأكثر حركة ومبيعاً'), findsOneWidget);
      expect(find.textContaining('الأصناف الراكدة'), findsOneWidget);

      // Switch to Debts Tab
      await tester.tap(find.text('مديونيات العملاء والموردين'));
      await tester.pumpAndSettle();
      expect(find.textContaining('إجمالي ديون العملاء'), findsOneWidget);
      expect(find.textContaining('إجمالي مستحقات الموردين'), findsOneWidget);
      expect(find.text('ديون العملاء المستحقة'), findsOneWidget);
      expect(find.text('مستحقات وفواتير الموردين'), findsOneWidget);
    });
  });
}
