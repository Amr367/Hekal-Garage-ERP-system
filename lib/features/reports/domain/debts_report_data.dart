import '../../../core/money/money.dart';

class CustomerDebtRow {
  const CustomerDebtRow({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.balancePiasters,
    required this.lastVisit,
  });

  final int customerId;
  final String name;
  final String phone;
  final int balancePiasters; // Positive means customer owes money
  final DateTime? lastVisit;

  String get formattedBalance => MoneyUtils.format(balancePiasters, withCurrency: true);
}

class SupplierDebtRow {
  const SupplierDebtRow({
    required this.supplierId,
    required this.name,
    required this.phone,
    required this.balancePiasters,
    required this.totalInvoicesCount,
  });

  final int supplierId;
  final String name;
  final String phone;
  final int balancePiasters; // Positive means we owe supplier money
  final int totalInvoicesCount;

  String get formattedBalance => MoneyUtils.format(balancePiasters, withCurrency: true);
}

class DebtsReportData {
  const DebtsReportData({
    required this.totalCustomersDebtPiasters,
    required this.totalSuppliersDebtPiasters,
    required this.customersCountWithDebt,
    required this.suppliersCountWithDebt,
    required this.customerDebts,
    required this.supplierDebts,
  });

  final int totalCustomersDebtPiasters;
  final int totalSuppliersDebtPiasters;
  final int customersCountWithDebt;
  final int suppliersCountWithDebt;
  final List<CustomerDebtRow> customerDebts;
  final List<SupplierDebtRow> supplierDebts;

  String get formattedTotalCustomersDebt =>
      MoneyUtils.format(totalCustomersDebtPiasters, withCurrency: true);
  String get formattedTotalSuppliersDebt =>
      MoneyUtils.format(totalSuppliersDebtPiasters, withCurrency: true);
}
