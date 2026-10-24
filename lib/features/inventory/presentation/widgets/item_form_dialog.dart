import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drift/drift.dart' as drift;
import '../../../../core/db/database.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/qty_field.dart';
import '../inventory_controller.dart';

/// Dialog for creating or editing an inventory item.
class ItemFormDialog extends ConsumerStatefulWidget {
  const ItemFormDialog({
    super.key,
    this.item,
  });

  final Item? item;

  static Future<int?> show(BuildContext context, {Item? item}) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ItemFormDialog(item: item),
    );
  }

  @override
  ConsumerState<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends ConsumerState<ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _unitController;

  int? _selectedCategoryId;
  late int _costPrice;
  late int _salePrice;
  late double _minQuantity;
  double _openingStock = 0.0;
  late bool _isActive;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _skuController = TextEditingController(text: item?.sku ?? '');
    _barcodeController = TextEditingController(text: item?.barcode ?? '');
    _unitController = TextEditingController(text: item?.unit ?? 'قطعة');

    _selectedCategoryId = item?.categoryId;
    _costPrice = item?.costPrice ?? 0;
    _salePrice = item?.salePrice ?? 0;
    _minQuantity = item?.minQuantity ?? 0.0;
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      setState(() {
        _errorMessage = 'يرجى اختيار قسم للصنف';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final actions = ref.read(inventoryActionsControllerProvider);

      if (widget.item == null) {
        // Create new item
        final newId = await actions.createItem(
          name: _nameController.text.trim(),
          categoryId: _selectedCategoryId!,
          sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
          unit: _unitController.text.trim().isEmpty ? 'قطعة' : _unitController.text.trim(),
          costPrice: _costPrice,
          salePrice: _salePrice,
          minQuantity: _minQuantity,
          openingStock: _openingStock,
        );
        if (mounted) Navigator.of(context).pop(newId);
      } else {
        // Update existing item
        final updated = widget.item!.copyWith(
          name: _nameController.text.trim(),
          categoryId: _selectedCategoryId!,
          sku: drift.Value(_skuController.text.trim().isEmpty ? null : _skuController.text.trim()),
          barcode: drift.Value(_barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim()),
          unit: _unitController.text.trim().isEmpty ? 'قطعة' : _unitController.text.trim(),
          costPrice: _costPrice,
          salePrice: _salePrice,
          minQuantity: _minQuantity,
          isActive: _isActive,
        );
        await actions.updateItem(updated);
        if (mounted) Navigator.of(context).pop(widget.item!.id);
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

  Future<void> _showQuickAddCategoryDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة قسم جديد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'اسم القسم',
            hintText: 'مثال: فلاتر وزيوت، فرامل، كهرباء',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(ctx).pop(text);
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      final actions = ref.read(inventoryActionsControllerProvider);
      final newCatId = await actions.createCategory(name);
      setState(() {
        _selectedCategoryId = newCatId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;
    final categoriesAsync = ref.watch(categoriesListProvider);

    return AppFormDialog(
      title: isEditing ? AppStrings.editItemButton : AppStrings.newItemButton,
      isLoading: _isSaving,
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
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

            // Category row with quick-add button
            categoriesAsync.when(
              data: (categories) {
                // If there is only one category or none selected yet, default to first if available
                final effectiveCategoryId = _selectedCategoryId ??
                    (categories.isNotEmpty ? categories.first.id : null);
                if (_selectedCategoryId == null && effectiveCategoryId != null) {
                  _selectedCategoryId = effectiveCategoryId;
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'القسم *',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem<int>(
                            value: cat.id,
                            child: Text(cat.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategoryId = val;
                          });
                        },
                        validator: (val) => val == null ? 'يرجى اختيار القسم' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: IconButton.outlined(
                        icon: const Icon(Icons.add),
                        tooltip: 'إضافة قسم جديد',
                        onPressed: _showQuickAddCategoryDialog,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('تعذر تحميل الأقسام'),
            ),
            const SizedBox(height: 14),

            // Item Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الصنف *',
                hintText: 'مثال: تيل فرامل أمامي كيا سيراتو',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return AppStrings.fieldRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // SKU & Barcode Row
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(
                      labelText: 'كود الصنف (SKU)',
                      hintText: 'مثال: BRK-001',
                      prefixIcon: Icon(Icons.qr_code_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'الباركود الدولي',
                      hintText: 'مثال: 6223001234567',
                      prefixIcon: Icon(Icons.barcode_reader),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Unit & Min Quantity Row
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'وحدة القياس',
                      hintText: 'قطعة، لتر، طقم، علبة...',
                      prefixIcon: Icon(Icons.straighten_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: QtyField(
                    label: AppStrings.itemMinQtyLabel,
                    initialQty: _minQuantity,
                    hintText: '0',
                    onChangedQty: (val) {
                      _minQuantity = val ?? 0.0;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Cost Price & Sale Price Row
            Row(
              children: <Widget>[
                Expanded(
                  child: MoneyField(
                    label: AppStrings.itemCostPriceLabel,
                    initialPiasters: _costPrice,
                    onChangedPiasters: (val) {
                      _costPrice = val ?? 0;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MoneyField(
                    label: AppStrings.itemSalePriceLabel,
                    initialPiasters: _salePrice,
                    onChangedPiasters: (val) {
                      _salePrice = val ?? 0;
                    },
                  ),
                ),
              ],
            ),

            // Opening stock field: only shown when creating new item
            if (!isEditing) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.add_shopping_cart, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: QtyField(
                        label: AppStrings.itemOpeningStockLabel,
                        hintText: '0',
                        initialQty: _openingStock,
                        onChangedQty: (val) {
                          _openingStock = val ?? 0.0;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Active status switch (if editing)
            if (isEditing) ...[
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('حالة الصنف'),
                subtitle: Text(_isActive ? 'نشط ومتاح في فواتير الصيانة' : 'معطل ومخفي عن أوامر الشغل'),
                value: _isActive,
                onChanged: (val) {
                  setState(() {
                    _isActive = val;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
