import '../../../core/money/money.dart';

/// Aggregated metric summary for the invoices overview dashboard.
class InvoicesSummary {
  const InvoicesSummary({
    required this.totalSalesPiasters,
    required this.totalCollectedPiasters,
    required this.totalRemainingPiasters,
    required this.todaySalesPiasters,
    required this.todayInvoicesCount,
    required this.totalInvoicesCount,
  });

  final int totalSalesPiasters;
  final int totalCollectedPiasters;
  final int totalRemainingPiasters;
  final int todaySalesPiasters;
  final int todayInvoicesCount;
  final int totalInvoicesCount;

  String get formattedTotalSales => MoneyUtils.format(totalSalesPiasters, withCurrency: true);
  String get formattedTotalCollected => MoneyUtils.format(totalCollectedPiasters, withCurrency: true);
  String get formattedTotalRemaining => MoneyUtils.format(totalRemainingPiasters, withCurrency: true);
  String get formattedTodaySales => MoneyUtils.format(todaySalesPiasters, withCurrency: true);
}
