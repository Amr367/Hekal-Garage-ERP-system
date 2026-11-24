import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/db/repositories/returns_repository.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/return_with_details.dart';
import '../domain/returns_summary.dart';

/// Search query notifier for filtering returns.
class ReturnsSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final returnsSearchQueryProvider =
    NotifierProvider<ReturnsSearchQueryNotifier, String>(
  ReturnsSearchQueryNotifier.new,
);

/// Return type filter notifier (null = all, saleReturn, purchaseReturn).
class ReturnsTypeFilterNotifier extends Notifier<ReturnType?> {
  @override
  ReturnType? build() => null;

  void setType(ReturnType? type) => state = type;
}

final returnsTypeFilterProvider =
    NotifierProvider<ReturnsTypeFilterNotifier, ReturnType?>(
  ReturnsTypeFilterNotifier.new,
);

/// Selected return ID notifier for master-detail pane.
class SelectedReturnIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedReturnIdProvider =
    NotifierProvider<SelectedReturnIdNotifier, int?>(
  SelectedReturnIdNotifier.new,
);

/// Summary KPI provider for returns.
final returnsSummaryProvider = FutureProvider<ReturnsSummary>((ref) async {
  final repo = ref.watch(returnsRepositoryProvider);
  return repo.getSummary();
});

/// Returns list provider with search query and return type filters.
final returnsListProvider =
    FutureProvider<List<ReturnWithDetails>>((ref) async {
  final repo = ref.watch(returnsRepositoryProvider);
  final query = ref.watch(returnsSearchQueryProvider);
  final type = ref.watch(returnsTypeFilterProvider);

  return repo.getAll(
    type: type,
    query: query,
  );
});

/// Selected return details provider.
final selectedReturnProvider =
    FutureProvider<ReturnWithDetails?>((ref) async {
  final selectedId = ref.watch(selectedReturnIdProvider);
  if (selectedId == null) return null;

  final repo = ref.watch(returnsRepositoryProvider);
  try {
    return await repo.getById(selectedId);
  } catch (_) {
    return null;
  }
});

/// Actions controller for creating and deleting returns.
class ReturnsActionsController {
  const ReturnsActionsController(this._ref);

  final Ref _ref;

  ReturnsRepository get _repo => _ref.read(returnsRepositoryProvider);

  Future<ReturnWithDetails> createSaleReturn({
    int? invoiceId,
    int? customerId,
    String? customerName,
    required PaymentMethod refundMethod,
    String? reason,
    required List<ReturnLineEntry> lines,
  }) async {
    final result = await _repo.createSaleReturn(
      invoiceId: invoiceId,
      customerId: customerId,
      customerName: customerName,
      refundMethod: refundMethod,
      reason: reason,
      lines: lines,
    );

    _invalidateAll();
    _ref.read(selectedReturnIdProvider.notifier).select(result.id);
    return result;
  }

  Future<ReturnWithDetails> createPurchaseReturn({
    int? purchaseInvoiceId,
    int? supplierId,
    String? supplierName,
    required PaymentMethod refundMethod,
    String? reason,
    required List<ReturnLineEntry> lines,
  }) async {
    final result = await _repo.createPurchaseReturn(
      purchaseInvoiceId: purchaseInvoiceId,
      supplierId: supplierId,
      supplierName: supplierName,
      refundMethod: refundMethod,
      reason: reason,
      lines: lines,
    );

    _invalidateAll();
    _ref.read(selectedReturnIdProvider.notifier).select(result.id);
    return result;
  }

  Future<void> deleteReturn(int id) async {
    await _repo.deleteReturn(id);
    _invalidateAll();

    final currentSelected = _ref.read(selectedReturnIdProvider);
    if (currentSelected == id) {
      _ref.read(selectedReturnIdProvider.notifier).select(null);
    }
  }

  void _invalidateAll() {
    _ref.invalidate(returnsListProvider);
    _ref.invalidate(returnsSummaryProvider);
    _ref.invalidate(selectedReturnProvider);
    // Invalidate inventory stock so numbers reflect warehouse return immediately
    _ref.invalidate(inventoryListProvider);
  }
}

final returnsActionsControllerProvider =
    Provider<ReturnsActionsController>((ref) {
  return ReturnsActionsController(ref);
});
