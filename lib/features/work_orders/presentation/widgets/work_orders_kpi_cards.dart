import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../work_orders_controller.dart';

/// 4 desktop KPI summary metric cards for work orders.
class WorkOrdersKpiCards extends ConsumerWidget {
  const WorkOrdersKpiCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(workOrdersSummaryProvider);

    return summaryAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, stack) => const SizedBox.shrink(),
      data: (summary) {
        final cards = <Widget>[
          _MetricCard(
            title: AppStrings.kpiInProgressOrders,
            value: '${summary.inProgressOrdersCount}',
            subtitle: 'أوامر جاري تنفيذها في الورشة',
            icon: Icons.engineering_rounded,
            color: AppColors.primary,
          ),
          _MetricCard(
            title: AppStrings.kpiReadyOrders,
            value: '${summary.readyOrdersCount}',
            subtitle: 'سيارات تم إصلاحها وجاهزة',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
          ),
          _MetricCard(
            title: AppStrings.kpiTodayOrders,
            value: '${summary.todayOrdersCount}',
            subtitle: 'أوامر جديدة دخلت اليوم',
            icon: Icons.today_rounded,
            color: const Color(0xFF0288D1),
          ),
          _MetricCard(
            title: AppStrings.kpiEstimatedOpenValue,
            value: summary.formattedEstimatedOpenValue,
            subtitle: 'إجمالي مصنعيات وقطع الأوامر المفتوحة',
            icon: Icons.monetization_on_outlined,
            color: AppColors.warning,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              final double cardW = (constraints.maxWidth - 14) / 2;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: cards.map((c) => SizedBox(width: cardW, child: c)).toList(),
              );
            }
            return Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
