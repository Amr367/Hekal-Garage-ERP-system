import 'package:flutter/material.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import 'state_views.dart';

/// Specification for a single column in [AppDataTable].
class AppTableColumn<T> {
  const AppTableColumn({
    required this.title,
    required this.cellBuilder,
    this.width,
    this.flex = 1,
    this.alignment = Alignment.centerRight,
    this.sortable = false,
  });

  final String title;
  final Widget Function(BuildContext context, T item, int index) cellBuilder;
  final double? width;
  final int flex;
  final Alignment alignment;
  final bool sortable;
}

/// High-performance desktop data table.
/// Uses [ListView.builder] for row virtualization so 10,000 rows render smoothly.
class AppDataTable<T> extends StatefulWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.items,
    this.isLoading = false,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
    this.onRowTap,
    this.emptyWidget,
    this.minTableWidth = 800,
    this.rowHeight = 48,
    this.headerHeight = 46,
  });

  final List<AppTableColumn<T>> columns;
  final List<T> items;
  final bool isLoading;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex, bool ascending)? onSort;
  final ValueChanged<T>? onRowTap;
  final Widget? emptyWidget;
  final double minTableWidth;
  final double rowHeight;
  final double headerHeight;

  @override
  State<AppDataTable<T>> createState() => _AppDataTableState<T>();
}

class _AppDataTableState<T> extends State<AppDataTable<T>> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 16),
            Text(AppStrings.loadingData, style: TextStyle(color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (widget.items.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: widget.emptyWidget ?? const EmptyState(title: AppStrings.noDataAvailable),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Calculate the minimum width needed by the columns dynamically
        double requiredColumnsWidth = 32.0; // horizontal padding: 16px on each side
        for (final col in widget.columns) {
          if (col.width != null) {
            requiredColumnsWidth += col.width!;
          } else {
            // Allocate at least 110px per flex factor
            requiredColumnsWidth += (col.flex * 110.0);
          }
        }

        final double effectiveMinWidth = requiredColumnsWidth > widget.minTableWidth
            ? requiredColumnsWidth
            : widget.minTableWidth;

        final double effectiveWidth = constraints.maxWidth > effectiveMinWidth
            ? constraints.maxWidth
            : effectiveMinWidth;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: effectiveWidth > constraints.maxWidth,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: effectiveWidth,
                child: Column(
                  children: <Widget>[
                    // ── Table Header ──────────────────────────────────────────
                    Container(
                      height: widget.headerHeight,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceVariant,
                        border: Border(
                          bottom: BorderSide(color: AppColors.border, width: 1.5),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: List<Widget>.generate(widget.columns.length, (int index) {
                          final AppTableColumn<T> col = widget.columns[index];
                          final bool isSorted = widget.sortColumnIndex == index;

                          Widget headerCell = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  col.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (col.sortable) ...<Widget>[
                                const SizedBox(width: 4),
                                Icon(
                                  isSorted
                                      ? (widget.sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                      : Icons.unfold_more,
                                  size: 16,
                                  color: isSorted ? AppColors.primary : AppColors.onSurfaceVariant,
                                ),
                              ],
                            ],
                          );

                          if (col.sortable && widget.onSort != null) {
                            headerCell = InkWell(
                              onTap: () {
                                final bool newAscending = isSorted ? !widget.sortAscending : true;
                                widget.onSort!(index, newAscending);
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                child: headerCell,
                              ),
                            );
                          }

                          headerCell = Align(
                            alignment: col.alignment,
                            child: headerCell,
                          );

                          if (col.width != null) {
                            return SizedBox(width: col.width, child: headerCell);
                          }
                          return Expanded(flex: col.flex, child: headerCell);
                        }),
                      ),
                    ),

                    // ── Virtualized Rows ──────────────────────────────────────
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.items.length,
                        itemExtent: widget.rowHeight,
                        itemBuilder: (BuildContext context, int rowIndex) {
                          final T item = widget.items[rowIndex];
                          final bool isEven = rowIndex % 2 == 0;

                          return Material(
                            color: isEven ? AppColors.surface : AppColors.background,
                            child: InkWell(
                              onTap: widget.onRowTap != null ? () => widget.onRowTap!(item) : null,
                              hoverColor: AppColors.primaryContainer.withValues(alpha: 0.35),
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: AppColors.divider, width: 0.8),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: List<Widget>.generate(widget.columns.length, (int colIndex) {
                                    final AppTableColumn<T> col = widget.columns[colIndex];
                                    final Widget cell = Align(
                                      alignment: col.alignment,
                                      child: col.cellBuilder(context, item, rowIndex),
                                    );

                                    if (col.width != null) {
                                      return SizedBox(width: col.width, child: cell);
                                    }
                                    return Expanded(flex: col.flex, child: cell);
                                  }),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
