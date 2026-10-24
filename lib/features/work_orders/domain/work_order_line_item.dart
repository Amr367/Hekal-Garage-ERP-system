import '../../../core/db/database.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/formatters.dart';

/// Represents a single line item within a work order (either a service/labor or warehouse spare part).
class WorkOrderLineItem {
  const WorkOrderLineItem({
    this.id,
    this.workOrderId,
    required this.lineType,
    this.serviceId,
    this.itemId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.itemUnit,
    this.stockOnHand,
  });

  final int? id;
  final int? workOrderId;
  final LineType lineType;
  final int? serviceId;
  final int? itemId;
  final String description;
  final double quantity;
  final int unitPrice; // in piasters
  final int totalPrice; // in piasters
  final String? itemUnit; // e.g. قطعة، لتر، طقم
  final double? stockOnHand; // Available stock in warehouse for parts

  bool get isService => lineType == LineType.service;
  bool get isPart => lineType == LineType.part;

  String get formattedUnitPrice => MoneyUtils.formatPounds(unitPrice);
  String get formattedTotalPrice => MoneyUtils.formatPounds(totalPrice);
  String get formattedQuantity => Formatters.formatQuantity(quantity);

  /// Creates a line from a Drift generated [WorkOrderLine] record.
  factory WorkOrderLineItem.fromDb(WorkOrderLine line, {String? unit, double? stock}) {
    return WorkOrderLineItem(
      id: line.id,
      workOrderId: line.workOrderId,
      lineType: line.lineType,
      serviceId: line.serviceId,
      itemId: line.itemId,
      description: line.description,
      quantity: line.quantity,
      unitPrice: line.unitPrice,
      totalPrice: line.totalPrice,
      itemUnit: unit,
      stockOnHand: stock,
    );
  }

  /// Calculates total price in piasters based on unit price and quantity.
  static int calculateTotal(int unitPricePiasters, double qty) {
    return (unitPricePiasters * qty).round();
  }

  WorkOrderLineItem copyWith({
    int? id,
    int? workOrderId,
    LineType? lineType,
    int? serviceId,
    int? itemId,
    String? description,
    double? quantity,
    int? unitPrice,
    int? totalPrice,
    String? itemUnit,
    double? stockOnHand,
  }) {
    return WorkOrderLineItem(
      id: id ?? this.id,
      workOrderId: workOrderId ?? this.workOrderId,
      lineType: lineType ?? this.lineType,
      serviceId: serviceId ?? this.serviceId,
      itemId: itemId ?? this.itemId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      itemUnit: itemUnit ?? this.itemUnit,
      stockOnHand: stockOnHand ?? this.stockOnHand,
    );
  }
}
