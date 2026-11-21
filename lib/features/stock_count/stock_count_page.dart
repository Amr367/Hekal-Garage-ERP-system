import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/state_views.dart';
import 'domain/stock_count_with_details.dart';
import 'presentation/stock_count_controller.dart';
import 'presentation/widgets/stock_count_details_pane.dart';
import 'presentation/widgets/stock_count_form_dialog.dart';
import 'presentation/widgets/stock_count_kpi_cards.dart';

/// Stock count management page for physical inventory audit & reconciliation.
class StockCountPage extends ConsumerWidget {
  const StockCountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockCountsAsync = ref.watch(stockCountsListProvider);
    final selectedCountAsync = ref.watch(selectedStockCountProvider);
    final selectedId = ref.watch(selectedStockCountIdProvider);

    return AppScaffold(
      title: AppStrings.stockCountTitle,
      subtitle: AppStrings.stockCountSubtitle,
      actions: <Widget>[
        ElevatedButton.icon(
          onPressed: () => StockCountFormDialog.show(context),
          icon: const Icon(Icons.add_task),
          label: const Text(AppStrings.startStockCountButton),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── KPI Summary Cards ─────────────────────────────────────────────
          const StockCountKpiCards(),

          // ── Search & Filter Toolbar ───────────────────────────────────────
          Row(
            children: <Widget>[
              Expanded(
                child: SearchField(
                  hintText: AppStrings.stockCountSearchHint,
                  onChanged: (q) {
                    ref
                        .read(stockCountSearchQueryProvider.notifier)
                        .update(q);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Master-Detail Layout ──────────────────────────────────────────
          Expanded(
            child: stockCountsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                title: 'خطأ',
                message: e.toString(),
                onRetry: () => ref.invalidate(stockCountsListProvider),
              ),
              data: (counts) {
                if (counts.isEmpty) {
                  return const EmptyState(
                    title: 'لا توجد جلسات جرد مسجلة',
                    subtitle:
                        'اضغط على "بدء جرد جديد" لحصر الكميات الفعلية ومطابقتها مع أرصدة النظام.',
                    icon: Icons.fact_check_outlined,
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Stock Counts Sessions Table
                    Expanded(
                      flex: selectedId != null ? 5 : 1,
                      child: AppDataTable<StockCountWithDetails>(
                        rowHeight: 52,
                        minTableWidth: 880,
                        columns: <AppTableColumn<StockCountWithDetails>>[
                          AppTableColumn<StockCountWithDetails>(
                            title: AppStrings.countNumber,
                            width: 110,
                            cellBuilder: (_, c, _) => Text(
                              '#${c.countNumber}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          AppTableColumn<StockCountWithDetails>(
                            title: AppStrings.countDate,
                            width: 130,
                            cellBuilder: (_, c, _) => Text(
                              c.createdAt.toString().split(' ')[0],
                            ),
                          ),
                          AppTableColumn<StockCountWithDetails>(
                            title: AppStrings.countScope,
                            width: 140,
                            cellBuilder: (_, c, _) => Text(c.scopeLabel),
                          ),
                          AppTableColumn<StockCountWithDetails>(
                            title: 'الحالة',
                            width: 120,
                            cellBuilder: (_, c, _) {
                              final color = c.isDraft
                                  ? AppColors.warning
                                  : AppColors.success;
                              final containerColor = c.isDraft
                                  ? AppColors.warningContainer
                                  : AppColors.successContainer;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: containerColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c.statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              );
                            },
                          ),
                          AppTableColumn<StockCountWithDetails>(
                            title: 'الأصناف (معدود / إجمالي)',
                            width: 150,
                            cellBuilder: (_, c, _) => Text(
                              '${c.countedItems} / ${c.totalItems}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: c.remainingItems == 0
                                    ? AppColors.success
                                    : AppColors.onSurface,
                              ),
                            ),
                          ),
                          AppTableColumn<StockCountWithDetails>(
                            title: AppStrings.kpiTotalDifference,
                            width: 130,
                            cellBuilder: (_, c, _) {
                              final diff = c.totalDifferenceValuePiasters;
                              final color = diff == 0
                                  ? AppColors.onSurfaceVariant
                                  : (diff < 0
                                      ? AppColors.danger
                                      : AppColors.success);
                              return Text(
                                c.formattedTotalDifferenceValue,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              );
                            },
                          ),
                          AppTableColumn<StockCountWithDetails>(
                            title: 'ملاحظات',
                            flex: 2,
                            cellBuilder: (_, c, _) => Text(
                              c.notes ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                        items: counts,
                        onRowTap: (c) {
                          ref
                              .read(selectedStockCountIdProvider.notifier)
                              .select(c.id);
                        },
                      ),
                    ),

                    // Right-side Details Pane
                    if (selectedCountAsync.value != null) ...<Widget>[
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 6,
                        child: StockCountDetailsPane(
                          stockCount: selectedCountAsync.value!,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
