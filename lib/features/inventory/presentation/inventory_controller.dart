import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../domain/inventory_summary.dart';
import '../domain/item_with_stock.dart';
import '../domain/stock_movement_entry.dart';

/// Filter toggle: only low stock / out of stock items.
class InventoryLowStockFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool val) => state = val;
}

final inventoryLowStockFilterProvider =
    NotifierProvider<InventoryLowStockFilterNotifier, bool>(
  InventoryLowStockFilterNotifier.new,
);

/// Search query string for items (name, SKU, barcode).
class InventorySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String val) => state = val;
}

final inventorySearchQueryProvider =
    NotifierProvider<InventorySearchQueryNotifier, String>(
  InventorySearchQueryNotifier.new,
);

/// Category filter: null means all categories.
class InventorySelectedCategoryNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? id) => state = id;
}

final inventorySelectedCategoryProvider =
    NotifierProvider<InventorySelectedCategoryNotifier, int?>(
  InventorySelectedCategoryNotifier.new,
);

/// Cost price visibility state (sensitive operation per Rule R12).
class InventoryCostPriceRevealedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void reveal() => state = true;
  void hide() => state = false;
}

final inventoryCostPriceRevealedProvider =
    NotifierProvider<InventoryCostPriceRevealedNotifier, bool>(
  InventoryCostPriceRevealedNotifier.new,
);

/// Selected item ID in the inventory master list.
class SelectedInventoryItemIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? id) => state = id;
}

final selectedInventoryItemIdProvider =
    NotifierProvider<SelectedInventoryItemIdNotifier, int?>(
  SelectedInventoryItemIdNotifier.new,
);

