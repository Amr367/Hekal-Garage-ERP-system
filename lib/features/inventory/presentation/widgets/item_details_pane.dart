import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../settings/data/pin_auth_service.dart';
import '../../../settings/presentation/settings_controller.dart';
import '../../domain/item_with_stock.dart';
import '../../domain/stock_movement_entry.dart';
import '../inventory_controller.dart';
import 'item_form_dialog.dart';
import 'item_ledger_dialog.dart';
import 'stock_adjustment_dialog.dart';

/// Detailed right-side pane displaying the selected item's metadata,
/// stock levels, pricing with PIN-protected cost reveal, and quick actions.
class ItemDetailsPane extends ConsumerWidget {
  const ItemDetailsPane({
    super.key,
    required this.itemWithStock,
  });

  final ItemWithStock? itemWithStock;

  Future<void> _handleRevealCost(BuildContext context, WidgetRef ref) async {
    final authService = ref.read(pinAuthServiceProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final requirePin = await settingsRepo.getBool(PinAuthService.keyRequireCostPrice, true);

    if (requirePin) {
      if (!context.mounted) return;
      final authorized = await authService.checkPermission(
        context,
        prompt: 'أدخل رمز PIN لكشف سعر التكلفة وهوامش الربح',
      );
      if (authorized) {
        ref.read(inventoryCostPriceRevealedProvider.notifier).reveal();
      }
    } else {
      ref.read(inventoryCostPriceRevealedProvider.notifier).toggle();
    }
  }

  Future<void> _toggleItemActive(BuildContext context, WidgetRef ref, ItemWithStock it) async {
    final actions = ref.read(inventoryActionsControllerProvider);
    if (it.item.isActive) {
      final confirmed = await ConfirmDialog.show(
        context: context,
        title: AppStrings.deactivateItemButton,
        message: 'هل أنت متأكد من تعطيل هذا الصنف؟ لن يظهر في فواتير البيع أو الصيانة الجديدة.',
        confirmLabel: 'تعطيل الصنف',
        isDestructive: true,
      );
      if (confirmed == true && context.mounted) {
        await actions.deactivateItem(it.item.id);
        if (context.mounted) {
          AppSnackbar.showSuccess(context, 'تم تعطيل الصنف');
        }
      }
    } else {
      await actions.activateItem(it.item);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, 'تم تفعيل الصنف بنجاح');
      }
    }
  }

  Future<void> _deleteItem(BuildContext context, WidgetRef ref, ItemWithStock it) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: AppStrings.deleteItemButton,
      message: 'هل أنت متأكد من حذف صنف "${it.item.name}" نهائياً؟',
      confirmLabel: AppStrings.delete,
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        final actions = ref.read(inventoryActionsControllerProvider);
        await actions.deleteItem(it.item.id);
        if (context.mounted) {
          AppSnackbar.showSuccess(context, AppStrings.itemDeletedSuccess);
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackbar.showError(context, e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (itemWithStock == null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'اختر صنفاً من القائمة لعرض تفاصيله وكارت الحركة',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final it = itemWithStock!;
    final item = it.item;
    final costRevealed = ref.watch(inventoryCostPriceRevealedProvider);
    final ledgerAsync = ref.watch(itemLedgerProvider(item.id));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 26,
                backgroundColor: it.isOutOfStock
                    ? AppColors.dangerContainer
                    : (it.isLowStock ? AppColors.warningContainer : AppColors.primaryContainer),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 26,
                  color: it.isOutOfStock
                      ? AppColors.danger
                      : (it.isLowStock ? AppColors.warning : AppColors.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            it.categoryName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (item.sku != null && item.sku!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SKU: ${item.sku}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.isActive
                                ? AppColors.successContainer
                                : AppColors.dangerContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.isActive ? 'نشط' : 'معطل',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: item.isActive ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stock Status Card
          Card(
            elevation: 0,
            color: it.isOutOfStock
                ? AppColors.dangerContainer.withValues(alpha: 0.4)
                : (it.isLowStock
                    ? AppColors.warningContainer.withValues(alpha: 0.4)
                    : AppColors.successContainer.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: it.isOutOfStock
                    ? AppColors.danger.withValues(alpha: 0.3)
                    : (it.isLowStock
                        ? AppColors.warning.withValues(alpha: 0.3)
                        : AppColors.success.withValues(alpha: 0.3)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          AppStrings.itemCurrentStockLabel,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${it.stockOnHand} ${item.unit}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: it.isOutOfStock
                                ? AppColors.danger
                                : (it.isLowStock ? AppColors.warning : AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.border,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          AppStrings.itemMinQtyLabel,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.minQuantity} ${item.unit}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pricing & Valuation Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.attach_money, size: 20, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Text(
                        'بيانات التسعير والربحية',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          costRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: costRevealed ? 'إخفاء سعر التكلفة' : AppStrings.revealCostPriceTooltip,
                        onPressed: () {
                          if (costRevealed) {
                            ref.read(inventoryCostPriceRevealedProvider.notifier).hide();
                          } else {
                            _handleRevealCost(context, ref);
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildPriceRow(
                    label: AppStrings.itemSalePriceLabel,
                    value: it.formattedSalePrice,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 8),
                  _buildPriceRow(
                    label: AppStrings.itemCostPriceLabel,
                    value: costRevealed ? it.formattedCostPrice : AppStrings.costPriceHidden,
                    color: costRevealed ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                  if (costRevealed) ...[
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      label: AppStrings.itemProfitMarginLabel,
                      value: '${it.profitMarginPercentage.toStringAsFixed(1)}%',
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      label: 'قيمة الرصيد الحالي (بالتكلفة)',
                      value: it.formattedStockValueCost,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildPriceRow(
                    label: 'قيمة الرصيد المتوقعة (بالبيع)',
                    value: it.formattedStockValueSale,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => ItemFormDialog.show(context, item: item),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text(AppStrings.editItemButton),
              ),
              FilledButton.tonalIcon(
                onPressed: () => StockAdjustmentDialog.show(context, itemWithStock: it),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text(AppStrings.stockAdjustmentButton),
              ),
              OutlinedButton.icon(
                onPressed: () => ItemLedgerDialog.show(context, itemWithStock: it),
                icon: const Icon(Icons.history_edu_outlined, size: 16),
                label: const Text(AppStrings.itemLedgerButton),
              ),
              OutlinedButton.icon(
                onPressed: () => _toggleItemActive(context, ref, it),
                icon: Icon(
                  item.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                  size: 16,
                  color: item.isActive ? AppColors.warning : AppColors.success,
                ),
                label: Text(
                  item.isActive ? AppStrings.deactivateItemButton : AppStrings.activateItemButton,
                  style: TextStyle(
                    color: item.isActive ? AppColors.warning : AppColors.success,
                  ),
                ),
              ),
              IconButton.outlined(
                onPressed: () => _deleteItem(context, ref, it),
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                tooltip: AppStrings.deleteItemButton,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Recent Movements Preview
          const Row(
            children: <Widget>[
              Icon(Icons.history, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text(
                'آخر الحركات المخزنية المسجلة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ledgerAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'لا توجد حركات مخزنية مسجلة حتى الآن',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                );
              }

              final previewEntries = entries.take(3).toList();
              return Column(
                children: previewEntries.map((e) => _buildMiniMovementRow(e, item.unit)).toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text('تعذر تحميل الحركات'),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow({
    required String label,
    required String value,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMovementRow(StockMovementEntry entry, String unit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (entry.isPositive ? AppColors.success : AppColors.danger)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.typeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: entry.isPositive ? AppColors.success : AppColors.danger,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.formattedDate,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          Text(
            '${entry.formattedQty} $unit',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: entry.isPositive ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
