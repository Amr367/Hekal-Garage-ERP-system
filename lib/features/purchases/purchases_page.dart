import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/excel_export_service.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/state_views.dart';
import 'domain/purchase_invoice_with_details.dart';
import 'presentation/purchases_controller.dart';
import 'presentation/widgets/purchase_details_pane.dart';
import 'presentation/widgets/purchase_invoice_form_dialog.dart';
import 'presentation/widgets/purchases_kpi_cards.dart';
import 'presentation/widgets/suppliers_dialog.dart';

/// Purchases & Suppliers management page for automotive garage ERP.
class PurchasesPage extends ConsumerWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(purchasesSummaryProvider);
    final purchasesAsync = ref.watch(purchasesListProvider);
    final selectedPurchaseAsync = ref.watch(selectedPurchaseProvider);
    final suppliersAsync = ref.watch(suppliersListProvider);
    final selectedSupplierId = ref.watch(supplierFilterProvider);

    return AppScaffold(
      title: AppStrings.purchasesTitle,
      subtitle: AppStrings.purchasesSubtitle,
      actions: <Widget>[
        // Export Purchases to Excel Button
        OutlinedButton.icon(
          onPressed: () async {
            final purchases = purchasesAsync.value ?? [];
            if (purchases.isEmpty) {
              AppSnackbar.showWarning(context, 'لا توجد فواتير مشتريات لتصديرها');
              return;
            }
            final bytes = ExcelExportService.exportPurchasesToExcel(purchases);
            final now = DateTime.now();
            final defaultFileName =
                'purchases_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}.xlsx';

            await ExcelExportService.saveExcelFile(
              context: context,
              bytes: bytes,
              defaultFileName: defaultFileName,
              dialogTitle: 'تصدير فواتير المشتريات إلى Excel',
              successMessage:
                  'تم تصدير فواتير المشتريات بنجاح (${purchases.length} فاتورة)',
            );
          },
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text(AppStrings.exportExcel),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => SuppliersDialog.show(context),
          icon: const Icon(Icons.store),
          label: const Text(AppStrings.manageSuppliersButton),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => PurchaseInvoiceFormDialog.show(context),
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text(AppStrings.newPurchaseButton),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── KPI Summary Cards ─────────────────────────────────────────────
          summaryAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorState(title: 'خطأ', message: e.toString()),
            data: (summary) => PurchasesKpiCards(summary: summary),
          ),

          const SizedBox(height: 16),

          // ── Search & Filter Toolbar ───────────────────────────────────────
          Row(
            children: <Widget>[
              // Search input
              Expanded(
                flex: 3,
                child: SearchField(
                  hintText: AppStrings.purchasesSearchHint,
                  onChanged: (q) {
                    ref.read(purchasesSearchQueryProvider.notifier).setQuery(q);
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Filter by supplier
              Expanded(
                flex: 2,
                child: suppliersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (suppliers) {
                    return DropdownButtonFormField<int?>(
                      initialValue: selectedSupplierId,
                      decoration: const InputDecoration(
                        labelText: 'تصفية بالمورد',
                        prefixIcon: Icon(Icons.filter_alt_outlined),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(AppStrings.filterAllSuppliers),
                        ),
                        ...suppliers.map((s) => DropdownMenuItem<int?>(
                              value: s.id,
                              child: Text(s.name),
                            )),
                      ],
                      onChanged: (id) {
                        ref.read(supplierFilterProvider.notifier).selectSupplier(id);
                      },
                    );
                  },
                ),
              ),

              if (selectedSupplierId != null) ...<Widget>[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    ref.read(supplierFilterProvider.notifier).selectSupplier(null);
                  },
                  icon: const Icon(Icons.clear),
                  tooltip: AppStrings.clearSearch,
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // ── Master-Detail Layout ──────────────────────────────────────────
          Expanded(
            child: purchasesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                title: 'خطأ',
                message: e.toString(),
                onRetry: () => ref.invalidate(purchasesListProvider),
              ),
              data: (purchases) {
                if (purchases.isEmpty) {
                  return const EmptyState(
                    title: 'لا توجد فواتير شراء مسجلة',
                    subtitle: 'اضغط على "تسجيل فاتورة شراء جديدة" لإضافة بضاعة للمخزن وتوثيق حسابات الموردين.',
                    icon: Icons.shopping_bag_outlined,
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Purchases Table
                    Expanded(
                      child: AppDataTable<PurchaseInvoiceWithDetails>(
                        rowHeight: 52,
                        columns: <AppTableColumn<PurchaseInvoiceWithDetails>>[
                          AppTableColumn<PurchaseInvoiceWithDetails>(
                            title: 'رقم الفاتورة',
                            width: 130,
                            cellBuilder: (_, p, _) => Text(
                              '#${p.id}${p.supplierInvoiceNumber != null ? " (${p.supplierInvoiceNumber})" : ""}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          AppTableColumn<PurchaseInvoiceWithDetails>(
                            title: 'المورد',
                            flex: 2,
                            cellBuilder: (_, p, _) => Text(
                              p.supplier.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          AppTableColumn<PurchaseInvoiceWithDetails>(
                            title: 'التاريخ',
                            width: 120,
                            cellBuilder: (_, p, _) => Text(p.formattedDate),
                          ),
                          AppTableColumn<PurchaseInvoiceWithDetails>(
                            title: 'إجمالي الفاتورة',
                            width: 140,
                            cellBuilder: (_, p, _) => Text(
                              p.formattedTotal,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          AppTableColumn<PurchaseInvoiceWithDetails>(
                            title: 'المدفوع',
                            width: 130,
                            cellBuilder: (_, p, _) => Text(
                              p.formattedPaid,
                              style: const TextStyle(color: AppColors.success),
                            ),
                          ),
                          AppTableColumn<PurchaseInvoiceWithDetails>(
                            title: 'المتبقي',
                            width: 130,
                            cellBuilder: (_, p, _) => Text(
                              p.formattedRemaining,
                              style: TextStyle(
                                fontWeight: p.remainingAmountPiasters > 0
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: p.remainingAmountPiasters > 0
                                    ? AppColors.danger
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          AppTableColumn<PurchaseInvoiceWithDetails>(
                            title: 'حالة السداد',
                            width: 130,
                            cellBuilder: (_, p, _) {
                              final color = p.paymentStatus == PurchasePaymentStatus.paid
                                  ? AppColors.success
                                  : (p.paymentStatus == PurchasePaymentStatus.partial
                                      ? AppColors.warning
                                      : AppColors.danger);
                              final containerColor = p.paymentStatus == PurchasePaymentStatus.paid
                                  ? AppColors.successContainer
                                  : (p.paymentStatus == PurchasePaymentStatus.partial
                                      ? AppColors.warningContainer
                                      : AppColors.dangerContainer);

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: containerColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.paymentStatusArabic,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        items: purchases,
                        onRowTap: (p) {
                          ref.read(selectedPurchaseIdProvider.notifier).select(p.id);
                        },
                      ),
                    ),

                    // Right-side Details Pane
                    if (selectedPurchaseAsync.value != null) ...<Widget>[
                      const SizedBox(width: 16),
                      PurchaseDetailsPane(
                        purchase: selectedPurchaseAsync.value!,
                        onClose: () {
                          ref.read(selectedPurchaseIdProvider.notifier).select(null);
                        },
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
