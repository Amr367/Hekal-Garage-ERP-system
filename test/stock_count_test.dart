import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/providers.dart';
import 'package:garage_erp/core/db/repositories/categories_repository.dart';
import 'package:garage_erp/core/db/repositories/items_repository.dart';
import 'package:garage_erp/core/db/repositories/stock_count_repository.dart';
import 'package:garage_erp/core/db/services/stock_service.dart';
import 'package:garage_erp/core/errors/app_exceptions.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/core/theme/app_theme.dart';
import 'package:garage_erp/features/stock_count/presentation/widgets/stock_count_details_pane.dart';
import 'package:garage_erp/features/stock_count/stock_count_page.dart';

void main() {
  late AppDatabase db;
  late StockService stockService;
  late CategoriesRepository categoriesRepo;
  late ItemsRepository itemsRepo;
  late StockCountRepository stockCountRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    stockService = StockService(db);
    categoriesRepo = DriftCategoriesRepository(db);
    itemsRepo = DriftItemsRepository(db);
    stockCountRepo = DriftStockCountRepository(db, stockService);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createTestItem({
    required String name,
    required int categoryId,
    int costPrice = 10000,
    double initialQty = 10.0,
  }) async {
    final itemId = await itemsRepo.insertItem(
      ItemsCompanion(
        categoryId: drift.Value(categoryId),
        name: drift.Value(name),
        costPrice: drift.Value(costPrice),
        salePrice: drift.Value(costPrice * 2),
        sku: drift.Value('SKU-$name'),
      ),
    );

    if (initialQty > 0) {
      await stockService.addMovement(
        StockMovementsCompanion.insert(
          itemId: itemId,
          movementType: StockMovementType.opening,
          qty: initialQty,
          notes: const drift.Value('Initial opening stock'),
        ),
      );
    }

    return itemId;
  }

  group('DriftStockCountRepository Repository Tests', () {
    test('createStockCount populates lines with current system quantities',
        () async {
      final catId = await categoriesRepo.insertCategory('فلاتر وزيوت');
      await createTestItem(name: 'فلتر زيت تويوتا', categoryId: catId, initialQty: 15.0);
      await createTestItem(name: 'فلتر هواء نيسان', categoryId: catId, initialQty: 8.0);

      final countId = await stockCountRepo.createStockCount(
        scope: 'all',
        notes: 'جرد ربع سنوي',
      );

      final session = await stockCountRepo.getStockCountById(countId);
      expect(session, isNotNull);
      expect(session!.isDraft, isTrue);
      expect(session.countNumber, equals(1));
      expect(session.totalItems, equals(2));
      expect(session.countedItems, equals(0));
      expect(session.remainingItems, equals(2));

      final line1 = session.lines.firstWhere((l) => l.itemName == 'فلتر زيت تويوتا');
      expect(line1.systemQty, equals(15.0));
      expect(line1.countedQty, isNull);
      expect(line1.difference, isNull);
    });

    test('updateCountedQty calculates difference correctly', () async {
      final catId = await categoriesRepo.insertCategory('بوجيهات');
      await createTestItem(
        name: 'بوجيه NGK ياباني',
        categoryId: catId,
        costPrice: 5000, // 50 EGP
        initialQty: 20.0,
      );

      final countId = await stockCountRepo.createStockCount(scope: 'all');
      final session = await stockCountRepo.getStockCountById(countId);
      final line = session!.lines.first;

      // Count 18 items (shortage of 2)
      await stockCountRepo.updateCountedQty(
        lineId: line.id,
        countedQty: 18.0,
        notes: 'عجز قطعتين تالفتين',
      );

      final updated = await stockCountRepo.getStockCountById(countId);
      final updatedLine = updated!.lines.first;

      expect(updatedLine.isCounted, isTrue);
      expect(updatedLine.countedQty, equals(18.0));
      expect(updatedLine.difference, equals(-2.0));
      // differenceValue = -2.0 * 5000 / 100 = -100
      expect(updatedLine.differenceValuePiasters, equals(-100));
      expect(updated.countedItems, equals(1));
      expect(updated.remainingItems, equals(0));
    });

    test('finalizeStockCount records stock movements and marks session finalized',
        () async {
      final catId = await categoriesRepo.insertCategory('سيور');
      final itemId = await createTestItem(
        name: 'سير دينامو بوش',
        categoryId: catId,
        costPrice: 12000,
        initialQty: 5.0,
      );

      final countId = await stockCountRepo.createStockCount(scope: 'all');
      final session = await stockCountRepo.getStockCountById(countId);
      final line = session!.lines.first;

      // Physically found 7 items (surplus of 2)
      await stockCountRepo.updateCountedQty(
        lineId: line.id,
        countedQty: 7.0,
      );

      await stockCountRepo.finalizeStockCount(countId);

      // Verify session is finalized
      final finalizedSession = await stockCountRepo.getStockCountById(countId);
      expect(finalizedSession!.isFinalized, isTrue);
      expect(finalizedSession.finalizedAt, isNotNull);

      // Verify stock level updated to 7.0
      final newStock = await stockService.onHand(itemId);
      expect(newStock, equals(7.0));

      // Attempting to finalize again should throw
      expect(
        () => stockCountRepo.finalizeStockCount(countId),
        throwsA(isA<BusinessRuleException>()),
      );

      // Attempting to delete a finalized count should throw
      expect(
        () => stockCountRepo.deleteStockCount(countId),
        throwsA(isA<BusinessRuleException>()),
      );
    });

    test('deleteStockCount successfully removes draft session and its lines',
        () async {
      final catId = await categoriesRepo.insertCategory('إطارات');
      await createTestItem(name: 'ميشلان 16', categoryId: catId, initialQty: 4.0);

      final countId = await stockCountRepo.createStockCount(scope: 'all');
      expect(await stockCountRepo.getStockCountById(countId), isNotNull);

      await stockCountRepo.deleteStockCount(countId);
      expect(await stockCountRepo.getStockCountById(countId), isNull);
    });

    test('getStockCountSummary returns correct metrics', () async {
      final catId = await categoriesRepo.insertCategory('سوائل');
      await createTestItem(name: 'مياه تبريد خضراء', categoryId: catId, initialQty: 10.0);

      // Create draft count
      await stockCountRepo.createStockCount(scope: 'all');

      // Create and finalize second count
      final count2 = await stockCountRepo.createStockCount(scope: 'all');
      await stockCountRepo.finalizeStockCount(count2);

      final summary = await stockCountRepo.getStockCountSummary();
      expect(summary.totalSessions, equals(2));
      expect(summary.draftSessions, equals(1));
      expect(summary.finalizedSessions, equals(1));
    });
  });

  group('Stock Count UI Widget Tests', () {
    Widget buildStockCountApp({Widget? child}) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          stockServiceProvider.overrideWithValue(stockService),
          categoriesRepositoryProvider.overrideWithValue(categoriesRepo),
          itemsRepositoryProvider.overrideWithValue(itemsRepo),
          stockCountRepositoryProvider.overrideWithValue(stockCountRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: child ?? const StockCountPage(),
            ),
          ),
        ),
      );
    }

    testWidgets('StockCountPage renders KPI cards, toolbar, and empty state',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildStockCountApp());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.stockCountTitle), findsOneWidget);
      expect(find.text(AppStrings.startStockCountButton), findsOneWidget);
      expect(find.text(AppStrings.kpiTotalCountSessions), findsOneWidget);
      expect(find.text('لا توجد جلسات جرد مسجلة'), findsOneWidget);
    });

    testWidgets('StockCountFormDialog opens and creates a new count session',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final catId = await categoriesRepo.insertCategory('قطع غيار تبريد');
      await createTestItem(name: 'طلمبة مياه هيونداي', categoryId: catId, initialQty: 5.0);

      await tester.pumpWidget(buildStockCountApp());
      await tester.pumpAndSettle();

      // Click "بدء جرد جديد"
      await tester.tap(find.text(AppStrings.startStockCountButton));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.newStockCountTitle), findsOneWidget);
      expect(find.text(AppStrings.stockCountScopeLabel), findsOneWidget);

      // Save count
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      // Verify table now shows session #1
      expect(find.text('#1'), findsAtLeastNWidgets(1));
      expect(find.text(AppStrings.countStatusDraft), findsAtLeastNWidgets(1));
    });

    testWidgets('StockCountDetailsPane displays details and supports line edit',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final catId = await categoriesRepo.insertCategory('فرامل');
      await createTestItem(name: 'تيل فرامل نيسان صني', categoryId: catId, initialQty: 10.0);

      final countId = await stockCountRepo.createStockCount(scope: 'all');
      final session = await stockCountRepo.getStockCountById(countId);

      await tester.pumpWidget(
        buildStockCountApp(
          child: SizedBox(
            height: 700,
            child: StockCountDetailsPane(stockCount: session!),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('جلسة جرد #1'), findsOneWidget);
      expect(find.text(AppStrings.finalizeCountButton), findsOneWidget);
      expect(find.text('تيل فرامل نيسان صني'), findsOneWidget);
      expect(find.text(AppStrings.notCounted), findsOneWidget);
    });
  });
}
