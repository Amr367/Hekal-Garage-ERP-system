import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/expenses_repository.dart';
import '../../core/money/money.dart';
import '../../core/services/excel_export_service.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_views.dart';
import 'presentation/expenses_controller.dart';
import 'presentation/widgets/expense_form_dialog.dart';
import 'presentation/widgets/expenses_kpi_cards.dart';

/// Main Expenses Management Page for the workshop.
class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesListProvider);
    final summaryAsync = ref.watch(expensesSummaryProvider);
    final selectedCategory = ref.watch(selectedExpenseCategoryProvider);

    return AppScaffold(
      title: AppStrings.expensesTitle,
      subtitle: AppStrings.expensesSubtitle,
      actions: [
        OutlinedButton.icon(
          onPressed: () async {
            final expenses = expensesAsync.value ?? [];
            if (expenses.isEmpty) {
              AppSnackbar.showWarning(context, 'لا توجد مصروفات لتصديرها');
              return;
            }
            final bytes = ExcelExportService.exportExpensesToExcel(
              expenses,
              categoryFilter: selectedCategory,
            );
            final now = DateTime.now();
            final defaultFileName =
                'expenses_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}.xlsx';

            await ExcelExportService.saveExcelFile(
              context: context,
              bytes: bytes,
              defaultFileName: defaultFileName,
              dialogTitle: 'تصدير المصروفات إلى Excel',
              successMessage:
                  'تم تصدير المصروفات بنجاح (${expenses.length} إيصال)',
            );
          },
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text(AppStrings.exportExcel),
        ),
        FilledButton.icon(
          onPressed: () => ExpenseFormDialog.show(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text(AppStrings.addExpense),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── KPI Cards ───────────────────────────────────────────────────
          summaryAsync.when(
            data: (summary) => ExpensesKpiCards(summary: summary),
            loading: () => const SizedBox(height: 70, child: Center(child: CircularProgressIndicator())),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // ── Search & Filter Toolbar ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 700;

                final searchField = TextField(
                  decoration: const InputDecoration(
                    hintText: 'بحث في المصروفات بالبيان، المدفوع له، أو رقم الإيصال...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                  onChanged: (val) => ref.read(expensesSearchQueryProvider.notifier).setQuery(val),
                );

                final categoryDropdown = SizedBox(
                  width: isCompact ? null : 220,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'التصنيف',
                      isDense: true,
                      prefixIcon: Icon(Icons.filter_list, size: 18),
                    ),
                    items: ['الكل', ...kCommonExpenseCategories].map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(selectedExpenseCategoryProvider.notifier).setCategory(val);
                      }
                    },
                  ),
                );

                if (isCompact) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      categoryDropdown,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 16),
                    categoryDropdown,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Expenses Data Table ─────────────────────────────────────────
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments_outlined, size: 64, color: AppColors.onSurfaceVariant.withAlpha(80)),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد مصروفات مسجلة مطابقة للبحث أو الفلتر.',
                          style: TextStyle(fontSize: 15, color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: () => ExpenseFormDialog.show(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('تسجيل أول مصروف الآن'),
                        ),
                      ],
                    ),
                  );
                }

                return AppDataTable<ExpenseWithDetails>(
                  columns: <AppTableColumn<ExpenseWithDetails>>[
                    AppTableColumn<ExpenseWithDetails>(
                      title: '#',
                      width: 50,
                      alignment: Alignment.center,
                      cellBuilder: (context, exp, index) => Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                    ),
                    AppTableColumn<ExpenseWithDetails>(
                      title: 'التاريخ',
                      width: 100,
                      cellBuilder: (context, exp, index) => Text(
                        '${exp.expenseDate.year}/${exp.expenseDate.month.toString().padLeft(2, '0')}/${exp.expenseDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    AppTableColumn<ExpenseWithDetails>(
                      title: 'التصنيف',
                      width: 140,
                      cellBuilder: (context, exp, index) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withAlpha(50),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primaryContainer),
                        ),
                        child: Text(
                          exp.category,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                    ),
                    AppTableColumn<ExpenseWithDetails>(
                      title: 'البيان / الوصف',
                      flex: 3,
                      cellBuilder: (context, exp, index) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(exp.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                          if (exp.notes != null && exp.notes!.isNotEmpty)
                            Text(exp.notes!, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    AppTableColumn<ExpenseWithDetails>(
                      title: 'المبلغ (ج.م)',
                      width: 120,
                      cellBuilder: (context, exp, index) => Text(
                        MoneyUtils.format(exp.amountPiasters, withCurrency: true),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.danger),
                      ),
                    ),
                    AppTableColumn<ExpenseWithDetails>(
                      title: 'المدفوع له',
                      width: 130,
                      cellBuilder: (context, exp, index) => Text(exp.paidTo ?? '—', style: const TextStyle(fontSize: 13)),
                    ),
                    AppTableColumn<ExpenseWithDetails>(
                      title: 'طريقة الدفع',
                      width: 100,
                      cellBuilder: (context, exp, index) {
                        final methodLabel = switch (exp.paymentMethod) {
                          PaymentMethod.cash => 'خزنة كاش',
                          PaymentMethod.instapay => 'انستاباي',
                          PaymentMethod.wallet => 'محفظة',
                          PaymentMethod.card => 'فيزا / كارت',
                          PaymentMethod.transfer => 'تحويل بنكي',
                        };
                        return Text(methodLabel, style: const TextStyle(fontSize: 12));
                      },
                    ),
                    AppTableColumn<ExpenseWithDetails>(
                      title: 'رقم الإيصال',
                      width: 90,
                      cellBuilder: (context, exp, index) => Text(exp.receiptNumber ?? '—', style: const TextStyle(fontSize: 12)),
                    ),
                    AppTableColumn<ExpenseWithDetails>(
                      title: 'إجراءات',
                      width: 100,
                      alignment: Alignment.center,
                      cellBuilder: (context, exp, index) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'تعديل',
                            onPressed: () => ExpenseFormDialog.show(context, existingExpense: exp),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                            tooltip: 'حذف',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('تأكيد حذف المصروف'),
                                  content: Text('هل أنت متأكد من حذف هذا المصروف بمبلغ "${MoneyUtils.format(exp.amountPiasters, withCurrency: true)}"؟'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('إلغاء'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('حذف'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(expensesActionsControllerProvider).deleteExpense(exp.id);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  items: expenses,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('حدث خطأ: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
