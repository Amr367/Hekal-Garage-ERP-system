import '../../../core/money/money.dart';

/// Aggregated metrics for work orders shown in desktop KPI cards.
class WorkOrderSummary {
  const WorkOrderSummary({
    required this.openOrdersCount,
    required this.inProgressOrdersCount,
    required this.readyOrdersCount,
    required this.todayOrdersCount,
    required this.estimatedOpenValuePiasters,
  });

  final int openOrdersCount;
  final int inProgressOrdersCount;
  final int readyOrdersCount;
  final int todayOrdersCount;
  final int estimatedOpenValuePiasters;

  /// Total count of orders currently requiring workshop attention (open + in progress).
  int get activeWorkshopCount => openOrdersCount + inProgressOrdersCount;

  String get formattedEstimatedOpenValue =>
      MoneyUtils.formatPounds(estimatedOpenValuePiasters);

  factory WorkOrderSummary.empty() {
    return const WorkOrderSummary(
      openOrdersCount: 0,
      inProgressOrdersCount: 0,
      readyOrdersCount: 0,
      todayOrdersCount: 0,
      estimatedOpenValuePiasters: 0,
    );
  }
}
