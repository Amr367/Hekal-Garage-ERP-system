import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/sales_report_data.dart';
import '../reports_controller.dart';

/// Tab displaying sales, revenues, and payment method distribution.
class SalesReportTab extends ConsumerWidget {
  const SalesReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesReportProvider);

    return salesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        title: 'خطأ في تحميل تقرير المبيعات',
        message: e.toString(),
        onRetry: () => ref.invalidate(salesReportProvider),
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── KPI Summary Cards ─────────────────────────────────────────────
          Row(
            children: <Widget>[
              _KpiCard(
                label: 'إجمالي الفواتير الصادرة',
                value: data.totalInvoices.toString(),
                icon: Icons.receipt_long_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'إجمالي المبيعات والإيرادات',
                value: data.formattedTotalRevenue,
                icon: Icons.monetization_on_outlined,
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'المدفوع والمحصل',
                value: data.formattedTotalPaid,
                icon: Icons.check_circle_outline,
                color: AppColors.info,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'المتبقي (آجل / ديون)',
                value: data.formattedTotalRemaining,
                icon: Icons.pending_actions_outlined,
                color: data.totalRemainingPiasters > 0
                    ? AppColors.danger
                    : AppColors.success,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Payment Methods Breakdown ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'توزيع طرق التحصيل والدفع',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _PaymentMethodBadge(
                        label: 'خزنة الفرع (كاش)',
                        amount: data.formattedAmountFor(PaymentMethod.cash),
                        icon: Icons.point_of_sale,
                        color: const Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 12),
                      _PaymentMethodBadge(
                        label: 'انستاباي (InstaPay)',
                        amount: data.formattedAmountFor(PaymentMethod.instapay),
                        icon: Icons.bolt,
                        color: const Color(0xFF6A1B9A),
                      ),
                      const SizedBox(width: 12),
                      _PaymentMethodBadge(
                        label: 'فودافون كاش ومحافظ',
                        amount: data.formattedAmountFor(PaymentMethod.wallet),
                        icon: Icons.phone_android,
                        color: const Color(0xFFC62828),
                      ),
                      const SizedBox(width: 12),
                      _PaymentMethodBadge(
                        label: 'فيزا / كارت',
                        amount: data.formattedAmountFor(PaymentMethod.card),
                        icon: Icons.credit_card,
                        color: const Color(0xFF0277BD),
                      ),
                      const SizedBox(width: 12),
                      _PaymentMethodBadge(
                        label: 'تحويل بنكي',
                        amount: data.formattedAmountFor(PaymentMethod.transfer),
                        icon: Icons.account_balance,
                        color: const Color(0xFF37474F),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Invoices Data Table ───────────────────────────────────────────
          Expanded(
            child: data.invoices.isEmpty
                ? const EmptyState(
                    title: 'لا توجد فواتير مبيعات صادرة في هذه الفترة',
                    icon: Icons.receipt_long,
                  )
                : AppDataTable<SalesReportInvoiceRow>(
                    minTableWidth: 850,
                    rowHeight: 52,
                    columns: <AppTableColumn<SalesReportInvoiceRow>>[
                      AppTableColumn<SalesReportInvoiceRow>(
                        title: 'رقم الفاتورة',
                        width: 110,
                        cellBuilder: (_, inv, _) => Text(
                          '#${inv.invoiceNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      AppTableColumn<SalesReportInvoiceRow>(
                        title: 'التاريخ',
                        width: 120,
                        cellBuilder: (_, inv, _) => Text(
                          inv.date.toString().split(' ')[0],
                        ),
                      ),
                      AppTableColumn<SalesReportInvoiceRow>(
                        title: 'العميل',
                        flex: 2,
                        cellBuilder: (_, inv, _) => Text(
                          inv.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      AppTableColumn<SalesReportInvoiceRow>(
                        title: 'رقم اللوحة',
                        width: 130,
                        cellBuilder: (_, inv, _) => Text(inv.plateNumber),
                      ),
                      AppTableColumn<SalesReportInvoiceRow>(
                        title: 'الإجمالي',
                        width: 130,
                        cellBuilder: (_, inv, _) => Text(
                          inv.formattedTotal,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      AppTableColumn<SalesReportInvoiceRow>(
                        title: 'المدفوع',
                        width: 130,
                        cellBuilder: (_, inv, _) => Text(
                          inv.formattedPaid,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AppTableColumn<SalesReportInvoiceRow>(
                        title: 'المتبقي',
                        width: 120,
                        cellBuilder: (_, inv, _) => Text(
                          inv.formattedRemaining,
                          style: TextStyle(
                            color: inv.remainingPiasters > 0
                                ? AppColors.danger
                                : AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AppTableColumn<SalesReportInvoiceRow>(
                        title: 'طريقة الدفع',
                        width: 150,
                        cellBuilder: (_, inv, _) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            inv.paymentMethodLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    items: data.invoices,
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

class _PaymentMethodBadge extends StatelessWidget {
  const _PaymentMethodBadge({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
