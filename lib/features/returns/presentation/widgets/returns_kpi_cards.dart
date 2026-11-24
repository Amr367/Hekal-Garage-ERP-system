import 'package:flutter/material.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/returns_summary.dart';

/// KPI metric cards for the Returns Department.
class ReturnsKpiCards extends StatelessWidget {
  const ReturnsKpiCards({
    super.key,
    required this.summary,
  });

  final ReturnsSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth = (constraints.maxWidth - (2 * 16)) / 3;
        final bool wrapCards = cardWidth < 220;

        final List<Widget> cards = <Widget>[
          _MetricCard(
            title: AppStrings.totalReturnsCount,
            value: '${summary.totalCount} عملية إرجاع',
            icon: Icons.assignment_return_outlined,
            color: AppColors.primary,
            containerColor: AppColors.primaryContainer,
          ),
          _MetricCard(
            title: AppStrings.totalSalesReturnsAmount,
            value: summary.formattedTotalSalesReturns,
            icon: Icons.undo_outlined,
            color: AppColors.warning,
            containerColor: AppColors.warningContainer,
          ),
          _MetricCard(
            title: AppStrings.totalPurchaseReturnsAmount,
            value: summary.formattedTotalPurchaseReturns,
            icon: Icons.replay_outlined,
            color: AppColors.secondary,
            containerColor: AppColors.secondaryContainer,
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
          children: <Widget>[
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
            const SizedBox(width: 16),
            Expanded(child: cards[2]),
          ],
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
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
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
