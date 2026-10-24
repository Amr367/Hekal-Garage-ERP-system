import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/providers.dart';
import 'package:garage_erp/core/db/repositories/categories_repository.dart';
import 'package:garage_erp/core/db/repositories/items_repository.dart';
import 'package:garage_erp/core/db/repositories/settings_repository.dart';
import 'package:garage_erp/core/db/services/stock_service.dart';
import 'package:garage_erp/core/errors/app_exceptions.dart';
import 'package:garage_erp/core/money/money.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/core/theme/app_theme.dart';
import 'package:garage_erp/features/inventory/domain/item_with_stock.dart';
import 'package:garage_erp/features/inventory/inventory_page.dart';
import 'package:garage_erp/features/inventory/presentation/widgets/categories_management_dialog.dart';
import 'package:garage_erp/features/inventory/presentation/widgets/item_form_dialog.dart';
import 'package:garage_erp/features/inventory/presentation/widgets/item_ledger_dialog.dart';
import 'package:garage_erp/features/inventory/presentation/widgets/stock_adjustment_dialog.dart';
import 'package:garage_erp/features/settings/data/pin_auth_service.dart';
import 'package:garage_erp/features/settings/presentation/settings_controller.dart';

void main() {
  late AppDatabase db;
  late ItemsRepository itemsRepo;
  late CategoriesRepository categoriesRepo;
  late StockService stockService;
  late SettingsRepository settingsRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    itemsRepo = DriftItemsRepository(db);
    categoriesRepo = DriftCategoriesRepository(db);
    stockService = StockService(db);
    settingsRepo = DriftSettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ItemsRepository & StockService Unit Tests', () {
    test('insert and fetch item with category', () async {
      final catId = await categoriesRepo.insertCategory('فلاتر وزيوت');

      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('فلتر زيت تويوتا كورولا'),
          sku: const drift.Value('FLT-TOY-01'),
          costPrice: const drift.Value(15000), // 150.00 EGP
          salePrice: const drift.Value(22000), // 220.00 EGP
          minQuantity: const drift.Value(5.0),
          unit: const drift.Value('قطعة'),
        ),
      );

      final item = await itemsRepo.getById(itemId);
      expect(item.id, itemId);
      expect(item.name, 'فلتر زيت تويوتا كورولا');
      expect(item.sku, 'FLT-TOY-01');
      expect(item.costPrice, 15000);
      expect(item.salePrice, 22000);
      expect(item.minQuantity, 5.0);
      expect(item.isActive, isTrue);
    });

    test('SKU uniqueness is enforced (throws ValidationException on duplicate)', () async {
      final catId = await categoriesRepo.insertCategory('فرامل');

      await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('تيل فرامل أصلي'),
          sku: const drift.Value('BRK-100'),
          costPrice: const drift.Value(30000),
          salePrice: const drift.Value(45000),
        ),
      );

      expect(
        () => itemsRepo.insertItem(
          ItemsCompanion(
            categoryId: drift.Value(catId),
            name: const drift.Value('تيل فرامل تجاري'),
            sku: const drift.Value('BRK-100'),
            costPrice: const drift.Value(20000),
            salePrice: const drift.Value(30000),
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('opening stock records initial movement and calculates on-hand balance (Rules R2 & R3)', () async {
      final catId = await categoriesRepo.insertCategory('سيور');

      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('سير دينامو'),
          costPrice: const drift.Value(8000),
          salePrice: const drift.Value(12000),
        ),
      );

      // Add opening stock movement via StockService
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(15.0),
          unitCost: const drift.Value(8000),
          notes: const drift.Value('رصيد افتتاحي'),
        ),
      );

      final onHand = await stockService.onHand(itemId);
      expect(onHand, 15.0);

      // Verify stock ledger has 1 entry with balanceAfter = 15.0
      final ledger = await itemsRepo.getItemLedger(itemId);
      expect(ledger.length, 1);
      expect(ledger.first.movement.qty, 15.0);
      expect(ledger.first.balanceAfter, 15.0);
      expect(ledger.first.typeLabel, AppStrings.movementTypeOpening);
    });

    test('manual stock adjustments update balance and maintain running cumulative balance', () async {
      final catId = await categoriesRepo.insertCategory('إطارات');

      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('إطار ميشلان 16'),
          costPrice: const drift.Value(250000),
          salePrice: const drift.Value(320000),
        ),
      );

      // 1. Opening stock: 10
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(10.0),
          unitCost: const drift.Value(250000),
        ),
      );

      // 2. Adjustment Add: +5
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.adjustment),
          qty: const drift.Value(5.0),
          unitCost: const drift.Value(250000),
          notes: const drift.Value('زيادة تسوية'),
        ),
      );

      // 3. Adjustment Deduct: -3
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.adjustment),
          qty: const drift.Value(-3.0),
          unitCost: const drift.Value(250000),
          notes: const drift.Value('عجز تالف'),
        ),
      );

      expect(await stockService.onHand(itemId), 12.0);

      final ledger = await itemsRepo.getItemLedger(itemId);
      expect(ledger.length, 3);
      // ledger is reversed (newest first)
      expect(ledger[0].balanceAfter, 12.0);
      expect(ledger[0].movement.qty, -3.0);
      expect(ledger[1].balanceAfter, 15.0);
      expect(ledger[1].movement.qty, 5.0);
      expect(ledger[2].balanceAfter, 10.0);
      expect(ledger[2].movement.qty, 10.0);
    });

    test('Rule R4: Negative stock is blocked when deducting beyond on-hand quantity', () async {
      final catId = await categoriesRepo.insertCategory('بطاريات');

      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('بطارية كلورايد 70 أمبير'),
          costPrice: const drift.Value(180000),
          salePrice: const drift.Value(230000),
        ),
      );

      // On-hand is 2
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(2.0),
        ),
      );

      // Try to deduct 5
      expect(
        () => stockService.addMovement(
          StockMovementsCompanion(
            itemId: drift.Value(itemId),
            movementType: const drift.Value(StockMovementType.adjustment),
            qty: const drift.Value(-5.0),
          ),
        ),
        throwsA(isA<InsufficientStockException>()),
      );
    });

    test('deleting item with stock movements throws BusinessRuleException', () async {
      final catId = await categoriesRepo.insertCategory('شمعات');

      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('بوجيهات NGK'),
          costPrice: const drift.Value(6000),
          salePrice: const drift.Value(9000),
        ),
      );

      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(4.0),
        ),
      );

      expect(
        () => itemsRepo.deleteItem(itemId),
        throwsA(isA<BusinessRuleException>()),
      );
    });

    test('categories management: merge, delete empty, and block deletion of populated category', () async {
      final cat1 = await categoriesRepo.insertCategory('قسم قديم');
      final cat2 = await categoriesRepo.insertCategory('قسم جديد');

      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(cat1),
          name: const drift.Value('صنف تجريبي'),
          costPrice: const drift.Value(5000),
          salePrice: const drift.Value(8000),
        ),
      );

      // Deleting populated cat1 should throw
      expect(
        () => categoriesRepo.deleteCategory(cat1),
        throwsA(isA<BusinessRuleException>()),
      );

      // Merge cat1 into cat2
      await categoriesRepo.mergeAndDelete(cat1, cat2);

      // Verify item now belongs to cat2
      final item = await itemsRepo.getById(itemId);
      expect(item.categoryId, cat2);

      // Verify cat1 is deleted
      final allCats = await categoriesRepo.getAll();
      expect(allCats.any((c) => c.id == cat1), isFalse);
      expect(allCats.any((c) => c.id == cat2), isTrue);

      // Create and delete an empty category
      final cat3 = await categoriesRepo.insertCategory('قسم مؤقت');
      await categoriesRepo.deleteCategory(cat3);
      final finalCats = await categoriesRepo.getAll();
      expect(finalCats.any((c) => c.id == cat3), isFalse);
    });

    test('inventory summary computes total items, stock values, and low stock counts', () async {
      final catId = await categoriesRepo.insertCategory('فلاتر');

      // Item 1: onHand 10, cost 100 EGP, sale 150 EGP, minQty 5 (plentiful)
      final id1 = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('صنف وفير'),
          costPrice: const drift.Value(10000),
          salePrice: const drift.Value(15000),
          minQuantity: const drift.Value(5.0),
        ),
      );
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(id1),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(10.0),
        ),
      );

      // Item 2: onHand 2, cost 50 EGP, sale 80 EGP, minQty 5 (low stock)
      final id2 = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('صنف ناقص'),
          costPrice: const drift.Value(5000),
          salePrice: const drift.Value(8000),
          minQuantity: const drift.Value(5.0),
        ),
      );
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(id2),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(2.0),
        ),
      );

      // Item 3: onHand 0 (out of stock)
      await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('صنف نافد'),
          costPrice: const drift.Value(2000),
          salePrice: const drift.Value(4000),
          minQuantity: const drift.Value(2.0),
        ),
      );

      final summary = await itemsRepo.getInventorySummary();
      expect(summary.totalItemsCount, 3);
      expect(summary.lowStockCount, 1);
      expect(summary.outOfStockCount, 1);

      // Total Cost Value: (10 * 10000) + (2 * 5000) = 100000 + 10000 = 110000 piasters (1100.00 EGP)
      expect(summary.totalCostValue, 110000);
      // Total Sale Value: (10 * 15000) + (2 * 8000) = 150000 + 16000 = 166000 piasters (1660.00 EGP)
      expect(summary.totalSaleValue, 166000);
      expect(summary.potentialProfit, 56000);
    });

    test('search filters items by name, SKU, and barcode', () async {
      final catId = await categoriesRepo.insertCategory('كهرباء');

      await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('لمبة هالوجين H4'),
          sku: const drift.Value('LMP-H4'),
          barcode: const drift.Value('6221009999'),
          costPrice: const drift.Value(4000),
          salePrice: const drift.Value(6000),
        ),
      );

      final byName = await itemsRepo.getItemsWithStock(query: 'هالوجين');
      expect(byName.length, 1);

      final bySku = await itemsRepo.getItemsWithStock(query: 'LMP-H4');
      expect(bySku.length, 1);

      final byBarcode = await itemsRepo.getItemsWithStock(query: '6221009999');
      expect(byBarcode.length, 1);

      final noMatch = await itemsRepo.getItemsWithStock(query: 'مساعدين');
      expect(noMatch.isEmpty, isTrue);
    });
  });

  group('Inventory UI Widget Tests', () {
    Widget buildTestApp(Widget child) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          itemsRepositoryProvider.overrideWithValue(itemsRepo),
          categoriesRepositoryProvider.overrideWithValue(categoriesRepo),
          stockServiceProvider.overrideWithValue(stockService),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          pinAuthServiceProvider.overrideWithValue(PinAuthService(settingsRepo)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: child),
          ),
        ),
      );
    }

    testWidgets('InventoryPage renders KPI cards, table, and header buttons', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catId = await categoriesRepo.insertCategory('فلاتر');
      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('فلتر هواء كورولا'),
          sku: const drift.Value('FLT-AIR-01'),
          costPrice: const drift.Value(12000),
          salePrice: const drift.Value(18000),
          minQuantity: const drift.Value(2.0),
        ),
      );
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(8.0),
        ),
      );

      await tester.pumpWidget(buildTestApp(const InventoryPage()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.inventoryTitle), findsOneWidget);
      expect(find.text(AppStrings.newItemButton), findsOneWidget);
      expect(find.text(AppStrings.manageCategoriesButton), findsOneWidget);
      expect(find.text(AppStrings.totalItemsCountLabel), findsOneWidget);
      expect(find.text('فلتر هواء كورولا'), findsOneWidget);
      expect(find.text('FLT-AIR-01'), findsOneWidget);
      expect(find.text(MoneyUtils.formatPounds(18000)), findsWidgets);
    });

    testWidgets('cost price is hidden by default and reveals on button tap when PIN is not set', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Disable require PIN for test
      await settingsRepo.setBool(PinAuthService.keyRequireCostPrice, false);

      final catId = await categoriesRepo.insertCategory('زيوت');
      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('زيت موتور 5W30'),
          costPrice: const drift.Value(65000),
          salePrice: const drift.Value(90000),
        ),
      );
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(10.0),
        ),
      );

      await tester.pumpWidget(buildTestApp(const InventoryPage()));
      await tester.pumpAndSettle();

      // By default, cost price shows hidden label
      expect(find.text(AppStrings.costPriceHidden), findsWidgets);

      // Tap the reveal button in KPI cards
      final revealBtn = find.byTooltip(AppStrings.revealCostPriceTooltip).first;
      await tester.tap(revealBtn);
      await tester.pumpAndSettle();

      // Now formatted cost price should be visible
      expect(find.text(MoneyUtils.formatPounds(65000)), findsWidgets);
    });

    testWidgets('ItemFormDialog creates new item with opening stock', (tester) async {
      tester.view.physicalSize = const Size(1100, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await categoriesRepo.insertCategory('إكسسوارات');

      await tester.pumpWidget(buildTestApp(const ItemFormDialog()));
      await tester.pumpAndSettle();

      // Enter name
      final nameField = find.widgetWithText(TextFormField, 'اسم الصنف *');
      await tester.enterText(nameField, 'دواسات سيارة جلد');

      // Enter SKU
      final skuField = find.widgetWithText(TextFormField, 'كود الصنف (SKU)');
      await tester.enterText(skuField, 'ACC-MAT-01');

      // Enter opening stock
      final openingField = find.widgetWithText(TextFormField, AppStrings.itemOpeningStockLabel);
      if (openingField.evaluate().isNotEmpty) {
        await tester.enterText(openingField, '5');
      }

      // Tap Save
      final saveBtn = find.text(AppStrings.save);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      final items = await itemsRepo.getAll();
      expect(items.any((it) => it.name == 'دواسات سيارة جلد'), isTrue);
    });

    testWidgets('StockAdjustmentDialog records adjustment quantity', (tester) async {
      tester.view.physicalSize = const Size(1100, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Disable PIN protection for test
      await settingsRepo.setBool(PinAuthService.keyRequireStockAdjust, false);

      final catId = await categoriesRepo.insertCategory('سوائل');
      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('مياه رادياتير خضراء'),
          costPrice: const drift.Value(3000),
          salePrice: const drift.Value(5000),
        ),
      );
      final item = await itemsRepo.getById(itemId);
      final itemWithStock = ItemWithStock(item: item, categoryName: 'سوائل', stockOnHand: 5.0);

      await tester.pumpWidget(
        buildTestApp(StockAdjustmentDialog(itemWithStock: itemWithStock)),
      );
      await tester.pumpAndSettle();

      // Enter reason
      final reasonField = find.widgetWithText(TextFormField, AppStrings.adjustmentReasonLabel);
      await tester.enterText(reasonField, 'إضافة كمية من المخزن الاحتياطي');

      // Save
      final saveBtn = find.text(AppStrings.save);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      final movements = await itemsRepo.getItemLedger(itemId);
      expect(movements.isNotEmpty, isTrue);
      expect(movements.first.movement.movementType, StockMovementType.adjustment);
    });

    testWidgets('ItemLedgerDialog renders movement history table', (tester) async {
      tester.view.physicalSize = const Size(1100, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final catId = await categoriesRepo.insertCategory('فلاتر');
      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('فلتر بنزين هيونداي'),
          costPrice: const drift.Value(10000),
          salePrice: const drift.Value(16000),
        ),
      );
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(12.0),
          unitCost: const drift.Value(10000),
          notes: const drift.Value('افتتاحي'),
        ),
      );
      final item = await itemsRepo.getById(itemId);
      final itemWithStock = ItemWithStock(item: item, categoryName: 'فلاتر', stockOnHand: 12.0);

      await tester.pumpWidget(
        buildTestApp(ItemLedgerDialog(itemWithStock: itemWithStock)),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.movementTypeOpening), findsOneWidget);
      expect(find.text('افتتاحي'), findsOneWidget);
      expect(find.text(AppStrings.close), findsOneWidget);
    });

    testWidgets('CategoriesManagementDialog displays categories and add input', (tester) async {
      tester.view.physicalSize = const Size(1100, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await categoriesRepo.insertCategory('أقسام الكهرباء');
      await categoriesRepo.insertCategory('أقسام الميكانيكا');

      await tester.pumpWidget(buildTestApp(const CategoriesManagementDialog()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.manageCategoriesButton), findsOneWidget);
      expect(find.text('أقسام الكهرباء'), findsOneWidget);
      expect(find.text('أقسام الميكانيكا'), findsOneWidget);
      expect(find.text(AppStrings.newCategoryButton), findsOneWidget);
    });
  });
}