/// AsyncNotifier for the list of items with stock on hand and categories.
class InventoryListNotifier extends AsyncNotifier<List<ItemWithStock>> {
  @override
  Future<List<ItemWithStock>> build() async {
    final repo = ref.watch(itemsRepositoryProvider);
    final search = ref.watch(inventorySearchQueryProvider);
    final categoryId = ref.watch(inventorySelectedCategoryProvider);
    final onlyLowStock = ref.watch(inventoryLowStockFilterProvider);

    return repo.getItemsWithStock(
      query: search.trim().isEmpty ? null : search.trim(),
      categoryId: categoryId,
      onlyLowStock: onlyLowStock,
      onlyActive: false,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final inventoryListProvider =
    AsyncNotifierProvider<InventoryListNotifier, List<ItemWithStock>>(
  InventoryListNotifier.new,
);

/// Currently selected item with stock object.
final selectedItemWithStockProvider = Provider<ItemWithStock?>((ref) {
  final itemsAsync = ref.watch(inventoryListProvider);
  final selectedId = ref.watch(selectedInventoryItemIdProvider);

  return itemsAsync.when(
    data: (items) {
      if (selectedId == null) return null;
      try {
        return items.firstWhere((it) => it.item.id == selectedId);
      } catch (_) {
        return null;
      }
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Aggregated inventory KPIs.
final inventorySummaryProvider = FutureProvider<InventorySummary>((ref) async {
  // Re-run whenever the inventory list updates
  ref.watch(inventoryListProvider);
  final repo = ref.watch(itemsRepositoryProvider);
  return repo.getInventorySummary();
});

/// Stock movement card (ledger) for an item.
final itemLedgerProvider =
    FutureProvider.family<List<StockMovementEntry>, int>((ref, itemId) async {
  final repo = ref.watch(itemsRepositoryProvider);
  return repo.getItemLedger(itemId);
});

/// AsyncNotifier for item categories.
class CategoriesListNotifier extends AsyncNotifier<List<ItemCategory>> {
  @override
  Future<List<ItemCategory>> build() async {
    final repo = ref.watch(categoriesRepositoryProvider);
    return repo.getAll();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final categoriesListProvider =
    AsyncNotifierProvider<CategoriesListNotifier, List<ItemCategory>>(
  CategoriesListNotifier.new,
);

/// Actions controller for creating/editing items, adjusting stock, and managing categories.
class InventoryActionsController {
  const InventoryActionsController(this._ref);

  final Ref _ref;

  /// Creates a new item and optionally records opening stock via StockService.
  Future<int> createItem({
    required String name,
    required int categoryId,
    String? sku,
    String? barcode,
    String? unit,
    required int costPrice,
    required int salePrice,
    double minQuantity = 0.0,
    double openingStock = 0.0,
  }) async {
    final itemsRepo = _ref.read(itemsRepositoryProvider);
    final stockService = _ref.read(stockServiceProvider);

    final companion = ItemsCompanion(
      name: drift.Value(name),
      categoryId: drift.Value(categoryId),
      sku: drift.Value(sku),
      barcode: drift.Value(barcode),
      unit: drift.Value(unit ?? 'قطعة'),
      costPrice: drift.Value(costPrice),
      salePrice: drift.Value(salePrice),
      minQuantity: drift.Value(minQuantity),
      isActive: const drift.Value(true),
    );

    final itemId = await itemsRepo.insertItem(companion);

    // If opening stock was specified, record initial stock movement via StockService
    if (openingStock > 0) {
      await stockService.addMovement(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: drift.Value(openingStock),
          unitCost: drift.Value(costPrice),
          notes: const drift.Value('رصيد افتتاحي عند إنشاء الصنف'),
        ),
      );
    }

    _ref.read(inventoryListProvider.notifier).refresh();
    _ref.invalidate(inventorySummaryProvider);
    _ref.read(selectedInventoryItemIdProvider.notifier).set(itemId);

    return itemId;
  }

  /// Updates an existing item's metadata and prices.
  Future<void> updateItem(Item item) async {
    final itemsRepo = _ref.read(itemsRepositoryProvider);
    await itemsRepo.updateItem(item);

    _ref.read(inventoryListProvider.notifier).refresh();
    _ref.invalidate(inventorySummaryProvider);
  }

  /// Deactivates an item (soft-delete).
  Future<void> deactivateItem(int id) async {
    final itemsRepo = _ref.read(itemsRepositoryProvider);
    await itemsRepo.deactivate(id);

    _ref.read(inventoryListProvider.notifier).refresh();
    _ref.invalidate(inventorySummaryProvider);
  }

  /// Re-activates a deactivated item.
  Future<void> activateItem(Item item) async {
    final itemsRepo = _ref.read(itemsRepositoryProvider);
    await itemsRepo.updateItem(item.copyWith(isActive: true));

    _ref.read(inventoryListProvider.notifier).refresh();
    _ref.invalidate(inventorySummaryProvider);
  }

  /// Deletes an item if no stock movements exist, otherwise throws exception.
  Future<void> deleteItem(int id) async {
    final itemsRepo = _ref.read(itemsRepositoryProvider);
    await itemsRepo.deleteItem(id);

    final selectedId = _ref.read(selectedInventoryItemIdProvider);
    if (selectedId == id) {
      _ref.read(selectedInventoryItemIdProvider.notifier).set(null);
    }

    _ref.read(inventoryListProvider.notifier).refresh();
    _ref.invalidate(inventorySummaryProvider);
  }

  /// Performs a manual stock adjustment via StockService (Rule R2, R3, R4).
  Future<void> adjustStock({
    required int itemId,
    required double qty,
    required bool isAdd,
    required int unitCost,
    String? notes,
  }) async {
    final stockService = _ref.read(stockServiceProvider);
    final movementQty = isAdd ? qty : -qty;

    await stockService.addMovement(
      StockMovementsCompanion(
        itemId: drift.Value(itemId),
        movementType: const drift.Value(StockMovementType.adjustment),
        qty: drift.Value(movementQty),
        unitCost: drift.Value(unitCost),
        refType: const drift.Value('adjustment'),
        notes: drift.Value(notes),
      ),
    );

    _ref.read(inventoryListProvider.notifier).refresh();
    _ref.invalidate(inventorySummaryProvider);
    _ref.invalidate(itemLedgerProvider(itemId));
  }

  /// Category management actions.
  Future<int> createCategory(String name) async {
    final catRepo = _ref.read(categoriesRepositoryProvider);
    final id = await catRepo.insertCategory(name);
    _ref.read(categoriesListProvider.notifier).refresh();
    return id;
  }

  Future<void> renameCategory(int id, String newName) async {
    final catRepo = _ref.read(categoriesRepositoryProvider);
    await catRepo.renameCategory(id, newName);
    _ref.read(categoriesListProvider.notifier).refresh();
    _ref.read(inventoryListProvider.notifier).refresh();
  }

  Future<void> deleteCategory(int id) async {
    final catRepo = _ref.read(categoriesRepositoryProvider);
    await catRepo.deleteCategory(id);
    _ref.read(categoriesListProvider.notifier).refresh();
    _ref.read(inventoryListProvider.notifier).refresh();
  }

  Future<void> mergeCategories(int sourceId, int targetId) async {
    final catRepo = _ref.read(categoriesRepositoryProvider);
    await catRepo.mergeAndDelete(sourceId, targetId);
    _ref.read(categoriesListProvider.notifier).refresh();
    _ref.read(inventoryListProvider.notifier).refresh();
  }
}

final inventoryActionsControllerProvider =
    Provider<InventoryActionsController>((ref) {
  return InventoryActionsController(ref);
});
