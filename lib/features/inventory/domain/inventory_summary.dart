import '../../../core/money/money.dart';

/// Aggregated inventory KPIs for dashboard and inventory summary cards.
class InventorySummary {
  const InventorySummary({
    required this.totalItemsCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalCostValue,
    required this.totalSaleValue,
  });

  final int totalItemsCount;
  final int lowStockCount;
  final int outOfStockCount;
  final int totalCostValue; // in piasters
  final int totalSaleValue; // in piasters

  String get formattedTotalCostValue => MoneyUtils.formatPounds(totalCostValue);
  String get formattedTotalSaleValue => MoneyUtils.formatPounds(totalSaleValue);

  /// Potential gross profit = totalSaleValue - totalCostValue
  int get potentialProfit => totalSaleValue - totalCostValue;
  String get formattedPotentialProfit => MoneyUtils.formatPounds(potentialProfit);
}
