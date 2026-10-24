import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../domain/item_with_stock.dart';
import '../../domain/stock_movement_entry.dart';
import '../inventory_controller.dart';

/// Dialog displaying the full stock movement card (كارت حركة الصنف)
/// showing all historical ins, outs, adjustments, and cumulative running balance.
class ItemLedgerDialog extends ConsumerWidget {
  const ItemLedgerDialog({
    super.key,
    required this.itemWithStock,
  });

  final ItemWithStock itemWithStock;

  static Future<void> show(
    BuildContext context, {
    required ItemWithStock itemWithStock,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ItemLedgerDialog(itemWithStock: itemWithStock),
    );
  }

  Color _movementColor(StockMovementEntry entry) {
    if (entry.isPositive) return AppColors.success;
    if (entry.isNegative) return AppColors.danger;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = itemWithStock.item;
    final ledgerAsync = ref.watch(itemLedgerProvider(item.id));

    return AppFormDialog(
      title: '${AppStrings.stockLedgerTitle} - ${item.name}',
      maxWidth: 860,
      showSaveButton: false,
      cancelLabel: AppStrings.close,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Item Overview Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'كود SKU: ${item.sku ?? "بدون كود"} | الباركود: ${item.barcode ?? "غير مسجل"} | القسم: ${itemWithStock.categoryName}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Text(
                        'الرصيد الحالي بالمخزن: ',
                        style: TextStyle(fontSize: 12, color: AppColors.primary),
                      ),
                      Text(
                        '${itemWithStock.stockOnHand} ${item.unit}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ledger Table
          ledgerAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: Text('لا توجد حركات مخزنية مسجلة لهذا الصنف حتى الآن')),
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 460),
                child: AppDataTable<StockMovementEntry>(
                  items: entries,
                  columns: <AppTableColumn<StockMovementEntry>>[
                    AppTableColumn<StockMovementEntry>(
                      title: 'التاريخ والوقت',
                      width: 140,
                      cellBuilder: (context, entry, index) => Text(
                        entry.formattedDate,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    AppTableColumn<StockMovementEntry>(
                      title: 'نوع الحركة',
                      width: 120,
                      cellBuilder: (context, entry, index) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _movementColor(entry).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.typeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _movementColor(entry),
                            ),
                          ),
                        );
                      },
                    ),
                    AppTableColumn<StockMovementEntry>(
                      title: 'الكمية (+ / -)',
                      width: 110,
                      cellBuilder: (context, entry, index) => Text(
                        '${entry.formattedQty} ${item.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _movementColor(entry),
                        ),
                      ),
                    ),
                    AppTableColumn<StockMovementEntry>(
                      title: AppStrings.balanceAfterLabel,
                      width: 120,
                      cellBuilder: (context, entry, index) => Text(
                        '${entry.formattedBalanceAfter} ${item.unit}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    AppTableColumn<StockMovementEntry>(
                      title: 'تكلفة الوحدة',
                      width: 110,
                      cellBuilder: (context, entry, index) => Text(
                        entry.formattedUnitCost,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    AppTableColumn<StockMovementEntry>(
                      title: 'البيان والملاحظات',
                      flex: 2,
                      cellBuilder: (context, entry, index) => Text(
                        entry.movement.notes?.isNotEmpty == true
                            ? entry.movement.notes!
                            : (entry.movement.refType != null
                                ? 'مرجع: ${entry.movement.refType} #${entry.movement.refId ?? ""}'
                                : '-'),
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(36),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('خطأ في تحميل كارت الحركة: $err',
                    style: const TextStyle(color: AppColors.danger)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
