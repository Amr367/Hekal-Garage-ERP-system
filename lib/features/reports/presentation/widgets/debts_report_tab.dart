import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/debts_report_data.dart';
import '../reports_controller.dart';

/// Tab displaying customer receivables and supplier payables.
class DebtsReportTab extends ConsumerWidget {
  const DebtsReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsReportProvider);

    return debtsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        title: 'خطأ في تحميل تقرير المديونيات',
        message: e.toString(),
        onRetry: () => ref.invalidate(debtsReportProvider),
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── KPI Summary Cards ─────────────────────────────────────────────
          Row(
            children: <Widget>[
              _KpiCard(
                label: 'إجمالي ديون العملاء (لنا بالخارج)',
                value: data.formattedTotalCustomersDebt,
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.danger,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'عدد العملاء المدينين',
                value: '${data.customersCountWithDebt} عميل',
                icon: Icons.people_outline,
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'إجمالي مستحقات الموردين (علينا)',
                value: data.formattedTotalSuppliersDebt,
                icon: Icons.storefront_outlined,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'عدد الموردين المستحق لهم',
                value: '${data.suppliersCountWithDebt} مورد',
                icon: Icons.local_shipping_outlined,
                color: AppColors.info,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Dual Tables (Split View) ──────────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Left: Customers Debt Table
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(Icons.arrow_downward,
                                color: AppColors.danger, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'ديون العملاء المستحقة',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.dangerContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                data.formattedTotalCustomersDebt,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onDangerContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: data.customerDebts.isEmpty
                              ? const EmptyState(
                                  title: 'لا توجد ديون مستحقة على العملاء',
                                  icon: Icons.check_circle_outline,
                                )
                              : AppDataTable<CustomerDebtRow>(
                                  minTableWidth: 380,
                                  rowHeight: 48,
                                  columns: <AppTableColumn<CustomerDebtRow>>[
                                    AppTableColumn<CustomerDebtRow>(
                                      title: 'اسم العميل',
                                      flex: 2,
                                      cellBuilder: (_, c, _) => Text(
                                        c.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    AppTableColumn<CustomerDebtRow>(
                                      title: 'رقم الهاتف',
                                      width: 120,
                                      cellBuilder: (_, c, _) => Text(
                                        c.phone,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    AppTableColumn<CustomerDebtRow>(
                                      title: 'المبلغ المستحق',
                                      width: 120,
                                      cellBuilder: (_, c, _) => Text(
                                        c.formattedBalance,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.danger,
                                        ),
                                      ),
                                    ),
                                  ],
                                  items: data.customerDebts,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Right: Suppliers Debt Table
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(Icons.arrow_upward,
                                color: AppColors.secondary, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'مستحقات وفواتير الموردين',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                data.formattedTotalSuppliersDebt,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: data.supplierDebts.isEmpty
                              ? const EmptyState(
                                  title: 'لا توجد مستحقات معلقة للموردين',
                                  icon: Icons.check_circle_outline,
                                )
                              : AppDataTable<SupplierDebtRow>(
                                  minTableWidth: 380,
                                  rowHeight: 48,
                                  columns: <AppTableColumn<SupplierDebtRow>>[
                                    AppTableColumn<SupplierDebtRow>(
                                      title: 'اسم المورد',
                                      flex: 2,
                                      cellBuilder: (_, s, _) => Text(
                                        s.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    AppTableColumn<SupplierDebtRow>(
                                      title: 'الفواتير',
                                      width: 80,
                                      cellBuilder: (_, s, _) => Text(
                                        '${s.totalInvoicesCount} فواتير',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    AppTableColumn<SupplierDebtRow>(
                                      title: 'المبلغ المتبقي',
                                      width: 120,
                                      cellBuilder: (_, s, _) => Text(
                                        s.formattedBalance,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                  items: data.supplierDebts,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
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
