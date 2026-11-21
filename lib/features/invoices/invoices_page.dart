import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/services/excel_export_service.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/state_views.dart';
import 'domain/invoice_with_details.dart';
import 'presentation/invoices_controller.dart';
import 'presentation/widgets/direct_sale_invoice_dialog.dart';
import 'presentation/widgets/invoice_details_pane.dart';
import 'presentation/widgets/invoice_preview_dialog.dart';
import 'presentation/widgets/invoices_kpi_cards.dart';

/// Comprehensive invoices and sales management page for Egyptian automotive garage ERP.
class InvoicesPage extends ConsumerWidget {
  const InvoicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesListProvider);
    final selectedInvoice = ref.watch(selectedInvoiceProvider);
    final activeStatusFilter = ref.watch(invoiceStatusFilterProvider);

    return AppScaffold(
      title: AppStrings.invoicesTitle,
      subtitle: AppStrings.invoicesSubtitle,
      actions: <Widget>[
        SizedBox(
          width: 260,
          child: SearchField(
            hintText: 'بحث برقم الفاتورة، العميل، اللوحة...',
            onChanged: (q) => ref.read(invoiceSearchQueryProvider.notifier).setQuery(q),
          ),
        ),
        const SizedBox(width: 8),
        // Export Invoices to Excel Button
        OutlinedButton.icon(
          onPressed: () async {
            final invoices = invoicesAsync.value ?? [];
            if (invoices.isEmpty) {
              AppSnackbar.showWarning(context, 'لا توجد فواتير لتصديرها');
              return;
            }
            final bytes = ExcelExportService.exportInvoicesToExcel(invoices);
            final now = DateTime.now();
            final defaultFileName =
                'invoices_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}.xlsx';

            await ExcelExportService.saveExcelFile(
              context: context,
              bytes: bytes,
              defaultFileName: defaultFileName,
              dialogTitle: 'تصدير فواتير المبيعات إلى Excel',
              successMessage:
                  'تم تصدير فواتير المبيعات بنجاح (${invoices.length} فاتورة)',
            );
          },
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text(AppStrings.exportExcel),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => DirectSaleInvoiceDialog.show(context),
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.newInvoiceButton),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── KPI Summary Cards ─────────────────────────────────────────────
          const InvoicesKpiCards(),

          const SizedBox(height: 16),

          // ── Filter Toolbar ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const Text('تصفية الحالة:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ChoiceChip(
                  label: const Text('جميع الفواتير'),
                  selected: activeStatusFilter == null,
                  onSelected: (_) => ref.read(invoiceStatusFilterProvider.notifier).setFilter(null),
                ),
                ChoiceChip(
                  label: const Text('الفواتير المعتمدة (صادرة)'),
                  selected: activeStatusFilter == InvoiceStatus.issued,
                  onSelected: (_) => ref.read(invoiceStatusFilterProvider.notifier).setFilter(InvoiceStatus.issued),
                ),
                ChoiceChip(
                  label: const Text('الفواتير الملغاة'),
                  selected: activeStatusFilter == InvoiceStatus.cancelled,
                  onSelected: (_) => ref.read(invoiceStatusFilterProvider.notifier).setFilter(InvoiceStatus.cancelled),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Split View: Data Table + Details Pane ─────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double paneWidth = constraints.maxWidth < 1100
                    ? 340.0
                    : (constraints.maxWidth < 1350 ? 380.0 : 420.0);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Table
                    Expanded(
                      child: invoicesAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => ErrorState(
                          title: 'خطأ في تحميل الفواتير',
                          message: e.toString(),
                          onRetry: () => ref.invalidate(invoicesListProvider),
                        ),
                        data: (invoices) => invoices.isEmpty
                            ? const EmptyState(
                                title: 'لا توجد فواتير مسجلة مطابقة لمعايير البحث',
                                icon: Icons.receipt_long,
                              )
                            : AppDataTable<InvoiceWithDetails>(
                                minTableWidth: 980,
                                rowHeight: 52,
                                onRowTap: (inv) => ref.read(selectedInvoiceIdProvider.notifier).select(inv.id),
                                columns: <AppTableColumn<InvoiceWithDetails>>[
                                  AppTableColumn<InvoiceWithDetails>(
                                    title: 'رقم الفاتورة',
                                    width: 95,
                                    cellBuilder: (_, inv, _) => Text(
                                      inv.invoiceNumberFormatted,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  AppTableColumn<InvoiceWithDetails>(
                                    title: 'التاريخ',
                                    width: 95,
                                    cellBuilder: (_, inv, _) => Text(inv.formattedDate),
                                  ),
                                  AppTableColumn<InvoiceWithDetails>(
                                    title: 'العميل',
                                    flex: 2,
                                    cellBuilder: (_, inv, _) => Text(
                                      inv.customerName,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  AppTableColumn<InvoiceWithDetails>(
                                    title: 'المركبة / الأمر',
                                    width: 130,
                                    cellBuilder: (_, inv, _) => Text(
                                      inv.workOrder != null
                                          ? 'أمر #${inv.workOrder!.orderNumber}'
                                          : (inv.vehicle != null ? inv.vehicleTitle : 'بيع مباشر'),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  AppTableColumn<InvoiceWithDetails>(
                                    title: 'الإجمالي',
                                    width: 110,
                                    cellBuilder: (_, inv, _) => Text(
                                      inv.formattedTotal,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  AppTableColumn<InvoiceWithDetails>(
                                    title: 'المدفوع',
                                    width: 110,
                                    cellBuilder: (_, inv, _) => Text(
                                      inv.formattedPaid,
                                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  AppTableColumn<InvoiceWithDetails>(
                                    title: 'المتبقي',
                                    width: 110,
                                    cellBuilder: (_, inv, _) => Text(
                                      inv.formattedRemaining,
                                      style: TextStyle(
                                        color: inv.remainingPiasters > 0 ? AppColors.danger : AppColors.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  AppTableColumn<InvoiceWithDetails>(
                                    title: 'طريقة الدفع',
                                    width: 130,
                                    cellBuilder: (_, inv, _) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        inv.paymentMethodLabel,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                  AppTableColumn<InvoiceWithDetails>(
                                    title: 'الحالة',
                                    width: 100,
                                    cellBuilder: (_, inv, _) => _TableStatusBadge(invoice: inv),
                                  ),
                                  AppTableColumn<InvoiceWithDetails>(
                                    title: 'معاينة',
                                    width: 65,
                                    cellBuilder: (ctx, inv, _) => IconButton(
                                      icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                                      tooltip: 'معاينة وطباعة الفاتورة',
                                      onPressed: () => InvoicePreviewDialog.show(ctx, invoice: inv),
                                    ),
                                  ),
                                ],
                                items: invoices,
                              ),
                      ),
                    ),

                    // Details Pane
                    if (selectedInvoice != null) ...[
                      const SizedBox(width: 14),
                      InvoiceDetailsPane(
                        invoice: selectedInvoice,
                        width: paneWidth,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TableStatusBadge extends StatelessWidget {
  const _TableStatusBadge({required this.invoice});

  final InvoiceWithDetails invoice;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (true) {
      _ when invoice.isCancelled => ('ملغاة', AppColors.danger, AppColors.dangerContainer),
      _ when invoice.isPaid => ('مدفوعة', AppColors.success, AppColors.successContainer),
      _ when invoice.isPartiallyPaid => ('جزئي', AppColors.warning, AppColors.warningContainer),
      _ => ('آجل', AppColors.danger, AppColors.dangerContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
