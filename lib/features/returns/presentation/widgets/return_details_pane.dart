import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/return_with_details.dart';
import '../returns_controller.dart';
import 'return_preview_dialog.dart';

/// Desktop right-side master-detail panel displaying Return details.
class ReturnDetailsPane extends ConsumerWidget {
  const ReturnDetailsPane({
    super.key,
    required this.returnData,
    required this.onClose,
  });

  final ReturnWithDetails returnData;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSale = returnData.isSaleReturn;
    final badgeColor = isSale ? AppColors.warning : AppColors.secondary;
    final badgeContainerColor =
        isSale ? AppColors.warningContainer : AppColors.secondaryContainer;

    return Container(
      width: 440,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 1),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeContainerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSale ? Icons.undo_outlined : Icons.replay_outlined,
                    color: badgeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: [
                          Text(
                            returnData.returnNumberFormatted,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeContainerColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              returnData.typeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        returnData.formattedDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: 'إغلاق',
                ),
              ],
            ),
          ),

          // ── Action Buttons ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ReturnPreviewDialog.show(context, returnData: returnData);
                    },
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text(AppStrings.printReturnReceipt),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text(AppStrings.deleteReturnButton),
                        content: const Text(AppStrings.confirmDeleteReturn),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('حذف واستعادة المخزون'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await ref
                            .read(returnsActionsControllerProvider)
                            .deleteReturn(returnData.id);
                        if (context.mounted) {
                          AppSnackbar.showSuccess(
                              context, AppStrings.returnDeletedSuccess);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackbar.showError(context, e.toString());
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.danger),
                  tooltip: AppStrings.deleteReturnButton,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // ── Scrollable Details & Returned Items ───────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Info Cards
                  _buildInfoRow(
                    isSale ? 'اسم العميل:' : 'اسم المورد:',
                    returnData.partyName,
                    icon: isSale ? Icons.person_outline : Icons.store_outlined,
                  ),
                  if (returnData.referenceLabel != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'الفاتورة المرجعية:',
                      returnData.referenceLabel!,
                      icon: Icons.receipt_long_outlined,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'طريقة استرداد المبلغ:',
                    returnData.refundMethodLabel,
                    icon: Icons.payments_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'تأثير المخزن:',
                    isSale
                        ? 'تم إرجاع البضاعة للمخزن (+)'
                        : 'تم خصم البضاعة من المخزن (-)',
                    icon: Icons.inventory_2_outlined,
                    valueColor: isSale ? AppColors.success : AppColors.primary,
                  ),

                  if (returnData.entry.reason != null &&
                      returnData.entry.reason!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'سبب الإرجاع:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            returnData.entry.reason!.trim(),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Text(
                    'الأصناف المرتجعة:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Returned Items Table
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Container(
                          color: AppColors.background,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text('الصنف / البيان',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text('الكمية',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('السعر',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        ...returnData.lines.map((line) {
                          final qtyStr = line.quantity % 1 == 0
                              ? line.quantity.toInt().toString()
                              : line.quantity.toString();
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: AppColors.divider, width: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    line.description,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    qtyStr,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${(line.totalPrice / 100).toStringAsFixed(2)} ج.م',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Total Summary ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'المبلغ الإجمالي المسترد:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  returnData.formattedTotalAmount,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
