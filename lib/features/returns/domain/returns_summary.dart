import '../../../core/printing/money_format.dart';

class ReturnsSummary {
  const ReturnsSummary({
    required this.totalReturnsCount,
    required this.totalSalesReturnsCount,
    required this.totalPurchaseReturnsCount,
    required this.totalSalesReturnsAmount,
    required this.totalPurchaseReturnsAmount,
  });

  final int totalReturnsCount;
  final int totalSalesReturnsCount;
  final int totalPurchaseReturnsCount;
  final int totalSalesReturnsAmount; // in piasters
  final int totalPurchaseReturnsAmount; // in piasters

  int get totalCount => totalReturnsCount;
  int get netRefundsAmount => totalSalesReturnsAmount;

  String get formattedTotalSalesReturns =>
      MoneyFormat.formatWithCurrency(totalSalesReturnsAmount);
  String get formattedTotalPurchaseReturns =>
      MoneyFormat.formatWithCurrency(totalPurchaseReturnsAmount);

  static const ReturnsSummary zero = ReturnsSummary(
    totalReturnsCount: 0,
    totalSalesReturnsCount: 0,
    totalPurchaseReturnsCount: 0,
    totalSalesReturnsAmount: 0,
    totalPurchaseReturnsAmount: 0,
  );
}
