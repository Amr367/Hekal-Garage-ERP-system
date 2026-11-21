import '../../../core/money/money.dart';
import '../../../core/utils/formatters.dart';

class InventoryReportItemRow {
  const InventoryReportItemRow({
    required this.itemId,
    required this.name,
    required this.categoryName,
    required this.sku,
    required this.unit,
    required this.quantityOnHand,
    required this.costPricePiasters,
    required this.salePricePiasters,
    required this.minQuantity,
  });

  final int itemId;
  final String name;
  final String categoryName;
  final String? sku;
  final String unit;
  final double quantityOnHand;
  final int costPricePiasters;
  final int salePricePiasters;
  final double minQuantity;

  int get totalCostValuePiasters => (quantityOnHand * costPricePiasters).round();
  int get totalSaleValuePiasters => (quantityOnHand * salePricePiasters).round();

  bool get isLowStock => quantityOnHand > 0 && quantityOnHand <= minQuantity;
  bool get isOutOfStock => quantityOnHand <= 0;

  String get formattedQty => Formatters.formatQty(quantityOnHand);
  String get formattedCostPrice => MoneyUtils.format(costPricePiasters, withCurrency: true);
  String get formattedSalePrice => MoneyUtils.format(salePricePiasters, withCurrency: true);
  String get formattedTotalCostValue => MoneyUtils.format(totalCostValuePiasters, withCurrency: true);
  String get formattedTotalSaleValue => MoneyUtils.format(totalSaleValuePiasters, withCurrency: true);
}

class TopMovingItemRow {
  const TopMovingItemRow({
    required this.itemId,
    required this.name,
    required this.categoryName,
    required this.totalSoldQty,
    required this.totalRevenuePiasters,
  });

  final int itemId;
  final String name;
  final String categoryName;
  final double totalSoldQty;
  final int totalRevenuePiasters;

  String get formattedQty => Formatters.formatQty(totalSoldQty);
  String get formattedRevenue => MoneyUtils.format(totalRevenuePiasters, withCurrency: true);
}

class InventoryReportData {
  const InventoryReportData({
    required this.totalItemsCount,
    required this.totalQuantityOnHand,
    required this.totalValuationCostPiasters,
    required this.totalValuationSalePiasters,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.topMovingItems,
    required this.stagnantItems,
    required this.items,
  });

  final int totalItemsCount;
  final double totalQuantityOnHand;
  final int totalValuationCostPiasters;
  final int totalValuationSalePiasters;
  final int lowStockCount;
  final int outOfStockCount;
  final List<TopMovingItemRow> topMovingItems;
  final List<InventoryReportItemRow> stagnantItems;
  final List<InventoryReportItemRow> items;

  int get potentialProfitPiasters =>
      totalValuationSalePiasters - totalValuationCostPiasters;

  String get formattedTotalQty => Formatters.formatQty(totalQuantityOnHand);
  String get formattedValuationCost => MoneyUtils.format(totalValuationCostPiasters, withCurrency: true);
  String get formattedValuationSale => MoneyUtils.format(totalValuationSalePiasters, withCurrency: true);
  String get formattedPotentialProfit => MoneyUtils.format(potentialProfitPiasters, withCurrency: true);
}
