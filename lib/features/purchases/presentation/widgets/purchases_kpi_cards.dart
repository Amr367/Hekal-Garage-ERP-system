import 'package:flutter/material.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/purchases_summary.dart';

/// 4 Desktop summary KPI metric cards for Purchases and Suppliers.
class PurchasesKpiCards extends StatelessWidget {
  const PurchasesKpiCards({
    super.key,
    required this.summary,
  });

  final PurchasesSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth = (constraints.maxWidth - (3 * 16)) / 4;
        final bool wrapCards = cardWidth < 220;

        final List<Widget> cards = <Widget>[
          _MetricCard(
            title: AppStrings.kpiTotalPurchases,
            value: summary.formattedTotalPurchases,
            icon: Icons.shopping_bag_outlined,
            color: AppColors.primary,
            containerColor: AppColors.primaryContainer,
          ),
          _MetricCard(
            title: AppStrings.kpiSuppliersDebt,
            value: summary.formattedTotalDebt,
            icon: Icons.account_balance_wallet_outlined,
            color: summary.totalSuppliersDebtPiasters > 0
                ? AppColors.danger
                : AppColors.success,
            containerColor: summary.totalSuppliersDebtPiasters > 0
                ? AppColors.dangerContainer
                : AppColors.successContainer,
          ),
          _MetricCard(
            title: AppStrings.kpiActiveSuppliers,
            value: '${summary.activeSuppliersCount} مورد',
            icon: Icons.store_outlined,
            color: AppColors.secondary,
            containerColor: AppColors.secondaryContainer,
          ),
          _MetricCard(
            title: AppStrings.kpiRecentPurchases,
            value: summary.formattedThisMonthPurchases,
            icon: Icons.calendar_today_outlined,
            color: AppColors.success,
            containerColor: AppColors.successContainer,
          ),
        ];

        if (wrapCards) {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: cards
                .map((w) => SizedBox(
                      width: (constraints.maxWidth - 16) / 2,
                      child: w,
                    ))
                .toList(),
          );
        }

        return Row(
          children: cards
              .map((w) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: w,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.containerColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
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
                    color: AppColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
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
