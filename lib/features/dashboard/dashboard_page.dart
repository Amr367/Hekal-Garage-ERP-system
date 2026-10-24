import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';

/// Main Dashboard showing key business metrics and quick shortcuts.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                const _MetricCard(
                  title: AppStrings.metricTodaySales,
                  value: '٠٫٠٠ ${AppStrings.currencySymbol}',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.success,
                  containerColor: AppColors.successContainer,
                ),
                const _MetricCard(
                  title: AppStrings.metricOpenWorkOrders,
                  value: '٠ أمر صيانة',
                  icon: Icons.build_circle_outlined,
                  color: AppColors.primary,
                  containerColor: AppColors.primaryContainer,
                ),
                const _MetricCard(
                  title: AppStrings.metricLowStock,
                  value: '٠ صنف',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.warning,
                  containerColor: AppColors.warningContainer,
                ),
                const _MetricCard(
                  title: AppStrings.metricReceivables,
                  value: '٠٫٠٠ ${AppStrings.currencySymbol}',
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
                  const Text(
                    AppStrings.recentWorkOrders,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 240,
                    child: AppDataTable<Map<String, String>>(
                      columns: <AppTableColumn<Map<String, String>>>[
                        AppTableColumn<Map<String, String>>(
                          title: 'رقم الأمر',
                          flex: 1,
                          cellBuilder: (_, item, index) => Text(item['orderNo'] ?? ''),
                        ),
                        AppTableColumn<Map<String, String>>(
                          title: 'العميل',
                          flex: 2,
                          cellBuilder: (_, item, index) => Text(item['customer'] ?? ''),
                        ),
                        AppTableColumn<Map<String, String>>(
                          title: 'السيارة',
                          flex: 2,
                          cellBuilder: (_, item, index) => Text(item['vehicle'] ?? ''),
                        ),
                        AppTableColumn<Map<String, String>>(
                          title: 'الحالة',
                          flex: 1,
                          cellBuilder: (_, item, index) => Text(item['status'] ?? ''),
                        ),
                        AppTableColumn<Map<String, String>>(
                          title: 'الإجمالي',
                          flex: 1,
                          cellBuilder: (_, item, index) => Text(item['total'] ?? ''),
                        ),
                      ],
                      items: const <Map<String, String>>[],
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
