import 'package:flutter/material.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/db/repositories/expenses_repository.dart';

/// KPI Summary cards for the Expenses page.
class ExpensesKpiCards extends StatelessWidget {
  const ExpensesKpiCards({
    super.key,
    required this.summary,
  });

  final ExpensesSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        final cards = [
          _KpiCard(
            title: 'إجمالي المصروفات',
            amountText: MoneyUtils.format(summary.totalPiasters, withCurrency: true),
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.primary,
          ),
          _KpiCard(
            title: 'مصروفات اليوم',
            amountText: MoneyUtils.format(summary.todayPiasters, withCurrency: true),
            icon: Icons.today_outlined,
            color: AppColors.warning,
          ),
          _KpiCard(
            title: 'مصروفات هذا الشهر',
            amountText: MoneyUtils.format(summary.thisMonthPiasters, withCurrency: true),
            icon: Icons.calendar_month_outlined,
            color: AppColors.danger,
          ),
          _KpiCard(
            title: 'إجمالي السندات',
            amountText: '${summary.count} سند',
            icon: Icons.receipt_long_outlined,
            color: AppColors.secondary,
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
    required this.amountText,
    required this.icon,
    required this.color,
  });

  final String title;
  final String amountText;
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
                  amountText,
                  style: TextStyle(
                    fontSize: 18,
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
