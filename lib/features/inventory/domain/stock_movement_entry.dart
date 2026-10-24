import '../../../core/db/database.dart';
import '../../../core/money/money.dart';
import '../../../core/strings.dart';
import '../../../core/utils/formatters.dart';

/// Represents a single movement in an item's stock card (كارت الحركة)
/// with the computed cumulative running balance immediately following this movement.
class StockMovementEntry {
  const StockMovementEntry({
    required this.movement,
    required this.balanceAfter,
  });

  final StockMovement movement;
  final double balanceAfter;

  bool get isPositive => movement.qty > 0;
  bool get isNegative => movement.qty < 0;

  String get typeLabel {
    return switch (movement.movementType) {
      StockMovementType.opening => AppStrings.movementTypeOpening,
      StockMovementType.purchaseIn => AppStrings.movementTypePurchase,
      StockMovementType.saleOut => AppStrings.movementTypeSale,
      StockMovementType.saleReturn => AppStrings.movementTypeReturn,
      StockMovementType.adjustment => AppStrings.movementTypeAdjustment,
      StockMovementType.countDiff => AppStrings.movementTypeCount,
    };
  }

  String get formattedQty {
    final prefix = movement.qty > 0 ? '+' : '';
    return '$prefix${Formatters.formatQuantity(movement.qty)}';
  }

  String get formattedBalanceAfter => Formatters.formatQuantity(balanceAfter);

  String get formattedUnitCost {
    final cost = movement.unitCost;
    if (cost == null) return '-';
    return MoneyUtils.formatPounds(cost);
  }

  String get formattedDate {
    final d = movement.createdAt;
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $h:$min';
  }
}
