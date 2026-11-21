import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../stock_count_controller.dart';

/// Four KPI summary cards for the stock count dashboard.
class StockCountKpiCards extends ConsumerWidget {
  const StockCountKpiCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(stockCountSummaryProvider);

    return summaryAsync.when(
      loading: () => const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: <Widget>[
            _KpiCard(
              icon: Icons.fact_check_outlined,
              label: AppStrings.kpiTotalCountSessions,
              value: summary.totalSessions.toString(),
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            _KpiCard(
              icon: Icons.edit_note,
              label: AppStrings.kpiDraftCounts,
              value: summary.draftSessions.toString(),
              color: AppColors.warning,
            ),
            const SizedBox(width: 12),
            _KpiCard(
              icon: Icons.check_circle_outline,
              label: AppStrings.kpiFinalizedCounts,
              value: summary.finalizedSessions.toString(),
              color: AppColors.success,
            ),
            const SizedBox(width: 12),
            _KpiCard(
              icon: Icons.trending_down,
              label: AppStrings.kpiTotalDifference,
              value: summary.formattedDifferenceValue,
              color: summary.totalDifferenceValuePiasters < 0
                  ? AppColors.error
                  : AppColors.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
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
