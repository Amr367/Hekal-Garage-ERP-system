import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/stock_count_line_entry.dart';
import '../../domain/stock_count_with_details.dart';
import '../stock_count_controller.dart';
import 'edit_stock_count_line_dialog.dart';

/// Detailed inspection pane for a selected stock count session.
class StockCountDetailsPane extends ConsumerStatefulWidget {
  const StockCountDetailsPane({
    super.key,
    required this.stockCount,
  });

  final StockCountWithDetails stockCount;

  @override
  ConsumerState<StockCountDetailsPane> createState() =>
      _StockCountDetailsPaneState();
}

class _StockCountDetailsPaneState extends ConsumerState<StockCountDetailsPane> {
  // Line filter: 'all', 'diff', 'uncounted'
  String _filter = 'all';

  List<StockCountLineEntry> get _filteredLines {
    switch (_filter) {
      case 'diff':
        return widget.stockCount.linesWithDifference;
      case 'uncounted':
        return widget.stockCount.lines.where((l) => !l.isCounted).toList();
      default:
        return widget.stockCount.lines;
    }
  }

  Future<void> _handleFinalize(BuildContext context) async {
    final count = widget.stockCount;
    if (count.remainingItems > 0) {
      final proceed = await ConfirmDialog.show(
        context: context,
        title: AppStrings.finalizeCountTitle,
        message: AppStrings.countHasUncountedItems,
        confirmLabel: 'متابعة الاعتماد',
        cancelLabel: AppStrings.cancel,
      );
      if (!proceed) return;
    }

    if (!context.mounted) return;
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: AppStrings.finalizeCountTitle,
      message: AppStrings.finalizeCountMessage,
      confirmLabel: AppStrings.finalizeCountConfirm,
      cancelLabel: AppStrings.finalizeCountCancel,
    );

