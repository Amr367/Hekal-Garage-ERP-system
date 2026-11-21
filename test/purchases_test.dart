import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/providers.dart';
import 'package:garage_erp/core/db/repositories/categories_repository.dart';
import 'package:garage_erp/core/db/repositories/items_repository.dart';
import 'package:garage_erp/core/db/repositories/purchases_repository.dart';
import 'package:garage_erp/core/db/repositories/suppliers_repository.dart';
import 'package:garage_erp/core/db/services/stock_service.dart';
import 'package:garage_erp/core/errors/app_exceptions.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/core/theme/app_theme.dart';
import 'package:garage_erp/features/inventory/domain/item_with_stock.dart';
import 'package:garage_erp/features/purchases/domain/purchase_invoice_with_details.dart';
import 'package:garage_erp/features/purchases/domain/purchase_line_item.dart';
import 'package:garage_erp/features/purchases/domain/purchase_print_builder.dart';
import 'package:garage_erp/features/purchases/presentation/widgets/purchase_details_pane.dart';
import 'package:garage_erp/features/purchases/presentation/widgets/purchase_invoice_form_dialog.dart';
import 'package:garage_erp/features/purchases/presentation/widgets/purchase_preview_dialog.dart';
import 'package:garage_erp/features/purchases/presentation/widgets/supplier_form_dialog.dart';
import 'package:garage_erp/core/printing/font_loader.dart';
import 'package:garage_erp/features/purchases/purchases_page.dart';
import 'package:garage_erp/features/settings/domain/garage_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await PdfFontLoader.init();
  });

  late AppDatabase db;
  late StockService stockService;
  late SuppliersRepository suppliersRepo;
  late PurchasesRepository purchasesRepo;
  late ItemsRepository itemsRepo;
  late CategoriesRepository categoriesRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    stockService = StockService(db);
    suppliersRepo = DriftSuppliersRepository(db);
    purchasesRepo = DriftPurchasesRepository(db, stockService);
    itemsRepo = DriftItemsRepository(db);
    categoriesRepo = DriftCategoriesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createTestItem({
    String name = 'تيل فرامل أمامي كوري',
    int costPrice = 45000,
    int salePrice = 65000,
  }) async {
    final catId = await categoriesRepo.insertCategory('قطع غيار الفرامل');

    return itemsRepo.insertItem(
      ItemsCompanion(
        categoryId: drift.Value(catId),
        name: drift.Value(name),
        costPrice: drift.Value(costPrice),
        salePrice: drift.Value(salePrice),
        sku: const drift.Value('BRK-KOR-01'),
      ),
    );
  }

  group('Suppliers Repository Unit Tests', () {
    test('insertSupplier validates name and inserts successfully', () async {
      expect(
        () => suppliersRepo.insertSupplier(
          const SuppliersCompanion(name: drift.Value('  ')),
        ),
        throwsA(isA<ValidationException>()),
      );

      final id = await suppliersRepo.insertSupplier(
        const SuppliersCompanion(
          name: drift.Value('شركة الأهرام لقطع الغيار'),
          phone: drift.Value('01099887766'),
          notes: drift.Value('التوفيقية - القاهرة'),
        ),
      );

      expect(id, greaterThan(0));
      final supplier = await suppliersRepo.getById(id);
      expect(supplier.name, 'شركة الأهرام لقطع الغيار');
      expect(supplier.phone, '01099887766');
      expect(supplier.isActive, true);
    });

    test('deactivate and reactivate supplier', () async {
      final id = await suppliersRepo.insertSupplier(
        const SuppliersCompanion(name: drift.Value('مؤسسة النصر للتوريدات')),
      );

      await suppliersRepo.deactivate(id);
      var supplier = await suppliersRepo.getById(id);
      expect(supplier.isActive, false);

      await suppliersRepo.reactivate(id);
      supplier = await suppliersRepo.getById(id);
      expect(supplier.isActive, true);
    });

    test('getSuppliersWithBalances calculates purchases, paid, and debt', () async {
      final suppId = await suppliersRepo.insertSupplier(
        const SuppliersCompanion(name: drift.Value('مورد الزيوت والفلاتر')),
      );
      final itemId = await createTestItem();

      // Create purchase invoice: 10 items @ 500 EGP = 5,000 EGP (500,000 piasters)
      // Paid: 2,000 EGP (200,000 piasters) -> Remaining debt: 3,000 EGP (300,000 piasters)
      await purchasesRepo.createPurchaseInvoice(
        supplierId: suppId,
        invoiceDate: DateTime.now(),
        paidAmountPiasters: 200000,
        lines: [
          PurchaseLineInput(
            itemId: itemId,
            quantity: 10,
            unitCostPiasters: 50000,
          ),
        ],
      );

      final balances = await suppliersRepo.getSuppliersWithBalances();
      expect(balances.length, 1);
      final entry = balances.first;
      expect(entry.invoicesCount, 1);
      expect(entry.totalPurchasesPiasters, 500000);
      expect(entry.totalPaidPiasters, 200000);
      expect(entry.balanceDuePiasters, 300000);
      expect(entry.hasDebt, true);
    });

    test('recordPayment distributes payment across unpaid invoices', () async {
      final suppId = await suppliersRepo.insertSupplier(
        const SuppliersCompanion(name: drift.Value('المصرية لتجارة السيور')),
      );
      final itemId = await createTestItem();

      // First invoice: 1,000 EGP total, 0 paid -> remaining 1,000 EGP
      await purchasesRepo.createPurchaseInvoice(
        supplierId: suppId,
        invoiceDate: DateTime(2026, 1, 1),
        paidAmountPiasters: 0,
        lines: [
          PurchaseLineInput(itemId: itemId, quantity: 2, unitCostPiasters: 50000),
        ],
      );

      // Second invoice: 1,000 EGP total, 0 paid -> remaining 1,000 EGP
      await purchasesRepo.createPurchaseInvoice(
        supplierId: suppId,
        invoiceDate: DateTime(2026, 1, 2),
        paidAmountPiasters: 0,
        lines: [
          PurchaseLineInput(itemId: itemId, quantity: 2, unitCostPiasters: 50000),
        ],
      );

      // Pay 1,500 EGP (150,000 piasters)
      await suppliersRepo.recordPayment(
        supplierId: suppId,
        amountPiasters: 150000,
      );

      final invoices = await purchasesRepo.getPurchaseInvoices(supplierId: suppId);
      // Invoice 1 should be fully paid (100,000)
      final inv1 = invoices.firstWhere((i) => i.invoiceDate == DateTime(2026, 1, 1));
      expect(inv1.paidAmountPiasters, 100000);
      expect(inv1.paymentStatus, PurchasePaymentStatus.paid);

      // Invoice 2 should be partially paid (50,000 paid, 50,000 remaining)
      final inv2 = invoices.firstWhere((i) => i.invoiceDate == DateTime(2026, 1, 2));
      expect(inv2.paidAmountPiasters, 50000);
      expect(inv2.paymentStatus, PurchasePaymentStatus.partial);
    });
  });

  group('Purchases Repository Unit Tests', () {
    test('createPurchaseInvoice adds stock movements and updates item cost price', () async {
      final suppId = await suppliersRepo.insertSupplier(
        const SuppliersCompanion(name: drift.Value('توكيل بوش مصر')),
      );
      final itemId = await createTestItem(costPrice: 40000);

      // Current stock before purchase
      final stockBefore = await stockService.onHand(itemId);
      expect(stockBefore, 0.0);

      // Create purchase invoice for 5 items at 520 EGP (52,000 piasters)
      final purchase = await purchasesRepo.createPurchaseInvoice(
        supplierId: suppId,
        supplierInvoiceNumber: 'BOSCH-778',
        invoiceDate: DateTime.now(),
        paidAmountPiasters: 260000,
        notes: 'دفعة نقدية بالكامل',
        lines: [
          PurchaseLineInput(
            itemId: itemId,
            quantity: 5,
            unitCostPiasters: 52000,
          ),
        ],
      );

      expect(purchase.totalAmountPiasters, 260000);
      expect(purchase.paidAmountPiasters, 260000);
      expect(purchase.remainingAmountPiasters, 0);
      expect(purchase.paymentStatus, PurchasePaymentStatus.paid);
      expect(purchase.lines.length, 1);

      // Check stock on hand incremented (Rule R2, R3)
      final stockAfter = await stockService.onHand(itemId);
      expect(stockAfter, 5.0);

      // Check item's latest cost price was updated to 52000 (Rule R8)
      final updatedItem = await itemsRepo.getById(itemId);
      expect(updatedItem.costPrice, 52000);

      // Check stock movement record via item ledger
      final ledger = await itemsRepo.getItemLedger(itemId);
      expect(ledger.length, 1);
      expect(ledger.first.movement.movementType, StockMovementType.purchaseIn);
      expect(ledger.first.movement.qty, 5.0);
      expect(ledger.first.movement.unitCost, 52000);
    });

    test('getPurchasesSummary aggregates totals accurately', () async {
      final suppId = await suppliersRepo.insertSupplier(
        const SuppliersCompanion(name: drift.Value('مورد كماليات سيارات')),
      );
      final itemId = await createTestItem();

      await purchasesRepo.createPurchaseInvoice(
        supplierId: suppId,
        invoiceDate: DateTime.now(),
        paidAmountPiasters: 100000,
        lines: [
          PurchaseLineInput(itemId: itemId, quantity: 4, unitCostPiasters: 50000),
        ],
      );

      final summary = await purchasesRepo.getPurchasesSummary();
      expect(summary.totalPurchasesPiasters, 200000);
      expect(summary.totalSuppliersDebtPiasters, 100000);
      expect(summary.activeSuppliersCount, 1);
      expect(summary.thisMonthPurchasesPiasters, 200000);
    });
  });

  group('Purchases UI Widget Tests', () {
    Widget buildTestApp(Widget child) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          stockServiceProvider.overrideWithValue(stockService),
          suppliersRepositoryProvider.overrideWithValue(suppliersRepo),
          purchasesRepositoryProvider.overrideWithValue(purchasesRepo),
          itemsRepositoryProvider.overrideWithValue(itemsRepo),
          categoriesRepositoryProvider.overrideWithValue(categoriesRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ar'),
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('PurchasesPage renders KPI cards, toolbar, and empty state', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const PurchasesPage()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.purchasesTitle), findsOneWidget);
      expect(find.text(AppStrings.newPurchaseButton), findsOneWidget);
      expect(find.text(AppStrings.manageSuppliersButton), findsOneWidget);
      expect(find.text(AppStrings.kpiTotalPurchases), findsOneWidget);
      expect(find.text(AppStrings.kpiSuppliersDebt), findsOneWidget);
      expect(find.text('لا توجد فواتير شراء مسجلة'), findsOneWidget);
    });

    testWidgets('SupplierFormDialog creates a new supplier', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const SupplierFormDialog()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.newSupplierButton), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, '${AppStrings.supplierNameLabel} *'),
        'مركز الدلتا لقطع الغيار',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.supplierPhoneLabel),
        '01122334455',
      );

      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      final suppliers = await suppliersRepo.getAll();
      expect(suppliers.length, 1);
      expect(suppliers.first.name, 'مركز الدلتا لقطع الغيار');
    });

    testWidgets('PurchaseInvoiceFormDialog creates purchase invoice with line item', (tester) async {
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Setup supplier and item
      await suppliersRepo.insertSupplier(
        const SuppliersCompanion(name: drift.Value('مؤسسة الصفا للتوريدات')),
      );
      await createTestItem(name: 'مساعدين أمامي نيسان');

      await tester.pumpWidget(buildTestApp(const PurchaseInvoiceFormDialog()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.purchaseInvoiceTitle), findsOneWidget);

      // Select Supplier
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('مؤسسة الصفا').last);
      await tester.pumpAndSettle();

      // Enter invoice number
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.supplierInvoiceNumberLabel),
        'INV-5544',
      );

      // Select item for line
      await tester.tap(find.byType(DropdownButtonFormField<ItemWithStock>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('مساعدين أمامي نيسان').last);
      await tester.pumpAndSettle();

      // Tap add line button
      await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.addPurchaseLine));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      // Verify invoice created in database
      final purchases = await purchasesRepo.getPurchaseInvoices();
      expect(purchases.length, 1);
      expect(purchases.first.supplier.name, 'مؤسسة الصفا للتوريدات');
      expect(purchases.first.supplierInvoiceNumber, 'INV-5544');
    });

    test('PurchasePrintBuilder generates valid non-empty PDF bytes', () async {
      final supplierId = await suppliersRepo.insertSupplier(
        const SuppliersCompanion(
          name: drift.Value('شركة الأهرام لقطع الغيار'),
          phone: drift.Value('01011223344'),
          notes: drift.Value('التوفيقية - القاهرة'),
        ),
      );
      final supplier = await suppliersRepo.getById(supplierId);

      final purchaseWithDetails = PurchaseInvoiceWithDetails(
        invoice: PurchaseInvoice(
          id: 1,
          supplierId: supplierId,
          supplierInvoiceNumber: 'INV-9988',
          invoiceDate: DateTime(2026, 11, 2),
          totalAmount: 150000,
          paidAmount: 100000,
          notes: 'دفعة أولى بشيك',
          createdAt: DateTime(2026, 11, 2),
        ),
        supplier: supplier,
        lines: const [
          PurchaseLineItem(
            itemId: 1,
            itemName: 'طقم تيل فرامل كوري أصلي',
            itemSku: 'BRK-101',
            itemUnit: 'طقم',
            quantity: 2,
            unitCostPiasters: 75000,
            totalAmountPiasters: 150000,
          ),
        ],
      );

      final profile = const GarageProfile(
        name: 'مركز الصيانة التخصصي',
        subtitle: 'قطع غيار وصيانة عامة',
        phone: '01012345678',
      );

      final doc = PurchasePrintBuilder.buildA4(purchaseWithDetails, profile);
      final pdfBytes = await doc.save();

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    testWidgets('PurchaseDetailsPane renders print button and opens preview dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final supplierId = await suppliersRepo.insertSupplier(
        const SuppliersCompanion(
          name: drift.Value('شركة الأهرام لقطع الغيار'),
          phone: drift.Value('01011223344'),
        ),
      );
      final supplier = await suppliersRepo.getById(supplierId);

      final purchase = PurchaseInvoiceWithDetails(
        invoice: PurchaseInvoice(
          id: 42,
          supplierId: supplierId,
          supplierInvoiceNumber: 'INV-4200',
          invoiceDate: DateTime(2026, 11, 2),
          totalAmount: 50000,
          paidAmount: 50000,
          notes: 'توريد عاجل',
          createdAt: DateTime(2026, 11, 2),
        ),
        supplier: supplier,
        lines: const [
          PurchaseLineItem(
            itemId: 1,
            itemName: 'فلتر زيت تويوتا أصلي',
            itemSku: 'FLT-TOY-01',
            itemUnit: 'حبة',
            quantity: 5,
            unitCostPiasters: 10000,
            totalAmountPiasters: 50000,
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: PurchaseDetailsPane(
              purchase: purchase,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify details pane content
      expect(find.textContaining('42'), findsWidgets);
      expect(find.text('شركة الأهرام لقطع الغيار'), findsOneWidget);
      expect(find.text('فلتر زيت تويوتا أصلي'), findsOneWidget);

      // Verify print buttons exist (both header icon and action button)
      final printBtn = find.widgetWithText(ElevatedButton, AppStrings.printPurchaseButton);
      expect(printBtn, findsOneWidget);

      // Tap print button
      await tester.tap(printBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify preview dialog opened
      expect(find.byType(PurchasePreviewDialog), findsOneWidget);
      expect(find.textContaining(AppStrings.purchasePreviewTitle), findsOneWidget);
    });
  });
}
