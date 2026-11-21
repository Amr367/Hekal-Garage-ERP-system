import '../../../core/money/money.dart';
import '../../../core/strings.dart';
import '../../../core/utils/formatters.dart';

/// Single line in a stock count session, combining item metadata with
/// system-reported and physically counted quantities.
class StockCountLineEntry {
  const StockCountLineEntry({
    required this.id,
    required this.stockCountId,
    required this.itemId,
    required this.itemName,
    required this.categoryName,
    required this.unit,
    required this.systemQty,
    required this.costPrice,
    this.countedQty,
    this.difference,
    this.notes,
  });

  final int id;
  final int stockCountId;
  final int itemId;
  final String itemName;
  final String categoryName;
  final String unit;
  final double systemQty;
  final int costPrice; // piasters
  final double? countedQty;
  final double? difference;
  final String? notes;

  /// Whether this line has been physically counted.
  bool get isCounted => countedQty != null;

  /// Formatted system quantity without trailing zeros.
  String get formattedSystemQty => Formatters.formatQty(systemQty);

  /// Formatted counted quantity, or placeholder text if not yet counted.
  String get formattedCountedQty =>
      countedQty != null ? Formatters.formatQty(countedQty!) : AppStrings.notCounted;

  /// Formatted difference quantity.
  String get formattedDifference =>
      difference != null ? Formatters.formatQty(difference!) : '-';

  /// Difference value in piasters (difference × costPrice).
  int get differenceValuePiasters =>
      difference != null ? (difference! * costPrice / 100).round() : 0;

  /// Formatted difference value.
  String get formattedDifferenceValue =>
      MoneyUtils.format(differenceValuePiasters, withCurrency: true);
}
