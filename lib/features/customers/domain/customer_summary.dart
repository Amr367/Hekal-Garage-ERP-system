import '../../../core/db/database.dart';
import '../../../core/money/money.dart';

/// Aggregated summary for a customer displayed in tables and summaries.
class CustomerSummary {
  const CustomerSummary({
    required this.customer,
    required this.vehiclesCount,
    required this.balance,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.invoicesCount,
    required this.workOrdersCount,
  });

  final Customer customer;
  final int vehiclesCount;

  /// Net balance in piasters (totalInvoiced - totalPaid).
  /// Positive value means the customer owes money.
  /// Zero means the account is settled.
  /// Negative value means the customer has credit.
  final int balance;

  /// Total amount of all issued invoices in piasters.
  final int totalInvoiced;

  /// Total amount paid across all invoices in piasters.
  final int totalPaid;

  /// Total number of invoices issued for this customer.
  final int invoicesCount;

  /// Total number of work orders recorded for this customer.
  final int workOrdersCount;

  bool get hasDebt => balance > 0;
  bool get isSettled => balance == 0;
  bool get hasCredit => balance < 0;

  String get formattedBalance => MoneyUtils.formatPounds(balance);
  String get formattedTotalInvoiced => MoneyUtils.formatPounds(totalInvoiced);
  String get formattedTotalPaid => MoneyUtils.formatPounds(totalPaid);
}