    if (confirmed && context.mounted) {
      await ref
          .read(stockCountActionsProvider)
          .finalizeStockCount(context, count.id);
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await ConfirmDialog.destructive(
      context: context,
      title: AppStrings.deleteCountButton,
      message: 'هل أنت متأكد من حذف جلسة الجرد هذه؟ سيتم فقدان التعديلات.',
    );

    if (confirmed && context.mounted) {
      await ref
          .read(stockCountActionsProvider)
          .deleteStockCount(context, widget.stockCount.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.stockCount;
    final filteredLines = _filteredLines;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Header & Action Buttons ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  count.isDraft ? Icons.edit_note : Icons.check_circle_outline,
                  color: count.isDraft ? AppColors.warning : AppColors.success,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            'جلسة جرد #${count.countNumber}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (count.isDraft
                                      ? AppColors.warning
                                      : AppColors.success)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              count.statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: count.isDraft
                                    ? AppColors.warning
                                    : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${count.scopeLabel} • ${count.createdAt.toString().split('.')[0]}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Draft action buttons
                if (count.isDraft) ...<Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _handleDelete(context),
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.danger),
                    label: const Text(
                      AppStrings.delete,
                      style: TextStyle(color: AppColors.danger),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _handleFinalize(context),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text(AppStrings.finalizeCountButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Close button
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'إغلاق التفاصيل',
                  onPressed: () {
                    ref
                        .read(selectedStockCountIdProvider.notifier)
                        .select(null);
                  },
                ),
              ],
            ),
          ),

          // ── Metrics Bar (Scrollable to prevent overflow) ────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surfaceVariant.withValues(alpha: 0.3),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _MetricItem(
                    label: AppStrings.countItemsTotal,
                    value: count.totalItems.toString(),
                    icon: Icons.list_alt,
                  ),
                  const SizedBox(width: 24),
                  _MetricItem(
                    label: AppStrings.countItemsCounted,
                    value: '${count.countedItems} / ${count.totalItems}',
                    icon: Icons.done_all,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 24),
                  _MetricItem(
                    label: AppStrings.countItemsRemaining,
                    value: count.remainingItems.toString(),
                    icon: Icons.pending_actions,
                    color: count.remainingItems > 0
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                  const SizedBox(width: 24),
                  _MetricItem(
                    label: AppStrings.kpiTotalDifference,
                    value: count.formattedTotalDifferenceValue,
                    icon: Icons.price_change_outlined,
                    color: count.totalDifferenceValuePiasters < 0
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ],
              ),
            ),
          ),

          // ── Filter Toolbar (Scrollable) ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  const Text(
                    'عرض الأصناف:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<String>(
                    segments: <ButtonSegment<String>>[
                      ButtonSegment(
                        value: 'all',
                        label: Text('الكل (${count.totalItems})'),
                      ),
                      ButtonSegment(
                        value: 'diff',
                        label: Text(
                            'الفروقات (${count.linesWithDifference.length})'),
                      ),
                      ButtonSegment(
                        value: 'uncounted',
                        label: Text('لم تُعد (${count.remainingItems})'),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (val) {
                      setState(() => _filter = val.first);
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Items Table ─────────────────────────────────────────────────────
          Expanded(
            child: filteredLines.isEmpty
                ? const EmptyState(
                    title: 'لا توجد أصناف مطابقة للفلتر المحدد',
                    icon: Icons.filter_list_off,
                  )
                : AppDataTable<StockCountLineEntry>(
                    minTableWidth: 760,
                    rowHeight: 64,
                    columns: <AppTableColumn<StockCountLineEntry>>[
                      AppTableColumn<StockCountLineEntry>(
                        title: AppStrings.columnItemName,
                        flex: 3,
                        cellBuilder: (_, line, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              line.itemName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              line.categoryName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppTableColumn<StockCountLineEntry>(
                        title: AppStrings.columnSystemQty,
                        width: 110,
                        cellBuilder: (_, line, _) => Text(
                          '${line.formattedSystemQty} ${line.unit}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      AppTableColumn<StockCountLineEntry>(
                        title: AppStrings.columnCountedQty,
                        width: 120,
                        cellBuilder: (_, line, _) => Text(
                          line.isCounted
                              ? '${line.formattedCountedQty} ${line.unit}'
                              : AppStrings.notCounted,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: line.isCounted
                                ? AppColors.onSurface
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      AppTableColumn<StockCountLineEntry>(
                        title: AppStrings.columnDifference,
                        width: 110,
                        cellBuilder: (_, line, _) {
                          if (line.difference == null) {
                            return const Text('-');
                          }
                          final diff = line.difference!;
                          final color = diff == 0
                              ? AppColors.onSurfaceVariant
                              : (diff < 0
                                  ? AppColors.danger
                                  : AppColors.success);
                          return Text(
                            '${diff > 0 ? "+" : ""}${line.formattedDifference} ${line.unit}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          );
                        },
                      ),
                      AppTableColumn<StockCountLineEntry>(
                        title: 'قيمة الفرق',
                        width: 120,
                        cellBuilder: (_, line, _) {
                          if (!line.isCounted || line.difference == 0) {
                            return const Text('-');
                          }
                          final val = line.differenceValuePiasters;
                          final color =
                              val < 0 ? AppColors.danger : AppColors.success;
                          return Text(
                            line.formattedDifferenceValue,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          );
                        },
                      ),
                      if (count.isDraft)
                        AppTableColumn<StockCountLineEntry>(
                          title: 'إجراء',
                          width: 80,
                          cellBuilder: (ctx, line, _) => IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: AppStrings.editCountedQtyButton,
                            color: AppColors.primary,
                            onPressed: () {
                              EditStockCountLineDialog.show(ctx, line);
                            },
                          ),
                        ),
                    ],
                    items: filteredLines,
                    onRowTap: count.isDraft
                        ? (line) =>
                            EditStockCountLineDialog.show(context, line)
                        : null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.onSurface;
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: effectiveColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
