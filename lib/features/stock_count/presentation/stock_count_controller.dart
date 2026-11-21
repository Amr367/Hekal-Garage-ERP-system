import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/db/repositories/stock_count_repository.dart';
import '../../../core/strings.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/stock_count_summary.dart';
import '../domain/stock_count_with_details.dart';

// ── Search & Selection ────────────────────────────────────────────────

/// Search query state for filtering stock count sessions.
class StockCountSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
  void clear() => state = '';
}

final stockCountSearchQueryProvider =
    NotifierProvider<StockCountSearchQueryNotifier, String>(
  StockCountSearchQueryNotifier.new,
);

/// Selected stock count session ID for master-detail view.
class SelectedStockCountIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedStockCountIdProvider =
    NotifierProvider<SelectedStockCountIdNotifier, int?>(
  SelectedStockCountIdNotifier.new,
);

// ── Lists & Details ────────────────────────────────────────────────────

/// Provides the full list of stock count sessions, filtered by search query.
final stockCountsListProvider =
    FutureProvider.autoDispose<List<StockCountWithDetails>>((ref) async {
  final repo = ref.watch(stockCountRepositoryProvider);
  final search = ref.watch(stockCountSearchQueryProvider);
  return repo.getStockCounts(search: search.isEmpty ? null : search);
});

/// Provides KPI summary metrics for stock count dashboard.
final stockCountSummaryProvider =
    FutureProvider.autoDispose<StockCountSummary>((ref) async {
  final repo = ref.watch(stockCountRepositoryProvider);
  return repo.getStockCountSummary();
});

/// Provides details for the selected stock count session.
final selectedStockCountProvider =
    FutureProvider.autoDispose<StockCountWithDetails?>((ref) async {
  final id = ref.watch(selectedStockCountIdProvider);
  if (id == null) return null;
  final repo = ref.watch(stockCountRepositoryProvider);
  return repo.getStockCountById(id);
});

// ── Actions Controller ─────────────────────────────────────────────────

/// Controller for stock count actions (create, update line, finalize, delete).
class StockCountActionsController {
  const StockCountActionsController(this._ref);

  final Ref _ref;

  StockCountRepository get _repo =>
      _ref.read(stockCountRepositoryProvider);

  void _invalidate() {
    _ref.invalidate(stockCountsListProvider);
    _ref.invalidate(stockCountSummaryProvider);
    _ref.invalidate(selectedStockCountProvider);
  }

  /// Creates a new stock count session.
  Future<int?> createStockCount(
    BuildContext context, {
    required String scope,
    int? categoryId,
    String? notes,
  }) async {
    try {
      final id = await _repo.createStockCount(
        scope: scope,
        categoryId: categoryId,
        notes: notes,
      );
      _invalidate();
      _ref.read(selectedStockCountIdProvider.notifier).select(id);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, AppStrings.operationSuccess);
      }
      return id;
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, e.toString());
      }
      return null;
    }
  }

  /// Updates the counted quantity for a line item.
  Future<bool> updateCountedQty(
    BuildContext context, {
    required int lineId,
    required double countedQty,
    String? notes,
  }) async {
    try {
      await _repo.updateCountedQty(
        lineId: lineId,
        countedQty: countedQty,
        notes: notes,
      );
      _invalidate();
      if (context.mounted) {
        AppSnackbar.showSuccess(context, AppStrings.operationSuccess);
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, e.toString());
      }
      return false;
    }
  }

  /// Finalizes a stock count session, recording all count differences.
  Future<bool> finalizeStockCount(BuildContext context, int id) async {
    try {
      await _repo.finalizeStockCount(id);
      _invalidate();
      if (context.mounted) {
        AppSnackbar.showSuccess(context, AppStrings.countFinalized);
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, e.toString());
      }
      return false;
    }
  }

  /// Deletes a draft stock count session.
  Future<bool> deleteStockCount(BuildContext context, int id) async {
    try {
      await _repo.deleteStockCount(id);
      _invalidate();
      _ref.read(selectedStockCountIdProvider.notifier).select(null);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, AppStrings.countDeleted);
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, e.toString());
      }
      return false;
    }
  }
}

final stockCountActionsProvider = Provider<StockCountActionsController>(
  (ref) => StockCountActionsController(ref),
);
