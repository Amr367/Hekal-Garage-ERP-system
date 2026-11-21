import '../../../core/db/database.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/formatters.dart';

/// Single line entry in an invoice, representing either a labor service or a spare part.
class InvoiceLineEntry {
  const InvoiceLineEntry({
    this.id,
    this.invoiceId,
    required this.lineType,
    this.serviceId,
    this.itemId,
    required this.description,
    required this.quantity,
    required this.unitPricePiasters,
    this.unitCostPiasters = 0,
    required this.totalPricePiasters,
  });

  final int? id;
  final int? invoiceId;
  final LineType lineType;
  final int? serviceId;
  final int? itemId;
  final String description;
  final double quantity;
  final int unitPricePiasters;
  final int unitCostPiasters;
  final int totalPricePiasters;

  bool get isService => lineType == LineType.service;
  bool get isPart => lineType == LineType.part;

  String get formattedQuantity => Formatters.formatQty(quantity);
  String get formattedUnitPrice => MoneyUtils.format(unitPricePiasters, withCurrency: true);
  String get formattedTotalPrice => MoneyUtils.format(totalPricePiasters, withCurrency: true);
}
