import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/providers.dart';
import 'package:garage_erp/core/db/repositories/categories_repository.dart';
import 'package:garage_erp/core/db/repositories/customers_repository.dart';
import 'package:garage_erp/core/db/repositories/invoices_repository.dart';
import 'package:garage_erp/core/db/repositories/items_repository.dart';
import 'package:garage_erp/core/db/repositories/services_repository.dart';
import 'package:garage_erp/core/db/services/stock_service.dart';
import 'package:garage_erp/core/errors/app_exceptions.dart';
import 'package:garage_erp/core/printing/tafqeet.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/core/theme/app_theme.dart';
import 'package:garage_erp/features/invoices/domain/invoice_line_entry.dart';
import 'package:garage_erp/core/printing/font_loader.dart';
import 'package:garage_erp/features/invoices/domain/invoice_print_builder.dart';
import 'package:garage_erp/features/invoices/invoices_page.dart';
import 'package:garage_erp/features/invoices/presentation/widgets/invoice_details_pane.dart';
import 'package:garage_erp/features/settings/domain/garage_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await PdfFontLoader.init();
  });

  late AppDatabase db;
  late StockService stockService;
  late InvoicesRepository invoicesRepo;
  late CustomersRepository customersRepo;
  late ItemsRepository itemsRepo;
  late CategoriesRepository categoriesRepo;
  late ServicesRepository servicesRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    stockService = StockService(db);
    invoicesRepo = DriftInvoicesRepository(db, stockService);
    customersRepo = DriftCustomersRepository(db);
    categoriesRepo = DriftCategoriesRepository(db);
    itemsRepo = DriftItemsRepository(db);
    servicesRepo = DriftServicesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftInvoicesRepository Unit Tests', () {
    test('createDirectSale inserts invoice, lines, payments, and deducts inventory stock', () async {
      // 1. Create category and item with stock
      final catId = await db.into(db.itemCategories).insert(
            const ItemCategoriesCompanion(name: drift.Value('فلاتر وزيوت')),
          );

      final itemId = await db.into(db.items).insert(
            ItemsCompanion(
              categoryId: drift.Value(catId),
              name: const drift.Value('فلتر زيت تويوتا'),
              costPrice: const drift.Value(10000), // 100 EGP
              salePrice: const drift.Value(15000), // 150 EGP
              minQuantity: const drift.Value(2.0),
            ),
          );

      // Add opening stock: 10 units
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(10.0),
          unitCost: const drift.Value(10000),
        ),
      );

      final initialStock = await stockService.onHand(itemId);
      expect(initialStock, equals(10.0));

      // 2. Create customer
      final custId = await db.into(db.customers).insert(
            const CustomersCompanion(
              name: drift.Value('عميل تجريبي'),
              phone: drift.Value('01011223344'),
            ),
          );

      // 3. Issue Direct Sale: 3 filters @ 150 EGP each = 450 EGP, 50 EGP discount = 400 EGP total
      // Paid: 300 EGP, Remaining: 100 EGP
      final invoice = await invoicesRepo.createDirectSale(
        customerId: custId,
        lines: [
          InvoiceLineEntry(
            lineType: LineType.part,
            itemId: itemId,
            description: 'فلتر زيت تويوتا',
            quantity: 3.0,
            unitPricePiasters: 15000,
            totalPricePiasters: 45000,
          ),
        ],
        discountAmountPiasters: 5000,
        paidAmountPiasters: 30000,
        paymentMethod: PaymentMethod.instapay,
        paymentNotes: 'مرجع: IP123456',
        notes: 'بيع سريع بدون صيانة',
      );

      expect(invoice.invoiceNumber, equals(1));
      expect(invoice.subtotalPiasters, equals(45000));
      expect(invoice.discountPiasters, equals(5000));
      expect(invoice.totalPiasters, equals(40000));
      expect(invoice.paidPiasters, equals(30000));
      expect(invoice.remainingPiasters, equals(10000));
      expect(invoice.isPartiallyPaid, isTrue);

      // 4. Verify stock was deducted by 3.0 (from 10.0 -> 7.0)
      final stockAfter = await stockService.onHand(itemId);
      expect(stockAfter, equals(7.0));

      // 5. Verify payment entry
      expect(invoice.payments.length, equals(1));
      expect(invoice.payments.first.amount, equals(30000));
      expect(invoice.payments.first.paymentMethod, equals(PaymentMethod.instapay));

      // 6. Record remaining payment of 100 EGP via Vodafone Cash (wallet)
      await invoicesRepo.recordPayment(
        invoiceId: invoice.id,
        amountPiasters: 10000,
        method: PaymentMethod.wallet,
        notes: 'سداد الباقي فودافون كاش',
      );

      final updated = await invoicesRepo.getById(invoice.id);
      expect(updated, isNotNull);
      expect(updated!.paidPiasters, equals(40000));
      expect(updated.remainingPiasters, equals(0));
      expect(updated.isPaid, isTrue);
      expect(updated.payments.length, equals(2));
    });

    test('createDirectSale blocks sale if stock is insufficient', () async {
      final catId = await db.into(db.itemCategories).insert(
            const ItemCategoriesCompanion(name: drift.Value('سيور')),
          );

      final itemId = await db.into(db.items).insert(
            ItemsCompanion(
              categoryId: drift.Value(catId),
              name: const drift.Value('سير دينامو'),
              costPrice: const drift.Value(8000),
              salePrice: const drift.Value(12000),
            ),
          );

      // Add only 1 unit to stock
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(1.0),
        ),
      );

      // Try to sell 5 units -> must throw InsufficientStockException
      expect(
        () => invoicesRepo.createDirectSale(
          lines: [
            InvoiceLineEntry(
              lineType: LineType.part,
              itemId: itemId,
              description: 'سير دينامو',
              quantity: 5.0,
              unitPricePiasters: 12000,
              totalPricePiasters: 60000,
            ),
          ],
          paymentMethod: PaymentMethod.cash,
        ),
        throwsA(isA<InsufficientStockException>()),
      );
    });

    test('cancelInvoice marks invoice cancelled and reverses stock deduction', () async {
      final catId = await db.into(db.itemCategories).insert(
            const ItemCategoriesCompanion(name: drift.Value('بوجيهات')),
          );

      final itemId = await db.into(db.items).insert(
            ItemsCompanion(
              categoryId: drift.Value(catId),
              name: const drift.Value('طقم بوجيهات NGK'),
              costPrice: const drift.Value(20000),
              salePrice: const drift.Value(30000),
            ),
          );

      // Stock: 5 sets
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(5.0),
        ),
      );

      // Sell 2 sets -> stock becomes 3
      final inv = await invoicesRepo.createDirectSale(
        lines: [
          InvoiceLineEntry(
            lineType: LineType.part,
            itemId: itemId,
            description: 'طقم بوجيهات NGK',
            quantity: 2.0,
            unitPricePiasters: 30000,
            totalPricePiasters: 60000,
          ),
        ],
        paidAmountPiasters: 60000,
        paymentMethod: PaymentMethod.cash,
      );

      expect(await stockService.onHand(itemId), equals(3.0));

      // Cancel invoice -> stock must return to 5.0
      await invoicesRepo.cancelInvoice(
        invoiceId: inv.id,
        reason: 'إرجاع من قبل العميل قبل التركيب',
      );

      final cancelled = await invoicesRepo.getById(inv.id);
      expect(cancelled!.isCancelled, isTrue);
      expect(cancelled.invoice.cancellationReason, equals('إرجاع من قبل العميل قبل التركيب'));
      expect(await stockService.onHand(itemId), equals(5.0));
    });

    test('getSummary aggregates financial metrics correctly', () async {
      await invoicesRepo.createDirectSale(
        lines: const [
          InvoiceLineEntry(
            lineType: LineType.service,
            description: 'فحص كمبيوتر',
            quantity: 1.0,
            unitPricePiasters: 20000,
            totalPricePiasters: 20000,
          ),
        ],
        paidAmountPiasters: 15000,
        paymentMethod: PaymentMethod.cash,
      );

      final summary = await invoicesRepo.getSummary();
      expect(summary.totalSalesPiasters, equals(20000));
      expect(summary.totalCollectedPiasters, equals(15000));
      expect(summary.totalRemainingPiasters, equals(5000));
      expect(summary.totalInvoicesCount, equals(1));
    });
  });

  group('Invoices UI Widget Tests', () {
    Widget buildInvoicesApp() {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          stockServiceProvider.overrideWithValue(stockService),
          invoicesRepositoryProvider.overrideWithValue(invoicesRepo),
          customersRepositoryProvider.overrideWithValue(customersRepo),
          itemsRepositoryProvider.overrideWithValue(itemsRepo),
          categoriesRepositoryProvider.overrideWithValue(categoriesRepo),
          servicesRepositoryProvider.overrideWithValue(servicesRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InvoicesPage(),
            ),
          ),
        ),
      );
    }

    testWidgets('InvoicesPage renders KPI cards, toolbar, and opens DirectSale dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildInvoicesApp());
      await tester.pumpAndSettle();

      // Check title and button
      expect(find.text(AppStrings.invoicesTitle), findsOneWidget);
      expect(find.text(AppStrings.newInvoiceButton), findsOneWidget);

      // Check KPI Cards
      expect(find.text('إجمالي المبيعات المفوترة'), findsOneWidget);
      expect(find.text('إجمالي المحصل والمدفوع'), findsOneWidget);
      expect(find.text('المتبقي (آجل وديون)'), findsOneWidget);

      // Click "فاتورة جديدة"
      await tester.tap(find.text(AppStrings.newInvoiceButton));
      await tester.pumpAndSettle();

      // Dialog should open
      expect(find.text('إصدار فاتورة بيع مباشر / كاونتر'), findsOneWidget);
      expect(find.text('إضافة قطعة'), findsOneWidget);
      expect(find.text('إضافة مصنعية'), findsOneWidget);
      expect(find.text('خزنة الفرع (كاش)'), findsOneWidget);
      expect(find.text('انستاباي (InstaPay)'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('إصدار فاتورة بيع مباشر / كاونتر'), findsNothing);
    });

    testWidgets('InvoicesPage renders and opens details pane without overflow at 1100x700', (tester) async {
      tester.view.physicalSize = const Size(1100, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FlutterErrorDetails? caughtDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        caughtDetails = details;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      // Create category, item, customer, and invoice
      final catId = await db.into(db.itemCategories).insert(
            const ItemCategoriesCompanion(name: drift.Value('قطع')),
          );
      final itemId = await db.into(db.items).insert(
            ItemsCompanion(
              categoryId: drift.Value(catId),
              name: const drift.Value('تيل فرامل'),
              costPrice: const drift.Value(10000),
              salePrice: const drift.Value(15000),
              minQuantity: const drift.Value(1.0),
            ),
          );
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(5.0),
          unitCost: const drift.Value(10000),
        ),
      );
      final custId = await db.into(db.customers).insert(
            const CustomersCompanion(
              name: drift.Value('خالد'),
              phone: drift.Value('12345678'),
            ),
          );
      await invoicesRepo.createDirectSale(
        customerId: custId,
        lines: [
          InvoiceLineEntry(
            lineType: LineType.part,
            itemId: itemId,
            description: 'تيل فرامل',
            quantity: 1.0,
            unitPricePiasters: 15000,
            totalPricePiasters: 15000,
          ),
        ],
        paidAmountPiasters: 15000,
        paymentMethod: PaymentMethod.cash,
      );

      await tester.pumpWidget(buildInvoicesApp());
      await tester.pumpAndSettle();

      // Expect to find customer in table
      expect(find.text('خالد'), findsOneWidget);

      // Tap the row to open details pane
      await tester.tap(find.text('خالد'));
      await tester.pumpAndSettle();

      // Verify details pane is open
      expect(find.byType(InvoiceDetailsPane), findsOneWidget);
      expect(find.text('طباعة الفاتورة'), findsOneWidget);
      expect(find.text('معاينة الفاتورة'), findsOneWidget);
      expect(find.text('بنود ومحتويات الفاتورة'), findsOneWidget);

      // Verify zero overflow exceptions
      expect(caughtDetails, isNull);
      expect(tester.takeException(), isNull);
    });

    test('InvoicePrintBuilder generates A4 and Thermal PDFs with vehicle and complaint', () async {
      final custId = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('عمرو عبد الحميد'),
          phone: drift.Value('01011223344'),
        ),
      );

      final invWithDetails = await invoicesRepo.createDirectSale(
        customerId: custId,
        lines: const [
          InvoiceLineEntry(
            lineType: LineType.service,
            description: 'فحص كمبيوتر وضبط زوايا',
            quantity: 1.0,
            unitPricePiasters: 25000,
            totalPricePiasters: 25000,
          ),
        ],
        paidAmountPiasters: 25000,
        paymentMethod: PaymentMethod.instapay,
        notes: 'صيانة دورية وتغيير زيت',
      );

      const profile = GarageProfile(
        name: 'مركز هيكل لإصلاح السيارات',
        subtitle: 'صيانة وميكانيكا وكهرباء',
        phone: '01004497144',
      );

      final a4Doc = InvoicePrintBuilder.buildA4(invWithDetails, profile);
      final a4Bytes = await a4Doc.save();
      expect(a4Bytes, isNotEmpty);
      expect(a4Bytes.length, greaterThan(1000));

      final thermalDoc = InvoicePrintBuilder.buildThermalReceipt(invWithDetails, profile);
      final thermalBytes = await thermalDoc.save();
      expect(thermalBytes, isNotEmpty);
      expect(thermalBytes.length, greaterThan(500));
    });
  });

  group('Tafqeet Unit Tests', () {
    test('converts various amounts accurately to Arabic words', () {
      expect(Tafqeet.formatPiasters(0), equals('صفر جنيه مصري'));
      expect(Tafqeet.formatPiasters(100), equals('جنيه مصري واحد'));
      expect(Tafqeet.formatPiasters(200), equals('جنيهان مصريان'));
      expect(Tafqeet.formatPiasters(500), equals('خمسة جنيهات مصرية'));
      expect(Tafqeet.formatPiasters(15000), equals('مائة وخمسون جنيهاً مصرياً'));
      expect(Tafqeet.formatPiasters(125000), equals('ألف ومائتان وخمسون جنيهاً مصرياً'));
    });
  });
}

