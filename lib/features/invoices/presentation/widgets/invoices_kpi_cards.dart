import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../invoices_controller.dart';

/// 4 KPI metric cards summarizing business sales, cash collected, and debt.
class InvoicesKpiCards extends ConsumerWidget {
  const InvoicesKpiCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(invoicesSummaryProvider);

    return summaryAsync.when(
      loading: () => const SizedBox(
        height: 84,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) {
        final cards = <Widget>[
          _CardItem(
            label: 'إجمالي المبيعات المفوترة',
            value: summary.formattedTotalSales,
            icon: Icons.receipt_long_outlined,
            color: AppColors.primary,
          ),
          _CardItem(
            label: 'إجمالي المحصل والمدفوع',
            value: summary.formattedTotalCollected,
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          ),
          _CardItem(
            label: 'المتبقي (آجل وديون)',
            value: summary.formattedTotalRemaining,
            icon: Icons.pending_actions_outlined,
            color: summary.totalRemainingPiasters > 0 ? AppColors.danger : AppColors.success,
          ),
          _CardItem(
            label: 'مبيعات اليوم (${summary.todayInvoicesCount} فاتورة)',
            value: summary.formattedTodaySales,
            icon: Icons.today_outlined,
            color: AppColors.info,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              final double cardW = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards.map((c) => SizedBox(width: cardW, child: c)).toList(),
              );
            }
            return Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
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

class _CardItem extends StatelessWidget {
  const _CardItem({
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
    return Container(
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
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: color,
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
