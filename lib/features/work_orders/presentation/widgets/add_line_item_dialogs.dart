import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/qty_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../inventory/domain/item_with_stock.dart';
import '../../../services/presentation/widgets/services_manager_dialog.dart';
import '../../domain/work_order_line_item.dart';

/// Modal dialog for adding a service / labor line item to a work order.
class AddServiceLineDialog extends ConsumerStatefulWidget {
  const AddServiceLineDialog({
    super.key,
    required this.onAdd,
    this.initialDescription,
    this.initialPricePiasters,
  });

  final ValueChanged<WorkOrderLineItem> onAdd;
  final String? initialDescription;
  final int? initialPricePiasters;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<WorkOrderLineItem> onAdd,
    String? initialDescription,
    int? initialPricePiasters,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddServiceLineDialog(
        onAdd: onAdd,
        initialDescription: initialDescription,
        initialPricePiasters: initialPricePiasters,
      ),
    );
  }

  @override
  ConsumerState<AddServiceLineDialog> createState() => _AddServiceLineDialogState();
}

class _AddServiceLineDialogState extends ConsumerState<AddServiceLineDialog> {
  late final TextEditingController _descController;
  late int _unitPricePiasters;
  double _qty = 1.0;
  int? _selectedServiceId;
  List<Service> _services = <Service>[];

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.initialDescription ?? '');
    _unitPricePiasters = widget.initialPricePiasters ?? 0;
    _loadServices();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    final servicesRepo = ref.read(servicesRepositoryProvider);
    final all = await servicesRepo.getAll(onlyActive: true);
    if (mounted) {
      setState(() => _services = all);
    }
  }

  void _onServiceSelected(int? serviceId) {
    if (serviceId == null) return;
    final s = _services.firstWhere((it) => it.id == serviceId);
    setState(() {
      _selectedServiceId = serviceId;
      _descController.text = s.name;
      _unitPricePiasters = s.defaultPrice;
    });
  }

  void _submit() {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      AppSnackbar.showError(context, 'يرجى كتابة اسم أو وصف الخدمة / المصنعية.');
      return;
    }
    if (_unitPricePiasters < 0) {
      AppSnackbar.showError(context, 'سعر الخدمة لا يمكن أن يكون سالباً.');
      return;
    }

    final total = WorkOrderLineItem.calculateTotal(_unitPricePiasters, _qty);
    widget.onAdd(
      WorkOrderLineItem(
        lineType: LineType.service,
        serviceId: _selectedServiceId,
        description: desc,
        quantity: _qty,
        unitPrice: _unitPricePiasters,
        totalPrice: total,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: AppStrings.addServiceLine,
      maxWidth: 500,
      onSave: _submit,
      saveLabel: 'إضافة الخدمة والمصنعية',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'اختر خدمة من الدليل أو اكتب مصنعية مخصصة:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              TextButton.icon(
                onPressed: () async {
                  await ServicesManagerDialog.show(context);
                  await _loadServices();
                },
                icon: const Icon(Icons.tune_outlined, size: 14),
                label: const Text('تعديل الأسعار وإضافة خدمة', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_services.isNotEmpty) ...[
            DropdownButtonFormField<int>(
              initialValue: _selectedServiceId,
              decoration: const InputDecoration(labelText: AppStrings.selectServiceFromList),
              items: _services.map((s) {
                return DropdownMenuItem<int>(
                  value: s.id,
                  child: Text('${s.name} (${MoneyUtils.formatPounds(s.defaultPrice)})'),
                );
              }).toList(),
              onChanged: _onServiceSelected,
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: AppStrings.serviceNameOrCustom,
              hintText: 'مثال: مصنعية صيانة عفشة، تغيير تيل فرامل، فحص كمبيوتر...',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: MoneyField(
                  label: AppStrings.lineUnitPrice,
                  initialPiasters: _unitPricePiasters,
                  onChangedPiasters: (piasters) => _unitPricePiasters = piasters ?? 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: QtyField(
                  label: AppStrings.lineQty,
                  initialQty: _qty,
                  onChangedQty: (qty) => _qty = qty ?? 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal dialog for selecting and adding a warehouse spare part line item.
class AddPartLineDialog extends ConsumerStatefulWidget {
  const AddPartLineDialog({
    super.key,
    required this.onAdd,
  });

  final ValueChanged<WorkOrderLineItem> onAdd;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<WorkOrderLineItem> onAdd,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddPartLineDialog(onAdd: onAdd),
    );
  }

  @override
  ConsumerState<AddPartLineDialog> createState() => _AddPartLineDialogState();
}

class _AddPartLineDialogState extends ConsumerState<AddPartLineDialog> {
  int? _selectedItemId;
  ItemWithStock? _selectedItemWithStock;
  int _unitPricePiasters = 0;
  double _qty = 1.0;
  List<ItemWithStock> _items = <ItemWithStock>[];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final itemsRepo = ref.read(itemsRepositoryProvider);
    final all = await itemsRepo.getItemsWithStock(onlyActive: true);
    if (mounted) {
      setState(() => _items = all);
    }
  }

  void _onItemSelected(int? itemId) {
    if (itemId == null) return;
    final it = _items.firstWhere((item) => item.item.id == itemId);
    setState(() {
      _selectedItemId = itemId;
      _selectedItemWithStock = it;
      _unitPricePiasters = it.item.salePrice;
    });
  }

  void _submit() {
    if (_selectedItemWithStock == null) {
      AppSnackbar.showError(context, 'يرجى اختيار صنف من المخزن.');
      return;
    }
    if (_qty <= 0) {
      AppSnackbar.showError(context, 'يرجى إدخال كمية صحيحة أكبر من صفر.');
      return;
    }

    final it = _selectedItemWithStock!;
    final total = WorkOrderLineItem.calculateTotal(_unitPricePiasters, _qty);

    widget.onAdd(
      WorkOrderLineItem(
        lineType: LineType.part,
        itemId: it.item.id,
        description: it.item.name,
        quantity: _qty,
        unitPrice: _unitPricePiasters,
        totalPrice: total,
        itemUnit: it.item.unit,
        stockOnHand: it.stockOnHand,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: AppStrings.addPartLine,
      maxWidth: 520,
      onSave: _submit,
      saveLabel: 'تأكيد سحب الصنف',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButtonFormField<int>(
            initialValue: _selectedItemId,
            decoration: const InputDecoration(labelText: AppStrings.selectItemFromList),
            items: _items.map((it) {
              final stockLabel = '${Formatters.formatQuantity(it.stockOnHand)} ${it.item.unit}';
              return DropdownMenuItem<int>(
                value: it.item.id,
                child: Text(
                  '${it.item.name} (المتاح بالمخزن: $stockLabel - ${it.formattedSalePrice})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _onItemSelected,
          ),
          if (_selectedItemWithStock != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedItemWithStock!.isOutOfStock
                    ? AppColors.danger.withValues(alpha: 0.1)
                    : AppColors.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _selectedItemWithStock!.isOutOfStock ? Icons.warning_amber_rounded : Icons.info_outline,
                    size: 16,
                    color: _selectedItemWithStock!.isOutOfStock ? AppColors.danger : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _selectedItemWithStock!.isOutOfStock
                          ? 'تنبيه: الرصيد الحالي بالمخزن صفر. سيصبح الرصيد سالباً بعد الفاتورة.'
                          : 'الرصيد المتاح حالياً بالمخزن: ${Formatters.formatQuantity(_selectedItemWithStock!.stockOnHand)} ${_selectedItemWithStock!.item.unit}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _selectedItemWithStock!.isOutOfStock ? AppColors.danger : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: MoneyField(
                  label: AppStrings.lineUnitPrice,
                  initialPiasters: _unitPricePiasters,
                  onChangedPiasters: (p) => _unitPricePiasters = p ?? 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: QtyField(
                  label: AppStrings.lineQty,
                  initialQty: _qty,
                  onChangedQty: (q) => _qty = q ?? 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
