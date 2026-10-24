import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/qty_field.dart';
import '../../../settings/data/pin_auth_service.dart';
import '../../../settings/presentation/settings_controller.dart';
import '../../domain/item_with_stock.dart';
import '../inventory_controller.dart';

/// Dialog for recording manual stock adjustments (تسوية مخزنية)
/// with PIN protection check per Rule R12 and negative stock check per Rule R4.
class StockAdjustmentDialog extends ConsumerStatefulWidget {
  const StockAdjustmentDialog({
    super.key,
    required this.itemWithStock,
  });

  final ItemWithStock itemWithStock;

  static Future<bool?> show(
    BuildContext context, {
    required ItemWithStock itemWithStock,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StockAdjustmentDialog(itemWithStock: itemWithStock),
    );
  }

  @override
  ConsumerState<StockAdjustmentDialog> createState() =>
      _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;

  bool _isAdd = true; // true = addition (+), false = deduction (-)
  double _qty = 1.0;
  late int _unitCost;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _unitCost = widget.itemWithStock.item.costPrice;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_qty <= 0) {
      setState(() {
        _errorMessage = 'يجب أن تكون كمية التسوية أكبر من صفر';
      });
      return;
    }

    // Check Rule R12: PIN check for manual stock adjustments
    final authService = ref.read(pinAuthServiceProvider);
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final requirePin = await settingsRepo.getBool(
      PinAuthService.keyRequireStockAdjust,
      true,
    );

    if (requirePin) {
      if (!mounted) return;
      final authorized = await authService.checkPermission(
        context,
        prompt: 'أدخل رمز PIN لتأكيد عملية التسوية المخزنية',
      );
      if (!authorized) {
        return; // PIN cancelled or failed
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final actions = ref.read(inventoryActionsControllerProvider);
      await actions.adjustStock(
        itemId: widget.itemWithStock.item.id,
        qty: _qty,
        isAdd: _isAdd,
        unitCost: _unitCost,
        notes: _reasonController.text.trim().isEmpty
            ? (_isAdd ? 'تسوية مخزنية (إضافة)' : 'تسوية مخزنية (خصم عجز)')
            : _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.itemWithStock.item;
    final currentStock = widget.itemWithStock.stockOnHand;

    return AppFormDialog(
      title: AppStrings.stockAdjustmentButton,
      isLoading: _isSaving,
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Item Info Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: <Widget>[
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'كود: ${item.sku ?? "بدون كود"} | القسم: ${widget.itemWithStock.categoryName}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      const Text(
                        AppStrings.itemCurrentStockLabel,
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        '$currentStock ${item.unit}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Adjustment Type Segmented Buttons
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: true,
                  label: Text(AppStrings.adjustmentTypeAdd),
                  icon: Icon(Icons.add_circle_outline, color: AppColors.success),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text(AppStrings.adjustmentTypeDeduct),
                  icon: Icon(Icons.remove_circle_outline, color: AppColors.danger),
                ),
              ],
              selected: {_isAdd},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  _isAdd = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Quantity Field
            QtyField(
              label: AppStrings.adjustmentQtyLabel,
              initialQty: _qty,
              unitSuffix: item.unit,
              hintText: '1',
              onChangedQty: (val) {
                _qty = val ?? 0.0;
              },
            ),
            const SizedBox(height: 14),

            // Unit Cost snapshot
            MoneyField(
              label: 'سعر التكلفة للحركة (ج.م)',
              initialPiasters: _unitCost,
              onChangedPiasters: (val) {
                _unitCost = val ?? 0;
              },
            ),
            const SizedBox(height: 14),

            // Reason / Notes
            TextFormField(
              controller: _reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: AppStrings.adjustmentReasonLabel,
                hintText: 'مثال: تلف أثناء النقل، هالك، تسوية فروقات جرد...',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'يرجى توضيح سبب التسوية';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
