import '../../../core/db/database.dart';
import '../../../core/money/money.dart';
import '../../../core/strings.dart';
import 'stock_count_line_entry.dart';

/// Complete aggregate model for a stock count session, including header
/// metadata and all constituent line entries.
class StockCountWithDetails {
  const StockCountWithDetails({
    required this.stockCount,
    required this.lines,
  });

  final StockCount stockCount;
  final List<StockCountLineEntry> lines;

  // ── Convenience Getters ──────────────────────────────────────────────

  int get id => stockCount.id;
  int get countNumber => stockCount.countNumber;
  String get scope => stockCount.scope;
  StockCountStatus get status => stockCount.status;
  String? get notes => stockCount.notes;
  DateTime get createdAt => stockCount.createdAt;
  DateTime? get finalizedAt => stockCount.finalizedAt;

  bool get isDraft => status == StockCountStatus.draft;
  bool get isFinalized => status == StockCountStatus.finalized;

  /// Human-readable scope name.
  String get scopeLabel {
    switch (scope) {
      case 'all':
        return AppStrings.scopeAll;
      case 'category':
        return AppStrings.scopeCategory;
      case 'recent':
        return AppStrings.scopeRecent;
      default:
        return scope;
    }
  }

  /// Human-readable status label.
  String get statusLabel =>
      isDraft ? AppStrings.countStatusDraft : AppStrings.countStatusFinalized;

  /// Total number of items in this count session.
  int get totalItems => lines.length;

  /// Number of items that have been physically counted.
  int get countedItems => lines.where((l) => l.isCounted).length;

  /// Number of items still awaiting count.
  int get remainingItems => totalItems - countedItems;

  /// Lines that have a non-zero difference.
  List<StockCountLineEntry> get linesWithDifference =>
      lines.where((l) => l.difference != null && l.difference != 0).toList();

  /// Total difference value in piasters across all lines.
  int get totalDifferenceValuePiasters =>
      lines.fold(0, (sum, l) => sum + l.differenceValuePiasters);

  /// Formatted total difference value.
  String get formattedTotalDifferenceValue =>
      MoneyUtils.format(totalDifferenceValuePiasters, withCurrency: true);
}
