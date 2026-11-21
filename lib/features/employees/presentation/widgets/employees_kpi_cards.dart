import 'package:flutter/material.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/db/repositories/employees_repository.dart';

/// KPI summary cards for the Employees & Payroll page.
class EmployeesKpiCards extends StatelessWidget {
  const EmployeesKpiCards({
    super.key,
    required this.summary,
  });

  final EmployeesSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        final cards = [
          _KpiCard(
            title: 'طاقم العمل النشط',
            valueText: '${summary.activeEmployees} من ${summary.totalEmployees} موظف',
            icon: Icons.people_alt_outlined,
            color: AppColors.primary,
          ),
          _KpiCard(
            title: 'إجمالي الرواتب الأساسية',
            valueText: MoneyUtils.format(summary.totalBasicSalariesPiasters, withCurrency: true),
            icon: Icons.account_balance_outlined,
            color: AppColors.secondary,
          ),
          _KpiCard(
            title: 'سلفيات معلقة للخصم',
            valueText: MoneyUtils.format(summary.pendingAdvancesPiasters, withCurrency: true),
            icon: Icons.price_change_outlined,
            color: AppColors.warning,
          ),
          _KpiCard(
            title: 'رواتب مصروفة هذا الشهر',
            valueText: MoneyUtils.format(summary.currentMonthPaidSalariesPiasters, withCurrency: true),
            icon: Icons.payments_outlined,
            color: AppColors.success,
          ),
        ];

        if (isCompact) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((c) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: c))
                .toList(),
          );
        }

        return Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.valueText,
    required this.icon,
    required this.color,
  });

  final String title;
  final String valueText;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  valueText,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
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
