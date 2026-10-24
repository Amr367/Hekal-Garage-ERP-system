import 'package:flutter/material.dart';

import '../../../../core/db/database.dart';
import '../../../../core/money/money.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../domain/customer_details.dart';

/// Account statement dialog showing invoices, payments, and net balance for a customer.
class CustomerStatementDialog extends StatelessWidget {
  const CustomerStatementDialog({
    super.key,
    required this.details,
  });

  final CustomerDetails details;

  static void show(BuildContext context, {required CustomerDetails details}) {
    showDialog<void>(
      context: context,
      builder: (_) => CustomerStatementDialog(details: details),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = details.summary;

    return AppFormDialog(
      title: '${AppStrings.customerStatementTitle} — ${details.customer.name}',
      saveLabel: AppStrings.close,
      onSave: () => Navigator.of(context).pop(),
      maxWidth: 780,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Financial KPI summary row
          Row(
            children: <Widget>[
              Expanded(
                child: _buildMetricCard(
                  title: 'إجمالي الفواتير الصادرة',
                  value: summary.formattedTotalInvoiced,
                  color: AppColors.primary,
                  icon: Icons.receipt_long,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'إجمالي المسدد',
                  value: summary.formattedTotalPaid,
                  color: AppColors.success,
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: AppStrings.customerBalanceLabel,
                  value: summary.formattedBalance,
                  color: summary.hasDebt
                      ? AppColors.error
                      : (summary.isSettled ? AppColors.success : AppColors.info),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Invoices section title
          const Text(
            'سجل الفواتير:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),

          // Invoices Table
          if (details.invoices.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text(
                'لا توجد فواتير صادرة لهذا العميل حتى الآن.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            SizedBox(
              height: 260,
              child: AppDataTable<Invoice>(
                columns: <AppTableColumn<Invoice>>[
                  AppTableColumn<Invoice>(
                    title: 'رقم الفاتورة',
                    width: 110,
                    cellBuilder: (_, inv, index) => Text(
                      '#${inv.invoiceNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  AppTableColumn<Invoice>(
                    title: 'تاريخ الإصدار',
                    width: 120,
                    cellBuilder: (_, inv, index) {
                      final d = inv.issuedAt;
                      return Text('${d.year}/${d.month}/${d.day}');
                    },
                  ),
                  AppTableColumn<Invoice>(
                    title: 'الإجمالي',
                    width: 110,
                    cellBuilder: (_, inv, index) => Text(
                      MoneyUtils.formatPounds(inv.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  AppTableColumn<Invoice>(
                    title: 'المسدد',
                    width: 110,
                    cellBuilder: (_, inv, index) => Text(
                      MoneyUtils.formatPounds(inv.paidAmount),
                      style: const TextStyle(color: AppColors.success),
                    ),
                  ),
                  AppTableColumn<Invoice>(
                    title: 'المتبقي',
                    width: 110,
                    cellBuilder: (_, inv, index) {
                      final rem = inv.totalAmount - inv.paidAmount;
                      return Text(
                        MoneyUtils.formatPounds(rem),
                        style: TextStyle(
                          color: rem > 0 ? AppColors.error : AppColors.textSecondary,
                          fontWeight: rem > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    },
                  ),
                  AppTableColumn<Invoice>(
                    title: 'الحالة',
                    flex: 1,
                    cellBuilder: (_, inv, index) {
                      final isCancelled = inv.status == InvoiceStatus.cancelled;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCancelled
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isCancelled ? 'ملغاة' : 'سارية',
                          style: TextStyle(
                            color: isCancelled ? AppColors.error : AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                items: details.invoices,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
