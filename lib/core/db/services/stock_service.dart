import 'package:drift/drift.dart';

import '../../errors/app_exceptions.dart';
import '../database.dart';

/// Central domain service for all inventory movements.
///
/// Complies with:
/// - Rule R2: Stock on hand is SUM(stock_movements.qty). Movements are never edited or deleted.
/// - Rule R3: All stock changes go through one StockService. No other code inserts into stock_movements.
/// - Rule R4: Negative stock is blocked by default, with a clear Arabic message listing short items.
class StockService {
  const StockService(this._db);

  final AppDatabase _db;

  /// Returns the current stock on hand for [itemId].
  Future<double> onHand(int itemId) => _db.stockOf(itemId);

  /// Returns a map of itemId -> on-hand quantity for all items with movements.
  Future<Map<int, double>> onHandMap() async {
    final qtySum = _db.stockMovements.qty.sum();
    final query = _db.selectOnly(_db.stockMovements)
      ..addColumns([_db.stockMovements.itemId, qtySum])
      ..groupBy([_db.stockMovements.itemId]);

    final rows = await query.get();
    final result = <int, double>{};
    for (final row in rows) {
      final id = row.read(_db.stockMovements.itemId);
      final qty = row.read(qtySum);
      if (id != null) {
        result[id] = qty ?? 0.0;
      }
    }
    return result;
  }

  /// Validates that sufficient stock exists for each item in [requiredItems] (itemId -> requiredQty).
  ///
  /// Throws [InsufficientStockException] with names of missing items if any item has insufficient stock,
  /// unless [allowNegative] is true.
  Future<void> validateStockAvailability(
    Map<int, double> requiredItems, {
    bool allowNegative = false,
  }) async {
    if (allowNegative || requiredItems.isEmpty) return;

    final shortItemNames = <String>[];

    for (final entry in requiredItems.entries) {
      final itemId = entry.key;
      final requiredQty = entry.value;
      if (requiredQty <= 0) continue;

      final currentStock = await onHand(itemId);
      if (currentStock < requiredQty) {
        final item = await (_db.select(_db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
        final name = item?.name ?? 'صنف رقم $itemId';
        shortItemNames.add('$name (المطلوب: $requiredQty، المتاح بالمخزن: $currentStock)');
      }
    }

    if (shortItemNames.isNotEmpty) {
      throw InsufficientStockException(
        'الكمية المتاحة في المخزن لا تكفي لإتمام العملية.\nالأصناف غير المتوفرة:\n• ${shortItemNames.join("\n• ")}',
        shortItems: shortItemNames,
      );
    }
  }

  /// Inserts a new stock movement.
  ///
  /// If the movement deducts stock (qty < 0), it verifies that on-hand stock is sufficient
  /// unless [allowNegative] is true.
  Future<int> addMovement(
    StockMovementsCompanion movement, {
    bool allowNegative = false,
  }) async {
    final qty = movement.qty.value;
    final itemId = movement.itemId.value;

    if (qty < 0 && !allowNegative) {
      final currentStock = await onHand(itemId);
      final needed = qty.abs();
      if (currentStock < needed) {
        final item = await (_db.select(_db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
        final name = item?.name ?? 'صنف رقم $itemId';
        throw InsufficientStockException(
          'رصيد الصنف ($name) في المخزن ($currentStock) غير كافٍ لصرف كمية ($needed).',
          shortItems: [name],
        );
      }
    }

    return _db.into(_db.stockMovements).insert(movement);
  }
}
