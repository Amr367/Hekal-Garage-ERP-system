import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/repositories/categories_repository.dart';
import 'package:garage_erp/core/db/repositories/items_repository.dart';
import 'package:garage_erp/core/db/repositories/returns_repository.dart';
import 'package:garage_erp/core/db/services/stock_service.dart';
import 'package:garage_erp/core/printing/font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await PdfFontLoader.init();
  });

  late AppDatabase db;
  late StockService stockService;
  late ReturnsRepository returnsRepo;
  late CategoriesRepository categoriesRepo;
  late ItemsRepository itemsRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    stockService = StockService(db);
    returnsRepo = DriftReturnsRepository(db, stockService);
    categoriesRepo = DriftCategoriesRepository(db);
    itemsRepo = DriftItemsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createTestItem(String name, int cost, int sale) async {
    final catId = await categoriesRepo.insertCategory('تصنيف عام');
    return itemsRepo.insertItem(
      ItemsCompanion(
        categoryId: drift.Value(catId),
        name: drift.Value(name),
        costPrice: drift.Value(cost),
        salePrice: drift.Value(sale),
      ),
    );
  }

  test('Creates sale return, increases stock, and records lines', () async {
    // 1. Insert an item
    final itemId = await createTestItem('تيل فرامل أمامي', 50000, 75000);

    // Initial stock is 0
    final stockBefore = await stockService.onHand(itemId);
    expect(stockBefore, 0.0);

    // 2. Create customer sale return for 2 units
    final saleReturn = await returnsRepo.createSaleReturn(
      customerName: 'أحمد محمود',
      refundMethod: PaymentMethod.cash,
      reason: 'عيوب صناعة',
      lines: [
        ReturnLineEntry(
          itemId: itemId,
          description: 'تيل فرامل أمامي',
          quantity: 2,
          unitPrice: 75000,
        ),
      ],
    );

    expect(saleReturn.returnNumber, 1);
    expect(saleReturn.isSaleReturn, isTrue);
    expect(saleReturn.totalAmount, 150000);
    expect(saleReturn.lines.length, 1);
    expect(saleReturn.lines.first.quantity, 2.0);

    // Stock should now be +2
    final stockAfter = await stockService.onHand(itemId);
    expect(stockAfter, 2.0);

    // Check summary
    final summary = await returnsRepo.getSummary();
    expect(summary.totalReturnsCount, 1);
    expect(summary.totalSalesReturnsCount, 1);
    expect(summary.totalSalesReturnsAmount, 150000);
  });

  test('Creates purchase return, decreases stock, and records lines', () async {
    // 1. Insert an item
    final itemId = await createTestItem('فلتر زيت أصلي', 20000, 30000);

    // Add initial stock of 10
    await stockService.addMovement(
      StockMovementsCompanion.insert(
        itemId: itemId,
        qty: 10,
        movementType: StockMovementType.adjustment,
        unitCost: const drift.Value(20000),
      ),
    );

    final stockBefore = await stockService.onHand(itemId);
    expect(stockBefore, 10.0);

    // 2. Create supplier purchase return for 3 units
    final purchaseReturn = await returnsRepo.createPurchaseReturn(
      supplierName: 'شركة النور لقطع الغيار',
      refundMethod: PaymentMethod.transfer,
      reason: 'شحنة زائدة',
      lines: [
        ReturnLineEntry(
          itemId: itemId,
          description: 'فلتر زيت أصلي',
          quantity: 3,
          unitPrice: 20000,
        ),
      ],
    );

    expect(purchaseReturn.returnNumber, 1);
    expect(purchaseReturn.isPurchaseReturn, isTrue);
    expect(purchaseReturn.totalAmount, 60000);

    // Stock should now be 10 - 3 = 7
    final stockAfter = await stockService.onHand(itemId);
    expect(stockAfter, 7.0);

    // Check summary
    final summary = await returnsRepo.getSummary();
    expect(summary.totalReturnsCount, 1);
    expect(summary.totalPurchaseReturnsCount, 1);
    expect(summary.totalPurchaseReturnsAmount, 60000);
  });
}
