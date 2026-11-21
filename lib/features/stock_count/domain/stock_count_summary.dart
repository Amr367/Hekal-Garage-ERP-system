import '../../../core/money/money.dart';

/// Aggregate summary metrics for the stock count dashboard KPI cards.
class StockCountSummary {
  const StockCountSummary({
    required this.totalSessions,
    required this.draftSessions,
    required this.finalizedSessions,
    required this.totalDifferenceValuePiasters,
  });

  final int totalSessions;
  final int draftSessions;
  final int finalizedSessions;
  final int totalDifferenceValuePiasters;

  /// Formatted total difference value.
  String get formattedDifferenceValue =>
      MoneyUtils.format(totalDifferenceValuePiasters, withCurrency: true);
}
