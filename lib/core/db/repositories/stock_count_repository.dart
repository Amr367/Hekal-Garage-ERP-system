import 'package:drift/drift.dart';

import '../../errors/app_exceptions.dart';
import '../../strings.dart';
import '../database.dart';
import '../services/stock_service.dart';
import '../../../features/stock_count/domain/stock_count_line_entry.dart';
import '../../../features/stock_count/domain/stock_count_summary.dart';
import '../../../features/stock_count/domain/stock_count_with_details.dart';

/// Repository contract for stock count operations.
abstract class StockCountRepository {
  /// Creates a new stock count session, populating lines with current system
  /// quantities. Returns the created session ID.
  ///
  /// [scope] must be one of 'all', 'category', 'recent'.
  /// [categoryId] is required when scope is 'category'.
  Future<int> createStockCount({
    required String scope,
    int? categoryId,
    String? notes,
  });

  /// Retrieves all stock count sessions ordered by creation date descending.
  Future<List<StockCountWithDetails>> getStockCounts({String? search});

  /// Retrieves a single stock count session by ID.
  Future<StockCountWithDetails?> getStockCountById(int id);

  /// Updates the counted quantity and optional notes for a stock count line.
  Future<void> updateCountedQty({
    required int lineId,
    required double countedQty,
    String? notes,
  });

  /// Finalizes a draft stock count session:
  ///   1. Records `countDiff` movements via StockService for all lines
  ///      with a non-zero difference.
  ///   2. Updates the session status to `finalized` with a timestamp.
  Future<void> finalizeStockCount(int stockCountId);

  /// Deletes a draft stock count session. Finalized sessions cannot be deleted.
  Future<void> deleteStockCount(int stockCountId);

  /// Returns aggregated summary metrics for stock count KPI cards.
  Future<StockCountSummary> getStockCountSummary();
}

/// Drift-backed implementation of [StockCountRepository].
class DriftStockCountRepository implements StockCountRepository {
  const DriftStockCountRepository(this._db, this._stockService);

  final AppDatabase _db;
  final StockService _stockService;

  /// Returns the next sequential count number.
  Future<int> _nextCountNumber() async {
    final maxNumber = _db.stockCounts.countNumber.max();
    final query = _db.selectOnly(_db.stockCounts)..addColumns([maxNumber]);
    final row = await query.getSingle();
    final currentMax = row.read(maxNumber);
    return (currentMax ?? 0) + 1;
  }

  @override
  Future<int> createStockCount({
    required String scope,
    int? categoryId,
    String? notes,
  }) async {
    return _db.transaction(() async {
      // 1. Determine which items to include.
      final itemQuery = _db.select(_db.items).join([
        innerJoin(
          _db.itemCategories,
          _db.itemCategories.id.equalsExp(_db.items.categoryId),
        ),
      ]);
      itemQuery.where(_db.items.isActive.equals(true));

      if (scope == 'category' && categoryId != null) {
        itemQuery.where(_db.items.categoryId.equals(categoryId));
      }

      final itemRows = await itemQuery.get();

      if (scope == 'recent') {
        // Only include items that have had stock movements in the last 90 days.
        final cutoff = DateTime.now().subtract(const Duration(days: 90));
        final recentItemIds = <int>{};
        final movementQuery = _db.selectOnly(_db.stockMovements)
          ..addColumns([_db.stockMovements.itemId])
          ..where(_db.stockMovements.createdAt.isBiggerOrEqualValue(cutoff))
          ..groupBy([_db.stockMovements.itemId]);
        final movementRows = await movementQuery.get();
        for (final row in movementRows) {
          final id = row.read(_db.stockMovements.itemId);
          if (id != null) recentItemIds.add(id);
        }
        itemRows.removeWhere((row) {
          final item = row.readTable(_db.items);
          return !recentItemIds.contains(item.id);
        });
      }

      if (itemRows.isEmpty) {
        throw const BusinessRuleException(AppStrings.noItemsToCount);
      }

      // 2. Get on-hand stock for all items.
      final stockMap = await _stockService.onHandMap();

      // 3. Create the stock count header.
      final countNumber = await _nextCountNumber();
      final countId = await _db.into(_db.stockCounts).insert(
            StockCountsCompanion.insert(
              countNumber: countNumber,
              scope: scope,
              notes: Value(notes),
            ),
          );

      // 4. Insert lines with system quantities.
      for (final row in itemRows) {
        final item = row.readTable(_db.items);
        final systemQty = stockMap[item.id] ?? 0.0;

        await _db.into(_db.stockCountLines).insert(
              StockCountLinesCompanion.insert(
                stockCountId: countId,
                itemId: item.id,
                systemQty: systemQty,
              ),
            );
      }

      return countId;
    });
  }

  @override
  Future<List<StockCountWithDetails>> getStockCounts({String? search}) async {
    final countQuery = _db.select(_db.stockCounts)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    final counts = await countQuery.get();

    final result = <StockCountWithDetails>[];
    for (final count in counts) {
      // Filter by search.
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        final matchesNumber = count.countNumber.toString().contains(q);
        final matchesNotes =
            count.notes?.toLowerCase().contains(q) ?? false;
        if (!matchesNumber && !matchesNotes) continue;
      }

      final lines = await _getCountLines(count.id);
      result.add(StockCountWithDetails(stockCount: count, lines: lines));
    }

