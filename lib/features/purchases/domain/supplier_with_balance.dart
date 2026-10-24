import 'package:flutter/foundation.dart';
import '../../../core/db/database.dart';
import '../../../core/money/money.dart';

/// Supplier aggregate with financial balance and invoices count.
@immutable
class SupplierWithBalance {
  const SupplierWithBalance({
    required this.supplier,
    required this.invoicesCount,
    required this.totalPurchasesPiasters,
    required this.totalPaidPiasters,
    required this.balanceDuePiasters,
  });

  final Supplier supplier;
  final int invoicesCount;
  final int totalPurchasesPiasters;
  final int totalPaidPiasters;
  final int balanceDuePiasters;

  int get id => supplier.id;
  String get name => supplier.name;
  String? get phone => supplier.phone;
  String? get notes => supplier.notes;
  bool get isActive => supplier.isActive;
  DateTime get createdAt => supplier.createdAt;

  String get formattedTotalPurchases =>
      MoneyUtils.formatPiasters(totalPurchasesPiasters);
  String get formattedTotalPaid =>
      MoneyUtils.formatPiasters(totalPaidPiasters);
  String get formattedBalanceDue =>
      MoneyUtils.formatPiasters(balanceDuePiasters);

  bool get hasDebt => balanceDuePiasters > 0;

  SupplierWithBalance copyWith({
    Supplier? supplier,
    int? invoicesCount,
    int? totalPurchasesPiasters,
    int? totalPaidPiasters,
    int? balanceDuePiasters,
  }) {
    return SupplierWithBalance(
      supplier: supplier ?? this.supplier,
      invoicesCount: invoicesCount ?? this.invoicesCount,
      totalPurchasesPiasters:
          totalPurchasesPiasters ?? this.totalPurchasesPiasters,
      totalPaidPiasters: totalPaidPiasters ?? this.totalPaidPiasters,
      balanceDuePiasters: balanceDuePiasters ?? this.balanceDuePiasters,
    );
  }
}
