import 'package:flutter/foundation.dart';
import '../../../core/money/money.dart';

/// KPI Summary metrics for Purchases and Suppliers.
@immutable
class PurchasesSummary {
  const PurchasesSummary({
    required this.totalPurchasesPiasters,
    required this.totalSuppliersDebtPiasters,
    required this.activeSuppliersCount,
    required this.thisMonthPurchasesPiasters,
  });

  final int totalPurchasesPiasters;
  final int totalSuppliersDebtPiasters;
  final int activeSuppliersCount;
  final int thisMonthPurchasesPiasters;

  String get formattedTotalPurchases =>
      MoneyUtils.format(totalPurchasesPiasters, withCurrency: true);
  String get formattedTotalDebt =>
      MoneyUtils.format(totalSuppliersDebtPiasters, withCurrency: true);
  String get formattedThisMonthPurchases =>
      MoneyUtils.format(thisMonthPurchasesPiasters, withCurrency: true);
}
