import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/excel_export_service.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/state_views.dart';
import 'domain/item_with_stock.dart';
import 'presentation/inventory_controller.dart';
import 'presentation/widgets/categories_management_dialog.dart';
import 'presentation/widgets/import_inventory_dialog.dart';
import 'presentation/widgets/inventory_kpi_cards.dart';
import 'presentation/widgets/item_details_pane.dart';
import 'presentation/widgets/item_form_dialog.dart';
import 'presentation/widgets/item_ledger_dialog.dart';
import 'presentation/widgets/stock_adjustment_dialog.dart';

/// Complete desktop Inventory Management page (المخزن والأصناف والأقسام).
class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(inventoryListProvider);
    final summaryAsync = ref.watch(inventorySummaryProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final selectedId = ref.watch(selectedInventoryItemIdProvider);
    final selectedItem = ref.watch(selectedItemWithStockProvider);
    final onlyLowStock = ref.watch(inventoryLowStockFilterProvider);
    final selectedCategoryId = ref.watch(inventorySelectedCategoryProvider);
    final costRevealed = ref.watch(inventoryCostPriceRevealedProvider);

    return AppScaffold(
      title: AppStrings.inventoryTitle,
      subtitle: AppStrings.inventorySubtitle,
      actions: <Widget>[
        // Export Inventory to Excel Button
        FilledButton.tonalIcon(
          onPressed: () async {
            final items = listAsync.value ?? [];
            if (items.isEmpty) {
              AppSnackbar.showWarning(context, 'لا توجد أصناف لتصديرها');
              return;
            }
            final categories = categoriesAsync.value ?? [];
            final categoryName = selectedCategoryId != null
                ? categories
                    .where((c) => c.id == selectedCategoryId)
                    .firstOrNull
                    ?.name
                : null;

            final bytes = ExcelExportService.exportInventoryItemsToExcel(
              items,
              categoryFilterName: categoryName,
            );
            final now = DateTime.now();
            final defaultFileName =
                'inventory_items_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}.xlsx';

            await ExcelExportService.saveExcelFile(
              context: context,
              bytes: bytes,
              defaultFileName: defaultFileName,
              dialogTitle: 'تصدير كشف أصناف المخزن إلى Excel',
              successMessage:
                  'تم تصدير كشف المخزن بنجاح (${items.length} صنف)',
            );
          },
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text(AppStrings.exportExcel),
        ),

        // Import Inventory from Excel Button
        OutlinedButton.icon(
          onPressed: () => ImportInventoryDialog.show(context),
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: const Text('استيراد من Excel'),
        ),

        // Manage Categories Button
        OutlinedButton.icon(
          onPressed: () => CategoriesManagementDialog.show(context),
          icon: const Icon(Icons.category_outlined, size: 18),
          label: const Text(AppStrings.manageCategoriesButton),
        ),

        // Add Item Button
        ElevatedButton.icon(
          onPressed: () => ItemFormDialog.show(context),
          icon: const Icon(Icons.add_box_outlined, size: 18),
          label: const Text(AppStrings.newItemButton),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── KPI Summary Cards ─────────────────────────────────────────────
          summaryAsync.when(
            data: (summary) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InventoryKpiCards(summary: summary),
            ),
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // ── Filter Toolbar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: <Widget>[
                // Search by name, SKU, or barcode
                Expanded(
                  child: SearchField(
                    hintText: AppStrings.inventorySearchHint,
                    onChanged: (val) {
                      ref.read(inventorySearchQueryProvider.notifier).set(val);
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Category Filter Dropdown
                categoriesAsync.when(
                  data: (categories) {
                    return Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: selectedCategoryId,
                          hint: const Text(AppStrings.allCategories, style: TextStyle(fontSize: 13)),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text(AppStrings.allCategories, style: TextStyle(fontSize: 13)),
                            ),
                            ...categories.map((c) => DropdownMenuItem<int?>(
                                  value: c.id,
                                  child: Text(c.name, style: const TextStyle(fontSize: 13)),
                                )),
                          ],
                          onChanged: (val) {
                            ref.read(inventorySelectedCategoryProvider.notifier).set(val);
                          },
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(width: 12),

                // Low stock filter chip
                FilterChip(
                  selected: onlyLowStock,
                  showCheckmark: false,
                  avatar: Icon(
                    onlyLowStock ? Icons.warning_amber_rounded : Icons.filter_list,
                    size: 16,
                    color: onlyLowStock ? AppColors.warning : AppColors.textSecondary,
                  ),
                  label: Text(
                    AppStrings.filterLowStockOnly,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: onlyLowStock ? FontWeight.bold : FontWeight.normal,
                      color: onlyLowStock ? AppColors.warning : AppColors.textPrimary,
                    ),
                  ),
                  onSelected: (val) {
                    ref.read(inventoryLowStockFilterProvider.notifier).set(val);
                  },
                ),
              ],
            ),
          ),

          // ── Split Master-Detail Layout ────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1000;

                return listAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: ErrorState(
                      title: AppStrings.genericError,
                      message: err.toString(),
                      onRetry: () => ref.read(inventoryListProvider.notifier).refresh(),
                    ),
                  ),
                  data: (items) {
                    final tableWidget = _buildItemsTable(
                      context,
                      ref,
                      items,
                      selectedId,
                      costRevealed,
                    );

                    if (!isWide) {
                      return tableWidget;
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          flex: 6,
                          child: tableWidget,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: ItemDetailsPane(itemWithStock: selectedItem),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(
    BuildContext context,
    WidgetRef ref,
    List<ItemWithStock> items,
    int? selectedId,
    bool costRevealed,
  ) {
    if (items.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: EmptyState(
            title: 'لا توجد أصناف مطابقة للبحث',
            subtitle: 'يمكنك إضافة أصناف جديدة بالضغط على زر "إضافة صنف جديد" بالأعلى',
            icon: Icons.inventory_2_outlined,
          ),
        ),
      );
    }

    return AppDataTable<ItemWithStock>(
      items: items,
      rowHeight: 52,
      onRowTap: (itemWithStock) {
        ref.read(selectedInventoryItemIdProvider.notifier).set(itemWithStock.item.id);
      },
      columns: <AppTableColumn<ItemWithStock>>[
        // SKU Column
        AppTableColumn<ItemWithStock>(
          title: 'كود الصنف (SKU)',
          width: 120,
          cellBuilder: (context, it, index) {
            final sku = it.item.sku;
            return Text(
              sku != null && sku.isNotEmpty ? sku : '-',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            );
          },
        ),

        // Item Name & Category
        AppTableColumn<ItemWithStock>(
          title: 'اسم الصنف',
          flex: 2,
          cellBuilder: (context, it, index) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        it.item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration: it.item.isActive ? null : TextDecoration.lineThrough,
                          color: it.item.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!it.item.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'معطل',
                          style: TextStyle(fontSize: 10, color: AppColors.danger),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  it.categoryName,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            );
          },
        ),

        // Stock on Hand Column with Stock Level Badge
        AppTableColumn<ItemWithStock>(
          title: 'الرصيد المتاح',
          width: 140,
          cellBuilder: (context, it, index) {
            final color = it.isOutOfStock
                ? AppColors.danger
                : (it.isLowStock ? AppColors.warning : AppColors.success);

            return Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${it.stockOnHand} ${it.item.unit}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ],
            );
          },
        ),

        // Min Qty Column
        AppTableColumn<ItemWithStock>(
          title: 'حد الطلب',
          width: 90,
          cellBuilder: (context, it, index) => Text(
            '${it.item.minQuantity}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),

        // Sale Price Column
        AppTableColumn<ItemWithStock>(
          title: 'سعر البيع',
          width: 120,
          cellBuilder: (context, it, index) => Text(
            it.formattedSalePrice,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.success,
            ),
          ),
        ),

        // Cost Price Column
        AppTableColumn<ItemWithStock>(
          title: 'سعر التكلفة',
          width: 120,
          cellBuilder: (context, it, index) => Text(
            costRevealed ? it.formattedCostPrice : AppStrings.costPriceHidden,
            style: TextStyle(
              fontSize: 12,
              color: costRevealed ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),

        // Actions Column
        AppTableColumn<ItemWithStock>(
          title: AppStrings.tableActions,
          width: 125,
          cellBuilder: (context, it, index) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  tooltip: AppStrings.editItemButton,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => ItemFormDialog.show(context, item: it.item),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  tooltip: AppStrings.stockAdjustmentButton,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => StockAdjustmentDialog.show(context, itemWithStock: it),
                ),
                IconButton(
                  icon: const Icon(Icons.history_edu_outlined, size: 16),
                  tooltip: AppStrings.itemLedgerButton,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => ItemLedgerDialog.show(context, itemWithStock: it),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
