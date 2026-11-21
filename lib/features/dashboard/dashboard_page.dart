import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_views.dart';
import '../inventory/presentation/inventory_controller.dart';
import '../invoices/presentation/invoices_controller.dart';
import '../work_orders/domain/work_order_with_details.dart';
import '../work_orders/presentation/work_orders_controller.dart';

/// Main Dashboard showing live key business metrics and quick shortcuts.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesSummaryAsync = ref.watch(invoicesSummaryProvider);
    final workOrdersSummaryAsync = ref.watch(workOrdersSummaryProvider);
    final inventorySummaryAsync = ref.watch(inventorySummaryProvider);
    final workOrdersAsync = ref.watch(workOrdersListProvider);

    final todaySalesText = invoicesSummaryAsync.value?.formattedTodaySales ?? '٠٫٠٠ ${AppStrings.currencySymbol}';
    final openOrdersText = '${workOrdersSummaryAsync.value?.activeWorkshopCount ?? 0} أمر صيانة';
    final lowStockCount = (inventorySummaryAsync.value?.lowStockCount ?? 0) + (inventorySummaryAsync.value?.outOfStockCount ?? 0);
    final lowStockText = '$lowStockCount صنف';
    final receivablesText = invoicesSummaryAsync.value?.formattedTotalRemaining ?? '٠٫٠٠ ${AppStrings.currencySymbol}';

    final recentOrders = (workOrdersAsync.value ?? const <WorkOrderWithDetails>[]).take(6).toList();

    return AppScaffold(
      title: AppStrings.dashboardTitle,
      subtitle: AppStrings.dashboardSubtitle,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── KPI Metric Cards ──────────────────────────────────────────────
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double cardWidth = (constraints.maxWidth - (3 * 16)) / 4;
              final bool wrapCards = cardWidth < 220;

              final List<Widget> cards = <Widget>[
                _MetricCard(
                  title: AppStrings.metricTodaySales,
                  value: todaySalesText,
                  icon: Icons.trending_up_rounded,
                  color: AppColors.success,
                  containerColor: AppColors.successContainer,
                ),
                _MetricCard(
                  title: AppStrings.metricOpenWorkOrders,
                  value: openOrdersText,
                  icon: Icons.build_circle_outlined,
                  color: AppColors.primary,
                  containerColor: AppColors.primaryContainer,
                ),
                _MetricCard(
                  title: AppStrings.metricLowStock,
                  value: lowStockText,
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.warning,
                  containerColor: AppColors.warningContainer,
                ),
                _MetricCard(
                  title: AppStrings.metricReceivables,
                  value: receivablesText,
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.danger,
                  containerColor: AppColors.dangerContainer,
                ),
              ];

              if (wrapCards) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: cards
                      .map((c) => SizedBox(width: (constraints.maxWidth - 16) / 2, child: c))
                      .toList(),
                );
              }

              return Row(
                children: cards
                    .map((c) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: c,
                          ),
                        ))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Quick Actions Bar ─────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    AppStrings.quickActions,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      ElevatedButton.icon(
                        onPressed: () => context.go('/work-orders'),
                        icon: const Icon(Icons.add),
                        label: const Text(AppStrings.actionNewWorkOrder),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
                        onPressed: () => context.go('/invoices'),
                        icon: const Icon(Icons.receipt_long),
                        label: const Text(AppStrings.actionNewInvoice),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/customers'),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text(AppStrings.actionAddCustomer),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/inventory'),
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text(AppStrings.actionAddItem),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/expenses'),
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text('تسجيل مصروف'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/employees'),
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text('الموظفين والرواتب'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Recent Work Orders Section ────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        AppStrings.recentWorkOrders,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      TextButton.icon(
                        onPressed: () => context.go('/work-orders'),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('عرض جميع الأوامر'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 260,
                    child: AppDataTable<WorkOrderWithDetails>(
                      columns: <AppTableColumn<WorkOrderWithDetails>>[
                        AppTableColumn<WorkOrderWithDetails>(
                          title: 'رقم الأمر',
                          flex: 1,
                          cellBuilder: (_, item, index) => Text(
                            item.orderNumberFormatted,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        AppTableColumn<WorkOrderWithDetails>(
                          title: 'العميل',
                          flex: 2,
                          cellBuilder: (_, item, index) => Text(item.customer.name),
                        ),
                        AppTableColumn<WorkOrderWithDetails>(
                          title: 'السيارة',
                          flex: 2,
                          cellBuilder: (_, item, index) => Text(
                            '${item.vehicle.plateNumber} ${item.vehicle.make != null ? "(${item.vehicle.make})" : ""}',
                          ),
                        ),
                        AppTableColumn<WorkOrderWithDetails>(
                          title: 'الحالة',
                          flex: 1,
                          cellBuilder: (_, item, index) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.statusArabic,
                              style: TextStyle(
                                color: item.statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        AppTableColumn<WorkOrderWithDetails>(
                          title: 'الإجمالي التقديري',
                          flex: 1,
                          cellBuilder: (_, item, index) => Text(
                            item.formattedTotal,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      items: recentOrders,
                      onRowTap: (item) {
                        ref.read(selectedWorkOrderIdProvider.notifier).set(item.id);
                        context.go('/work-orders');
                      },
                      emptyWidget: const EmptyState(
                        title: 'لا توجد أوامر صيانة حالياً',
                        subtitle: 'يمكنك إنشاء أمر شغل جديد من زر الإجراءات السريعة',
                        icon: Icons.build_circle_outlined,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
