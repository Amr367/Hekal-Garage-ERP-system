import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/state_views.dart';
import 'domain/return_with_details.dart';
import 'presentation/returns_controller.dart';
import 'presentation/widgets/new_purchase_return_dialog.dart';
import 'presentation/widgets/new_sale_return_dialog.dart';
import 'presentation/widgets/return_details_pane.dart';
import 'presentation/widgets/return_preview_dialog.dart';
import 'presentation/widgets/returns_kpi_cards.dart';

/// Returns Department page for automotive garage ERP.
///
/// Handles both Customer Sales Returns (مرتجع مبيعات) and Supplier Purchase Returns (مرتجع مشتريات),
/// automatically syncing warehouse stock and party balances.
class ReturnsPage extends ConsumerWidget {
  const ReturnsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(returnsSummaryProvider);
    final returnsAsync = ref.watch(returnsListProvider);
    final selectedReturnAsync = ref.watch(selectedReturnProvider);
    final selectedType = ref.watch(returnsTypeFilterProvider);

    return AppScaffold(
      title: AppStrings.returnsTitle,
      subtitle: AppStrings.returnsSubtitle,
      actions: <Widget>[
        // New Supplier Purchase Return
        OutlinedButton.icon(
          onPressed: () => NewPurchaseReturnDialog.show(context),
          icon: const Icon(Icons.replay_outlined, size: 18),
          label: const Text(AppStrings.newPurchaseReturnButton),
        ),
        const SizedBox(width: 8),
        // New Customer Sale Return
        ElevatedButton.icon(
          onPressed: () => NewSaleReturnDialog.show(context),
          icon: const Icon(Icons.undo_outlined, size: 18),
          label: const Text(AppStrings.newSaleReturnButton),
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
            data: (summary) => ReturnsKpiCards(summary: summary),
          ),

          const SizedBox(height: 16),

          // ── Search & Filter Toolbar ───────────────────────────────────────
          Row(
            children: <Widget>[
              // Search input
              Expanded(
                flex: 3,
                child: SearchField(
                  hintText: AppStrings.returnsSearchHint,
                  onChanged: (q) {
                    ref.read(returnsSearchQueryProvider.notifier).setQuery(q);
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Filter by Return Type
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<ReturnType?>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: AppStrings.filterReturnType,
                    prefixIcon: Icon(Icons.filter_alt_outlined),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem<ReturnType?>(
                      value: null,
                      child: Text(AppStrings.allReturns),
                    ),
                    DropdownMenuItem<ReturnType?>(
                      value: ReturnType.saleReturn,
                      child: Text(AppStrings.saleReturn),
                    ),
                    DropdownMenuItem<ReturnType?>(
                      value: ReturnType.purchaseReturn,
                      child: Text(AppStrings.purchaseReturn),
                    ),
                  ],
                  onChanged: (type) {
                    ref.read(returnsTypeFilterProvider.notifier).setType(type);
                  },
                ),
              ),

              if (selectedType != null) ...<Widget>[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    ref.read(returnsTypeFilterProvider.notifier).setType(null);
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
            child: returnsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                title: 'خطأ',
                message: e.toString(),
                onRetry: () => ref.invalidate(returnsListProvider),
              ),
              data: (returns) {
                if (returns.isEmpty) {
                  return const EmptyState(
                    title: 'لا توجد أذونات مرتجعات مسجلة',
                    subtitle:
                        'استخدم الأزرار أعلاه لتسجيل مرتجع مبيعات من عميل أو مرتجع مشتريات إلى مورد.',
                    icon: Icons.assignment_return_outlined,
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Returns Table
                    Expanded(
                      child: AppDataTable<ReturnWithDetails>(
                        rowHeight: 52,
                        columns: <AppTableColumn<ReturnWithDetails>>[
                          AppTableColumn<ReturnWithDetails>(
                            title: 'رقم المرتجع',
                            width: 110,
                            cellBuilder: (_, r, _) => Text(
                              r.returnNumberFormatted,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          AppTableColumn<ReturnWithDetails>(
                            title: 'نوع المرتجع',
                            width: 150,
                            cellBuilder: (_, r, _) {
                              final isSale = r.isSaleReturn;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSale
                                      ? AppColors.warningContainer
                                      : AppColors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  r.typeLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSale
                                        ? AppColors.warning
                                        : AppColors.secondary,
                                  ),
                                ),
                              );
                            },
                          ),
                          AppTableColumn<ReturnWithDetails>(
                            title: 'الطرف (العميل / المورد)',
                            width: 180,
                            cellBuilder: (_, r, _) => Text(
                              r.partyName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AppTableColumn<ReturnWithDetails>(
                            title: 'المرجع',
                            width: 120,
                            cellBuilder: (_, r, _) => Text(
                              r.referenceLabel ?? '—',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                          AppTableColumn<ReturnWithDetails>(
                            title: 'التاريخ',
                            width: 150,
                            cellBuilder: (_, r, _) => Text(
                              r.formattedDate,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          AppTableColumn<ReturnWithDetails>(
                            title: 'طريقة التسوية',
                            width: 130,
                            cellBuilder: (_, r, _) => Text(
                              r.refundMethodLabel,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          AppTableColumn<ReturnWithDetails>(
                            title: 'المبلغ المسترد',
                            width: 130,
                            cellBuilder: (_, r, _) => Text(
                              r.formattedTotalAmount,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          AppTableColumn<ReturnWithDetails>(
                            title: 'إجراءات',
                            width: 90,
                            cellBuilder: (context, r, _) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.print_outlined,
                                        size: 18),
                                    tooltip: AppStrings.printReturnReceipt,
                                    onPressed: () {
                                      ReturnPreviewDialog.show(context,
                                          returnData: r);
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                        items: returns,
                        onRowTap: (r) {
                          final current =
                              ref.read(selectedReturnIdProvider);
                          ref
                              .read(selectedReturnIdProvider.notifier)
                              .select(current == r.id ? null : r.id);
                        },
                      ),
                    ),

                    // Detail Pane
                    if (selectedReturnAsync.value != null) ...<Widget>[
                      const SizedBox(width: 16),
                      ReturnDetailsPane(
                        returnData: selectedReturnAsync.value!,
                        onClose: () {
                          ref
                              .read(selectedReturnIdProvider.notifier)
                              .select(null);
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
