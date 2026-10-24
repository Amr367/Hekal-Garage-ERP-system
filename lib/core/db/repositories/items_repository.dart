import 'package:drift/drift.dart';

import '../../errors/app_exceptions.dart';
import '../database.dart';
import '../../../features/inventory/domain/inventory_summary.dart';
import '../../../features/inventory/domain/item_with_stock.dart';
import '../../../features/inventory/domain/stock_movement_entry.dart';

abstract interface class ItemsRepository {
  Future<Item> getById(int id);
  Future<Item?> getBySku(String sku);
  Future<Item?> getByBarcode(String barcode);
  Future<List<Item>> getAll({bool onlyActive = false, int? categoryId});
  Future<List<Item>> search(String query);
  Future<int> insertItem(ItemsCompanion item);
  Future<bool> updateItem(Item item);
  Future<void> deactivate(int id);
  Future<void> deleteItem(int id);
  Future<List<ItemWithStock>> getItemsWithStock({
    String? query,
    int? categoryId,
    bool onlyLowStock = false,
    bool onlyActive = false,
  });
  Future<List<StockMovementEntry>> getItemLedger(int itemId);
  Future<InventorySummary> getInventorySummary();
}

class DriftItemsRepository implements ItemsRepository {
  const DriftItemsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Item> getById(int id) async {
    final item = await (_db.select(_db.items)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (item == null) {
      throw NotFoundException('الصنف برقم ($id) غير موجود.');
    }
    return item;
  }

  @override
  Future<Item?> getBySku(String sku) {
    final trimmed = sku.trim();
    if (trimmed.isEmpty) return Future.value(null);
    return (_db.select(_db.items)..where((t) => t.sku.equals(trimmed))).getSingleOrNull();
  }

  @override
  Future<Item?> getByBarcode(String barcode) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return Future.value(null);
    return (_db.select(_db.items)..where((t) => t.barcode.equals(trimmed))).getSingleOrNull();
  }

