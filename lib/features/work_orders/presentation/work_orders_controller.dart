import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../domain/work_order_line_item.dart';
import '../domain/work_order_summary.dart';
import '../domain/work_order_with_details.dart';

/// Text search query notifier for filtering work orders.
class WorkOrderSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String val) => state = val;
}

final workOrderSearchQueryProvider =
    NotifierProvider<WorkOrderSearchQueryNotifier, String>(
  WorkOrderSearchQueryNotifier.new,
);

/// Active status filter notifier for work orders (null = show all).
class WorkOrderStatusFilterNotifier extends Notifier<WorkOrderStatus?> {
  @override
  WorkOrderStatus? build() => null;

  void set(WorkOrderStatus? val) => state = val;
}

final workOrderStatusFilterProvider =
    NotifierProvider<WorkOrderStatusFilterNotifier, WorkOrderStatus?>(
  WorkOrderStatusFilterNotifier.new,
);

/// Currently selected work order ID notifier for desktop master-detail pane.
class SelectedWorkOrderIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? id) => state = id;
}

final selectedWorkOrderIdProvider =
    NotifierProvider<SelectedWorkOrderIdNotifier, int?>(
  SelectedWorkOrderIdNotifier.new,
);

/// Fetches filtered list of work orders with customer and vehicle details.
final workOrdersListProvider = FutureProvider<List<WorkOrderWithDetails>>((ref) async {
  final repo = ref.watch(workOrdersRepositoryProvider);
  final query = ref.watch(workOrderSearchQueryProvider);
  final status = ref.watch(workOrderStatusFilterProvider);

  return repo.getWorkOrders(
    query: query,
    status: status,
  );
});

/// Fetches full details for the currently selected work order.
final selectedWorkOrderDetailsProvider = FutureProvider<WorkOrderWithDetails?>((ref) async {
  final selectedId = ref.watch(selectedWorkOrderIdProvider);
  if (selectedId == null) return null;

  final repo = ref.watch(workOrdersRepositoryProvider);
  try {
    return await repo.getWorkOrderById(selectedId);
  } catch (_) {
    return null;
  }
});

/// Fetches aggregated metrics for work orders KPI cards.
final workOrdersSummaryProvider = FutureProvider<WorkOrderSummary>((ref) async {
  final repo = ref.watch(workOrdersRepositoryProvider);
  return repo.getWorkOrderSummary();
});

/// Controller handling mutating operations on work orders.
final workOrdersActionsControllerProvider = Provider<WorkOrdersActionsController>((ref) {
  return WorkOrdersActionsController(ref);
});

class WorkOrdersActionsController {
  const WorkOrdersActionsController(this._ref);

  final Ref _ref;

  Future<WorkOrderWithDetails> createWorkOrder({
    required int customerId,
    required int vehicleId,
    int? odometer,
    String? complaint,
    String? mechanicName,
    String? notes,
    DateTime? entryDate,
    DateTime? expectedExitDate,
    List<WorkOrderLineItem> lines = const [],
  }) async {
    final repo = _ref.read(workOrdersRepositoryProvider);
    final created = await repo.createWorkOrder(
      customerId: customerId,
      vehicleId: vehicleId,
      odometer: odometer,
      complaint: complaint,
      mechanicName: mechanicName,
      notes: notes,
      entryDate: entryDate,
      expectedExitDate: expectedExitDate,
      lines: lines,
    );

    _ref.invalidate(workOrdersListProvider);
    _ref.invalidate(workOrdersSummaryProvider);
    _ref.read(selectedWorkOrderIdProvider.notifier).set(created.id);

    return created;
  }

  Future<WorkOrderWithDetails> updateWorkOrder({
    required int id,
    int? odometer,
    String? complaint,
    String? mechanicName,
    String? notes,
    DateTime? entryDate,
    DateTime? expectedExitDate,
    List<WorkOrderLineItem>? lines,
  }) async {
    final repo = _ref.read(workOrdersRepositoryProvider);
    final updated = await repo.updateWorkOrder(
      id: id,
      odometer: odometer,
      complaint: complaint,
      mechanicName: mechanicName,
      notes: notes,
      entryDate: entryDate,
      expectedExitDate: expectedExitDate,
      lines: lines,
    );

    _ref.invalidate(workOrdersListProvider);
    _ref.invalidate(selectedWorkOrderDetailsProvider);
    _ref.invalidate(workOrdersSummaryProvider);

    return updated;
  }

  Future<void> updateStatus({
    required int id,
    required WorkOrderStatus status,
    String? cancellationReason,
  }) async {
    final repo = _ref.read(workOrdersRepositoryProvider);
    await repo.updateStatus(
      id: id,
      status: status,
      cancellationReason: cancellationReason,
    );

    _ref.invalidate(workOrdersListProvider);
    _ref.invalidate(selectedWorkOrderDetailsProvider);
    _ref.invalidate(workOrdersSummaryProvider);
  }

  Future<WorkOrderWithDetails> deliverWorkOrder({
    required int id,
    required PaymentMethod paymentMethod,
    int? paidAmountPiasters,
    int? discountAmountPiasters,
    String? paymentReference,
    String? deliveryNotes,
  }) async {
    final repo = _ref.read(workOrdersRepositoryProvider);
    final delivered = await repo.deliverWorkOrder(
      id: id,
      paymentMethod: paymentMethod,
      paidAmountPiasters: paidAmountPiasters,
      discountAmountPiasters: discountAmountPiasters,
      paymentReference: paymentReference,
      deliveryNotes: deliveryNotes,
    );

    _ref.invalidate(workOrdersListProvider);
    _ref.invalidate(selectedWorkOrderDetailsProvider);
    _ref.invalidate(workOrdersSummaryProvider);

    return delivered;
  }

  Future<void> deleteWorkOrder(int id) async {
    final repo = _ref.read(workOrdersRepositoryProvider);
    await repo.deleteWorkOrder(id);

    if (_ref.read(selectedWorkOrderIdProvider) == id) {
      _ref.read(selectedWorkOrderIdProvider.notifier).set(null);
    }

    _ref.invalidate(workOrdersListProvider);
    _ref.invalidate(selectedWorkOrderDetailsProvider);
    _ref.invalidate(workOrdersSummaryProvider);
  }
}
