import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/inventory_report_data.dart';
import '../reports_controller.dart';

/// Tab displaying stock valuation, top-moving items, and stagnant inventory analysis.
class InventoryReportTab extends ConsumerWidget {
  const InventoryReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(inventoryReportProvider);

    return invAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        title: 'خطأ في تحميل تقرير المخزون',
        message: e.toString(),
        onRetry: () => ref.invalidate(inventoryReportProvider),
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── KPI Valuation Cards ───────────────────────────────────────────
          Row(
            children: <Widget>[
              _KpiCard(
                label: 'إجمالي الأصناف بالمخزن',
                value: data.totalItemsCount.toString(),
                icon: Icons.inventory_2_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'قيمة المخزون (بسعر الشراء)',
                value: data.formattedValuationCost,
                icon: Icons.price_change_outlined,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'قيمة المخزون (بسعر البيع)',
                value: data.formattedValuationSale,
                icon: Icons.storefront_outlined,
                color: AppColors.info,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'الربح المتوقع بالمخزن',
                value: data.formattedPotentialProfit,
                icon: Icons.trending_up,
                color: AppColors.success,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Fast Moving & Stagnant Tables (Split View) ────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Left: Top Moving Items
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(Icons.local_fire_department,
                                color: AppColors.warning, size: 22),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'الأصناف الأكثر حركة ومبيعاً',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warningContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${data.topMovingItems.length} أصناف',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onWarningContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: data.topMovingItems.isEmpty
                              ? const EmptyState(
                                  title: 'لا توجد حركات بيع مسجلة حتى الآن',
                                  icon: Icons.trending_flat,
                                )
                              : AppDataTable<TopMovingItemRow>(
                                  minTableWidth: 380,
                                  rowHeight: 48,
                                  columns: <AppTableColumn<TopMovingItemRow>>[
                                    AppTableColumn<TopMovingItemRow>(
                                      title: 'اسم الصنف',
                                      flex: 2,
                                      cellBuilder: (_, item, _) => Text(
                                        item.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    AppTableColumn<TopMovingItemRow>(
                                      title: 'القسم',
                                      width: 100,
                                      cellBuilder: (_, item, _) => Text(
                                        item.categoryName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    AppTableColumn<TopMovingItemRow>(
                                      title: 'الكمية المباعة',
                                      width: 90,
                                      cellBuilder: (_, item, _) => Text(
                                        item.formattedQty,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                  items: data.topMovingItems,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Right: Stagnant Items (الراكدة)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(Icons.hourglass_empty,
                                color: AppColors.danger, size: 22),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'الأصناف الراكدة (لم تتحرك منذ 90 يوماً)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.dangerContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${data.stagnantItems.length} راكدة',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onDangerContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: data.stagnantItems.isEmpty
                              ? const EmptyState(
                                  title: 'ممتاز! لا توجد أصناف راكدة بالمخزن',
                                  icon: Icons.check_circle_outline,
                                )
                              : AppDataTable<InventoryReportItemRow>(
                                  minTableWidth: 380,
                                  rowHeight: 48,
                                  columns: <AppTableColumn<InventoryReportItemRow>>[
                                    AppTableColumn<InventoryReportItemRow>(
                                      title: 'اسم الصنف',
                                      flex: 2,
                                      cellBuilder: (_, item, _) => Text(
                                        item.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    AppTableColumn<InventoryReportItemRow>(
                                      title: 'الرصيد',
                                      width: 90,
                                      cellBuilder: (_, item, _) => Text(
                                        '${item.formattedQty} ${item.unit}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    AppTableColumn<InventoryReportItemRow>(
                                      title: 'قيمة التكلفة',
                                      width: 110,
                                      cellBuilder: (_, item, _) => Text(
                                        item.formattedTotalCostValue,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.danger,
                                        ),
                                      ),
                                    ),
                                  ],
                                  items: data.stagnantItems,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
