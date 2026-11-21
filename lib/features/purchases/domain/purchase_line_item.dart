import 'package:flutter/foundation.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/formatters.dart';

/// Single item line in a purchase invoice.
@immutable
class PurchaseLineItem {
  const PurchaseLineItem({
    required this.itemId,
    required this.itemName,
    this.itemSku,
    required this.itemUnit,
    required this.quantity,
    required this.unitCostPiasters,
    required this.totalAmountPiasters,
  });

  final int itemId;
  final String itemName;
  final String? itemSku;
  final String itemUnit;
  final double quantity;
  final int unitCostPiasters;
  final int totalAmountPiasters;

  String get formattedQuantity => Formatters.formatQty(quantity);
  String get formattedUnitCost => MoneyUtils.format(unitCostPiasters, withCurrency: true);
  String get formattedTotal => MoneyUtils.format(totalAmountPiasters, withCurrency: true);

  PurchaseLineItem copyWith({
    int? itemId,
    String? itemName,
    String? itemSku,
    String? itemUnit,
    double? quantity,
    int? unitCostPiasters,
    int? totalAmountPiasters,
  }) {
    return PurchaseLineItem(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      itemSku: itemSku ?? this.itemSku,
      itemUnit: itemUnit ?? this.itemUnit,
      quantity: quantity ?? this.quantity,
      unitCostPiasters: unitCostPiasters ?? this.unitCostPiasters,
      totalAmountPiasters: totalAmountPiasters ?? this.totalAmountPiasters,
    );
  }
}
