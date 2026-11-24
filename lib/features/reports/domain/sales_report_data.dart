import '../../../core/db/database.dart';
import '../../../core/money/money.dart';

/// Single invoice item in the sales report list.
class SalesReportInvoiceRow {
  const SalesReportInvoiceRow({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.date,
    required this.customerName,
    required this.plateNumber,
    required this.totalAmountPiasters,
    required this.paidAmountPiasters,
    required this.paymentMethod,
    required this.status,
  });

  final int invoiceId;
  final int invoiceNumber;
  final DateTime date;
  final String customerName;
  final String plateNumber;
  final int totalAmountPiasters;
  final int paidAmountPiasters;
  final PaymentMethod paymentMethod;
  final InvoiceStatus status;

  int get remainingPiasters => totalAmountPiasters - paidAmountPiasters;

  String get formattedTotal => MoneyUtils.format(totalAmountPiasters, withCurrency: true);
  String get formattedPaid => MoneyUtils.format(paidAmountPiasters, withCurrency: true);
  String get formattedRemaining => MoneyUtils.format(remainingPiasters, withCurrency: true);

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case PaymentMethod.cash:
        return 'خزنة / كاش';
      case PaymentMethod.wallet:
        return 'محفظة إلكترونية';
      case PaymentMethod.instapay:
        return 'انستاباي (InstaPay)';
      case PaymentMethod.card:
        return 'فيزا / كارت';
      case PaymentMethod.transfer:
        return 'تحويل بنكي';
    }
  }
}

/// Aggregated sales and revenues data for a given date range.
class SalesReportData {
  const SalesReportData({
    required this.totalInvoices,
    required this.partsRevenuePiasters,
    required this.servicesRevenuePiasters,
    required this.totalRevenuePiasters,
    required this.partsCostPiasters,
    required this.grossProfitPiasters,
    required this.totalPaidPiasters,
    required this.totalRemainingPiasters,
    required this.paymentBreakdown,
    required this.invoices,
    this.operatingExpensesPiasters = 0,
    this.salariesPaidPiasters = 0,
    this.salesReturnsPiasters = 0,
    this.purchaseReturnsPiasters = 0,
    this.salesReturnsCount = 0,
    this.purchaseReturnsCount = 0,
  });

  final int totalInvoices;
  final int partsRevenuePiasters;
  final int servicesRevenuePiasters;
  final int totalRevenuePiasters;
  final int partsCostPiasters;
  final int grossProfitPiasters;
  final int totalPaidPiasters;
  final int totalRemainingPiasters;
  final Map<PaymentMethod, int> paymentBreakdown;
  final List<SalesReportInvoiceRow> invoices;
  final int operatingExpensesPiasters;
  final int salariesPaidPiasters;
  final int salesReturnsPiasters;
  final int purchaseReturnsPiasters;
  final int salesReturnsCount;
  final int purchaseReturnsCount;

  int get netRevenuePiasters => totalRevenuePiasters - salesReturnsPiasters;
  int get totalExpensesAndSalariesPiasters =>
      operatingExpensesPiasters + salariesPaidPiasters;
  int get netOperatingProfitPiasters =>
      (grossProfitPiasters - salesReturnsPiasters) - totalExpensesAndSalariesPiasters;

  /// Formatted money getters
  String get formattedTotalRevenue => MoneyUtils.format(totalRevenuePiasters, withCurrency: true);
  String get formattedNetRevenue => MoneyUtils.format(netRevenuePiasters, withCurrency: true);
  String get formattedSalesReturns => MoneyUtils.format(salesReturnsPiasters, withCurrency: true);
  String get formattedPurchaseReturns => MoneyUtils.format(purchaseReturnsPiasters, withCurrency: true);
  String get formattedPartsRevenue => MoneyUtils.format(partsRevenuePiasters, withCurrency: true);
  String get formattedServicesRevenue => MoneyUtils.format(servicesRevenuePiasters, withCurrency: true);
  String get formattedPartsCost => MoneyUtils.format(partsCostPiasters, withCurrency: true);
  String get formattedGrossProfit => MoneyUtils.format(grossProfitPiasters, withCurrency: true);
  String get formattedOperatingExpenses => MoneyUtils.format(operatingExpensesPiasters, withCurrency: true);
  String get formattedSalariesPaid => MoneyUtils.format(salariesPaidPiasters, withCurrency: true);
  String get formattedTotalExpensesAndSalaries => MoneyUtils.format(totalExpensesAndSalariesPiasters, withCurrency: true);
  String get formattedNetOperatingProfit => MoneyUtils.format(netOperatingProfitPiasters, withCurrency: true);
  String get formattedTotalPaid => MoneyUtils.format(totalPaidPiasters, withCurrency: true);
  String get formattedTotalRemaining => MoneyUtils.format(totalRemainingPiasters, withCurrency: true);

  /// Gross profit margin percentage (grossProfit / totalRevenue * 100).
  double get profitMarginPercent {
    if (totalRevenuePiasters <= 0) return 0.0;
    return (grossProfitPiasters / totalRevenuePiasters) * 100.0;
  }

  String get formattedProfitMargin => '${profitMarginPercent.toStringAsFixed(1)}%';

  /// Net operating profit margin percentage (netOperatingProfit / totalRevenue * 100).
  double get netProfitMarginPercent {
    if (totalRevenuePiasters <= 0) return 0.0;
    return (netOperatingProfitPiasters / totalRevenuePiasters) * 100.0;
  }

  String get formattedNetProfitMargin => '${netProfitMarginPercent.toStringAsFixed(1)}%';

  /// Payment method amounts
  int amountFor(PaymentMethod method) => paymentBreakdown[method] ?? 0;
  String formattedAmountFor(PaymentMethod method) =>
      MoneyUtils.format(amountFor(method), withCurrency: true);
}
