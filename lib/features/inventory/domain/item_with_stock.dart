import '../../../core/db/database.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/formatters.dart';

/// Item joined with category name and computed stock on hand.
class ItemWithStock {
  const ItemWithStock({
    required this.item,
    required this.categoryName,
    required this.stockOnHand,
  });

  final Item item;
  final String categoryName;
  final double stockOnHand;

  int get id => item.id;
  String get name => item.name;
  String? get sku => item.sku;
  String? get barcode => item.barcode;
  String get unit => item.unit;
  int get costPrice => item.costPrice;
  int get salePrice => item.salePrice;
  bool get isActive => item.isActive;
  String get formattedStock => Formatters.formatQty(stockOnHand);

  bool get isOutOfStock => stockOnHand <= 0;
  bool get isLowStock => !isOutOfStock && item.minQuantity > 0 && stockOnHand <= item.minQuantity;
  bool get isPlentiful => !isOutOfStock && !isLowStock;

  int get stockValueCost => (stockOnHand * item.costPrice).round();
  int get stockValueSale => (stockOnHand * item.salePrice).round();

  String get formattedCostPrice => MoneyUtils.formatPounds(item.costPrice);
  String get formattedSalePrice => MoneyUtils.formatPounds(item.salePrice);
  String get formattedStockValueCost => MoneyUtils.formatPounds(stockValueCost);
  String get formattedStockValueSale => MoneyUtils.formatPounds(stockValueSale);

  /// Profit margin percentage: ((salePrice - costPrice) / salePrice) * 100
  double get profitMarginPercentage {
    if (item.salePrice <= 0) return 0.0;
    final diff = item.salePrice - item.costPrice;
    return (diff / item.salePrice) * 100;
  }
}