    return result;
  }

  @override
  Future<StockCountWithDetails?> getStockCountById(int id) async {
    final count = await (_db.select(_db.stockCounts)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (count == null) return null;

    final lines = await _getCountLines(count.id);
    return StockCountWithDetails(stockCount: count, lines: lines);
  }

  Future<List<StockCountLineEntry>> _getCountLines(int stockCountId) async {
    final lineQuery = _db.select(_db.stockCountLines).join([
      innerJoin(_db.items, _db.items.id.equalsExp(_db.stockCountLines.itemId)),
      innerJoin(
        _db.itemCategories,
        _db.itemCategories.id.equalsExp(_db.items.categoryId),
      ),
    ]);
    lineQuery.where(_db.stockCountLines.stockCountId.equals(stockCountId));
    lineQuery.orderBy([OrderingTerm.asc(_db.items.name)]);

    final rows = await lineQuery.get();
    return rows.map((row) {
      final line = row.readTable(_db.stockCountLines);
      final item = row.readTable(_db.items);
      final category = row.readTable(_db.itemCategories);

      return StockCountLineEntry(
        id: line.id,
        stockCountId: line.stockCountId,
        itemId: line.itemId,
        itemName: item.name,
        categoryName: category.name,
        unit: item.unit,
        systemQty: line.systemQty,
        costPrice: item.costPrice,
        countedQty: line.countedQty,
        difference: line.difference,
        notes: line.notes,
      );
    }).toList();
  }

  @override
  Future<void> updateCountedQty({
    required int lineId,
    required double countedQty,
    String? notes,
  }) async {
    // Get the line to compute difference.
    final line = await (_db.select(_db.stockCountLines)
          ..where((t) => t.id.equals(lineId)))
        .getSingle();

    final difference = countedQty - line.systemQty;

    await (_db.update(_db.stockCountLines)
          ..where((t) => t.id.equals(lineId)))
        .write(StockCountLinesCompanion(
      countedQty: Value(countedQty),
      difference: Value(difference),
      notes: Value(notes),
    ));
  }

  @override
  Future<void> finalizeStockCount(int stockCountId) async {
    return _db.transaction(() async {
      // 1. Verify the session is still a draft.
      final count = await (_db.select(_db.stockCounts)
            ..where((t) => t.id.equals(stockCountId)))
          .getSingle();

      if (count.status == StockCountStatus.finalized) {
        throw const BusinessRuleException(AppStrings.cannotFinalizeTwice);
      }

      // 2. Get all lines.
      final lines = await (_db.select(_db.stockCountLines)
            ..where((t) => t.stockCountId.equals(stockCountId)))
          .get();

      // 3. Record countDiff movements for each line with a non-zero difference.
      for (final line in lines) {
        final diff = line.difference ?? 0.0;
        if (diff == 0.0) continue;

        await _stockService.addMovement(
          StockMovementsCompanion.insert(
            itemId: line.itemId,
            movementType: StockMovementType.countDiff,
            qty: diff,
            refType: const Value('count'),
            refId: Value(stockCountId),
            notes: Value(
              'فرق جرد جلسة رقم ${count.countNumber}'
              '${line.notes != null ? " - ${line.notes}" : ""}',
            ),
          ),
          allowNegative: true, // Count differences can go negative.
        );
      }

      // 4. Mark session as finalized.
      await (_db.update(_db.stockCounts)
            ..where((t) => t.id.equals(stockCountId)))
          .write(StockCountsCompanion(
        status: const Value(StockCountStatus.finalized),
        finalizedAt: Value(DateTime.now()),
      ));
    });
  }

  @override
  Future<void> deleteStockCount(int stockCountId) async {
    return _db.transaction(() async {
      final count = await (_db.select(_db.stockCounts)
            ..where((t) => t.id.equals(stockCountId)))
          .getSingle();

      if (count.status == StockCountStatus.finalized) {
        throw const BusinessRuleException(
            AppStrings.cannotDeleteFinalizedCount);
      }

      // Delete lines first, then header.
      await (_db.delete(_db.stockCountLines)
            ..where((t) => t.stockCountId.equals(stockCountId)))
          .go();
      await (_db.delete(_db.stockCounts)
            ..where((t) => t.id.equals(stockCountId)))
          .go();
    });
  }

  @override
  Future<StockCountSummary> getStockCountSummary() async {
    final counts = await _db.select(_db.stockCounts).get();

    int draftCount = 0;
    int finalizedCount = 0;

    for (final c in counts) {
      if (c.status == StockCountStatus.draft) {
        draftCount++;
      } else {
        finalizedCount++;
      }
    }

    // Calculate total difference value from finalized sessions.
    int totalDiffValue = 0;
    for (final c in counts.where((c) => c.status == StockCountStatus.finalized)) {
      final lines = await (_db.select(_db.stockCountLines).join([
        innerJoin(_db.items, _db.items.id.equalsExp(_db.stockCountLines.itemId)),
      ])
            ..where(_db.stockCountLines.stockCountId.equals(c.id)))
          .get();

      for (final row in lines) {
        final line = row.readTable(_db.stockCountLines);
        final item = row.readTable(_db.items);
        final diff = line.difference ?? 0.0;
        totalDiffValue += (diff * item.costPrice / 100).round();
      }
    }

    return StockCountSummary(
      totalSessions: counts.length,
      draftSessions: draftCount,
      finalizedSessions: finalizedCount,
      totalDifferenceValuePiasters: totalDiffValue,
    );
  }
}
