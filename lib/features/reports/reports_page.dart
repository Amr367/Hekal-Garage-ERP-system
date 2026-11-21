import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_scaffold.dart';
import 'presentation/reports_controller.dart';
import 'presentation/widgets/debts_report_tab.dart';
import 'presentation/widgets/inventory_report_tab.dart';
import 'presentation/widgets/profit_report_tab.dart';
import 'presentation/widgets/reports_header_toolbar.dart';
import 'presentation/widgets/sales_report_tab.dart';

/// Financial and operational reports page for Egyptian automotive garage ERP.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(reportsSelectedTabProvider);

    return AppScaffold(
      title: AppStrings.reportsTitle,
      subtitle: AppStrings.reportsSubtitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Date Range & Export Toolbar ───────────────────────────────────
          const ReportsHeaderToolbar(),

          const SizedBox(height: 16),

          // ── Section Tabs ──────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: <Widget>[
                  _ReportTabItem(
                    title: 'تقرير المبيعات والإيرادات',
                    icon: Icons.payments_outlined,
                    isSelected: activeTab == 0,
                    onTap: () => ref
                        .read(reportsSelectedTabProvider.notifier)
                        .selectTab(0),
                  ),
                  const SizedBox(width: 8),
                  _ReportTabItem(
                    title: 'تقرير الأرباح وهوامش الربح',
                    icon: Icons.trending_up,
                    isSelected: activeTab == 1,
                    onTap: () => ref
                        .read(reportsSelectedTabProvider.notifier)
                        .selectTab(1),
                  ),
                  const SizedBox(width: 8),
                  _ReportTabItem(
                    title: 'حركة المخزون والركود',
                    icon: Icons.inventory_outlined,
                    isSelected: activeTab == 2,
                    onTap: () => ref
                        .read(reportsSelectedTabProvider.notifier)
                        .selectTab(2),
                  ),
                  const SizedBox(width: 8),
                  _ReportTabItem(
                    title: 'مديونيات العملاء والموردين',
                    icon: Icons.account_balance_outlined,
                    isSelected: activeTab == 3,
                    onTap: () => ref
                        .read(reportsSelectedTabProvider.notifier)
                        .selectTab(3),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ── Active Report View ────────────────────────────────────────────
          Expanded(
            child: switch (activeTab) {
              0 => const SalesReportTab(),
              1 => const ProfitReportTab(),
              2 => const InventoryReportTab(),
              3 => const DebtsReportTab(),
              _ => const SalesReportTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _ReportTabItem extends StatelessWidget {
  const _ReportTabItem({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
