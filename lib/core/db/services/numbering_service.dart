import '../database.dart';

/// Central domain service for assigning sequential document numbers without gaps or duplicates.
///
/// Complies with Domain Rule R6:
/// Numbers must be generated inside the same transaction that inserts the document.
class NumberingService {
  const NumberingService(this._db);

  final AppDatabase _db;

  /// Returns the next sequential invoice number.
  ///
  /// Must be invoked within the transaction inserting the [Invoice].
  Future<int> getNextInvoiceNumber() => _db.nextInvoiceNumber();

  /// Returns the next sequential work order number.
  ///
  /// Must be invoked within the transaction inserting the [WorkOrder].
  Future<int> getNextWorkOrderNumber() => _db.nextWorkOrderNumber();
}