  @override
  Future<List<Item>> getAll({bool onlyActive = false, int? categoryId}) {
    final query = _db.select(_db.items);
    if (onlyActive) {
      query.where((t) => t.isActive.equals(true));
    }
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    }
    return query.get();
  }

  @override
  Future<List<Item>> search(String query) {
    final cleaned = query.trim();
    if (cleaned.isEmpty) {
      return getAll(onlyActive: true);
    }
    return (_db.select(_db.items)
          ..where((t) =>
              t.name.contains(cleaned) |
              t.sku.contains(cleaned) |
              t.barcode.contains(cleaned)))
        .get();
  }

  @override
  Future<int> insertItem(ItemsCompanion item) async {
    final name = item.name.value.trim();
    if (name.isEmpty) {
      throw const ValidationException('اسم الصنف مطلوب.');
    }

    if (item.sku.present && item.sku.value != null && item.sku.value!.trim().isNotEmpty) {
      final existingSku = await getBySku(item.sku.value!);
      if (existingSku != null) {
        throw ValidationException('كود الصنف (SKU: ${item.sku.value}) مستخدم مسبقاً لصنف آخر.');
      }
    }

    return _db.into(_db.items).insert(item);
  }

  @override
  Future<bool> updateItem(Item item) {
    return _db.update(_db.items).replace(item);
  }

  @override
  Future<void> deactivate(int id) async {
    final updated = await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
      const ItemsCompanion(isActive: Value(false)),
    );
    if (updated == 0) {
      throw NotFoundException('الصنف برقم ($id) غير موجود لتعطيله.');
    }
  }

  @override
  Future<void> deleteItem(int id) async {
    // Check if item has stock movements or invoice/work-order lines
    final movementCount = await (_db.selectOnly(_db.stockMovements)
          ..addColumns([_db.stockMovements.id.count()])
          ..where(_db.stockMovements.itemId.equals(id)))
        .getSingle();

    final int movements = movementCount.read(_db.stockMovements.id.count()) ?? 0;
    if (movements > 0) {
      throw const BusinessRuleException(
        'لا يمكن حذف هذا الصنف لوجود حركات مخزنية مسجلة له. يمكنك إلغاء تفعيله بدلاً من الحذف.',
      );
    }

    final deleted = await (_db.delete(_db.items)..where((t) => t.id.equals(id))).go();
    if (deleted == 0) {
      throw NotFoundException('الصنف برقم ($id) غير موجود لحذفه.');
    }
  }

  @override
  Future<List<ItemWithStock>> getItemsWithStock({
    String? query,
    int? categoryId,
    bool onlyLowStock = false,
    bool onlyActive = false,
  }) async {
    // 1. Fetch categories map (id -> name)
    final categories = await _db.select(_db.itemCategories).get();
    final catMap = <int, String>{for (final c in categories) c.id: c.name};

    // 2. Fetch on-hand stock map for all items
    final qtySum = _db.stockMovements.qty.sum();
    final stockQuery = _db.selectOnly(_db.stockMovements)
      ..addColumns([_db.stockMovements.itemId, qtySum])
      ..groupBy([_db.stockMovements.itemId]);
    final stockRows = await stockQuery.get();
    final stockMap = <int, double>{};
    for (final r in stockRows) {
      final id = r.read(_db.stockMovements.itemId);
      final qty = r.read(qtySum);
      if (id != null) {
        stockMap[id] = qty ?? 0.0;
      }
    }

    // 3. Fetch items with optional category and active filters
    final itemsQuery = _db.select(_db.items);
    if (onlyActive) {
      itemsQuery.where((t) => t.isActive.equals(true));
    }
    if (categoryId != null) {
      itemsQuery.where((t) => t.categoryId.equals(categoryId));
    }
    final items = await itemsQuery.get();

    // 4. Map to ItemWithStock and apply filters
    final results = <ItemWithStock>[];
    final q = query?.trim().toLowerCase() ?? '';

    for (final item in items) {
      final stockOnHand = stockMap[item.id] ?? 0.0;
      final categoryName = catMap[item.categoryId] ?? 'قسم غير محدد';
      final itemWithStock = ItemWithStock(
        item: item,
        categoryName: categoryName,
        stockOnHand: stockOnHand,
      );

      // Filter by low stock if required
      if (onlyLowStock && !itemWithStock.isLowStock && !itemWithStock.isOutOfStock) {
        continue;
      }

      // Filter by search query if provided
      if (q.isNotEmpty) {
        final matchName = item.name.toLowerCase().contains(q);
        final matchSku = item.sku?.toLowerCase().contains(q) ?? false;
        final matchBarcode = item.barcode?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchSku && !matchBarcode) {
          continue;
        }
      }

      results.add(itemWithStock);
    }

    return results;
  }

  @override
  Future<List<StockMovementEntry>> getItemLedger(int itemId) async {
    final movements = await (_db.select(_db.stockMovements)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .get();

    final entries = <StockMovementEntry>[];
    double runningBalance = 0.0;

    for (final m in movements) {
      runningBalance += m.qty;
      entries.add(StockMovementEntry(
        movement: m,
        balanceAfter: runningBalance,
      ));
    }

    // Return in reverse chronological order (newest first) for UI display
    return entries.reversed.toList();
  }

  @override
  Future<InventorySummary> getInventorySummary() async {
    final allItems = await getItemsWithStock(onlyActive: true);

    final int totalItems = allItems.length;
    int lowStock = 0;
    int outOfStock = 0;
    int totalCost = 0;
    int totalSale = 0;

    for (final it in allItems) {
      if (it.isOutOfStock) {
        outOfStock++;
      } else if (it.isLowStock) {
        lowStock++;
      }
      if (it.stockOnHand > 0) {
        totalCost += it.stockValueCost;
        totalSale += it.stockValueSale;
      }
    }

    return InventorySummary(
      totalItemsCount: totalItems,
      lowStockCount: lowStock,
      outOfStockCount: outOfStock,
      totalCostValue: totalCost,
      totalSaleValue: totalSale,
    );
  }
}
