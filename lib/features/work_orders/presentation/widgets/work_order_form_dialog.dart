import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../customers/presentation/widgets/customer_form_dialog.dart';
import '../../../customers/presentation/widgets/vehicle_form_dialog.dart';
import '../../../inventory/domain/item_with_stock.dart';
import '../../domain/work_order_line_item.dart';
import '../../domain/work_order_with_details.dart';
import '../work_orders_controller.dart';

/// Comprehensive modal dialog for creating or editing a work order.
class WorkOrderFormDialog extends ConsumerStatefulWidget {
  const WorkOrderFormDialog({
    super.key,
    this.order,
  });

  final WorkOrderWithDetails? order;

  static Future<void> show(BuildContext context, {WorkOrderWithDetails? order}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WorkOrderFormDialog(order: order),
    );
  }

  @override
  ConsumerState<WorkOrderFormDialog> createState() => _WorkOrderFormDialogState();
}

class _WorkOrderFormDialogState extends ConsumerState<WorkOrderFormDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedCustomerId;
  int? _selectedVehicleId;
  late final TextEditingController _odometerController;
  late final TextEditingController _complaintController;
  late final TextEditingController _mechanicController;
  late final TextEditingController _notesController;

  final List<WorkOrderLineItem> _lines = <WorkOrderLineItem>[];
  bool _isLoading = false;

  // Cached lists for dropdowns
  List<Customer> _customers = <Customer>[];
  List<Vehicle> _vehicles = <Vehicle>[];

  @override
  void initState() {
    super.initState();
    final existing = widget.order;
    if (existing != null) {
      _selectedCustomerId = existing.customer.id;
      _selectedVehicleId = existing.vehicle.id;
      _odometerController = TextEditingController(
        text: existing.workOrder.odometer?.toString() ?? '',
      );
      _complaintController = TextEditingController(
        text: existing.workOrder.complaint ?? '',
      );
      _mechanicController = TextEditingController(
        text: existing.workOrder.mechanicName ?? '',
      );
      _notesController = TextEditingController(
        text: existing.workOrder.notes ?? '',
      );
      _lines.addAll(existing.lines);
    } else {
      _odometerController = TextEditingController();
      _complaintController = TextEditingController();
      _mechanicController = TextEditingController();
      _notesController = TextEditingController();
    }

    _loadData();
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _complaintController.dispose();
    _mechanicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final customersRepo = ref.read(customersRepositoryProvider);
    final vehiclesRepo = ref.read(vehiclesRepositoryProvider);

    final allCustomers = await customersRepo.getAll(onlyActive: true);

    int? autoCustId = _selectedCustomerId;
    if (autoCustId == null && allCustomers.length == 1) {
      autoCustId = allCustomers.first.id;
    }

    List<Vehicle> initialVehicles = <Vehicle>[];
    int? autoVehId = _selectedVehicleId;
    if (autoCustId != null) {
      initialVehicles = await vehiclesRepo.getByCustomerId(autoCustId);
      if (autoVehId == null && initialVehicles.length == 1) {
        autoVehId = initialVehicles.first.id;
        if (initialVehicles.first.lastOdometer != null && _odometerController.text.isEmpty) {
          _odometerController.text = initialVehicles.first.lastOdometer.toString();
        }
      }
    }

    if (mounted) {
      setState(() {
        _customers = allCustomers;
        _selectedCustomerId = autoCustId;
        _vehicles = initialVehicles;
        _selectedVehicleId = autoVehId;
      });
    }
  }

  Future<void> _onCustomerChanged(int? customerId) async {
    setState(() {
      _selectedCustomerId = customerId;
      _selectedVehicleId = null;
      _vehicles = <Vehicle>[];
    });

    if (customerId != null) {
      final vehiclesRepo = ref.read(vehiclesRepositoryProvider);
      final custVehicles = await vehiclesRepo.getByCustomerId(customerId);
      if (mounted) {
        setState(() {
          _vehicles = custVehicles;
          if (custVehicles.length == 1) {
            _selectedVehicleId = custVehicles.first.id;
            if (custVehicles.first.lastOdometer != null && _odometerController.text.isEmpty) {
              _odometerController.text = custVehicles.first.lastOdometer.toString();
            }
          }
        });
      }
    }
  }

  Future<void> _addNewCustomer() async {
    final newId = await CustomerFormDialog.show(context);
    if (newId != null && mounted) {
      await _loadData();
      await _onCustomerChanged(newId);
    }
  }

  Future<void> _addNewVehicle() async {
    if (_selectedCustomerId == null) {
      AppSnackbar.showError(context, 'يرجى اختيار العميل أولاً قبل إضافة السيارة.');
      return;
    }

    final newId = await VehicleFormDialog.show(context, customerId: _selectedCustomerId!);
    if (newId != null && mounted) {
      final vehiclesRepo = ref.read(vehiclesRepositoryProvider);
      final custVehicles = await vehiclesRepo.getByCustomerId(_selectedCustomerId!);
      setState(() {
        _vehicles = custVehicles;
        _selectedVehicleId = newId;
      });
    }
  }

  void _addServiceLineDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddServiceDialog(
        onAdd: (line) {
          setState(() => _lines.add(line));
        },
      ),
    );
  }

  void _addPartLineDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddPartDialog(
        onAdd: (line) {
          setState(() => _lines.add(line));
        },
      ),
    );
  }

  void _removeLine(int index) {
    setState(() => _lines.removeAt(index));
  }

  int get _servicesTotal => _lines.where((l) => l.isService).fold<int>(0, (sum, l) => sum + l.totalPrice);
  int get _partsTotal => _lines.where((l) => l.isPart).fold<int>(0, (sum, l) => sum + l.totalPrice);
  int get _grandTotal => _servicesTotal + _partsTotal;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomerId == null || _selectedVehicleId == null) {
      AppSnackbar.showError(context, AppStrings.customerVehicleRequired);
      return;
    }

    int? odo;
    if (_odometerController.text.trim().isNotEmpty) {
      odo = int.tryParse(_odometerController.text.trim());
    }

    setState(() => _isLoading = true);

    try {
      final actions = ref.read(workOrdersActionsControllerProvider);

      if (widget.order == null) {
        // Create new
        await actions.createWorkOrder(
          customerId: _selectedCustomerId!,
          vehicleId: _selectedVehicleId!,
          odometer: odo,
          complaint: _complaintController.text.trim(),
          mechanicName: _mechanicController.text.trim().isEmpty ? null : _mechanicController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          lines: _lines,
        );
        if (mounted) {
          Navigator.of(context).pop();
          AppSnackbar.showSuccess(context, 'تم فتح أمر الشغل بنجاح');
        }
      } else {
        // Update existing
        await actions.updateWorkOrder(
          id: widget.order!.id,
          odometer: odo,
          complaint: _complaintController.text.trim(),
          mechanicName: _mechanicController.text.trim().isEmpty ? null : _mechanicController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          lines: _lines,
        );
        if (mounted) {
          Navigator.of(context).pop();
          AppSnackbar.showSuccess(context, 'تم حفظ تعديلات أمر الشغل بنجاح');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.order != null;

    return AppFormDialog(
      title: isEditing
          ? '${AppStrings.editWorkOrderButton} ${widget.order!.orderNumberFormatted}'
          : AppStrings.newWorkOrderButton,
      maxWidth: 820,
      isLoading: _isLoading,
      onSave: _save,
      saveLabel: isEditing ? 'حفظ التعديلات' : 'فتح أمر الشغل',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Section 1: Customer & Vehicle Selection ──────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.directions_car_filled_outlined, size: 18, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'بيانات العميل والمركبة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Customer Dropdown
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          key: ValueKey<String>('customer_$_selectedCustomerId'),
                          isExpanded: true,
                          initialValue: _customers.any((c) => c.id == _selectedCustomerId) ? _selectedCustomerId : null,
                          decoration: InputDecoration(
                            labelText: AppStrings.selectCustomer,
                            suffixIcon: !isEditing
                                ? IconButton(
                                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                                    tooltip: 'تسجيل عميل جديد',
                                    onPressed: _addNewCustomer,
                                  )
                                : null,
                          ),
                          items: _customers.map((c) {
                            return DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(
                                '${c.name} ${c.phone != null ? "(${c.phone})" : ""}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: isEditing ? null : _onCustomerChanged,
                          validator: (val) => val == null ? 'يرجى اختيار العميل' : null,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Vehicle Dropdown
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          key: ValueKey<String>('vehicle_$_selectedVehicleId'),
                          isExpanded: true,
                          initialValue: _vehicles.any((v) => v.id == _selectedVehicleId) ? _selectedVehicleId : null,
                          decoration: InputDecoration(
                            labelText: AppStrings.selectVehicle,
                            suffixIcon: !isEditing
                                ? IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    tooltip: 'إضافة سيارة جديدة لهذا العميل',
                                    onPressed: _addNewVehicle,
                                  )
                                : null,
                          ),
                          items: _vehicles.map((v) {
                            final plate = Formatters.normalizePlateNumber(v.plateNumber);
                            final info = '${v.make} ${v.model} ($plate)';
                            return DropdownMenuItem<int>(
                              value: v.id,
                              child: Text(info, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: isEditing
                              ? null
                              : (val) {
                                  setState(() => _selectedVehicleId = val);
                                },
                          validator: (val) => val == null ? 'يرجى اختيار السيارة' : null,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Odometer
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _odometerController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: AppStrings.odometerLabel,
                            suffixText: 'كم',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Section 2: Complaint, Mechanic & Diagnostic Notes ────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Complaint
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _complaintController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: AppStrings.complaintLabel,
                      hintText: AppStrings.complaintHint,
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? AppStrings.complaintRequired : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Mechanic Name
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _mechanicController,
                    decoration: const InputDecoration(
                      labelText: AppStrings.mechanicLabel,
                      hintText: AppStrings.mechanicHint,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: AppStrings.orderNotesLabel,
                hintText: 'ملاحظات الفحص، الخدوش الخارجية، أو تعليمات إضافية...',
              ),
            ),
            const SizedBox(height: 14),

            // ── Section 3: Services & Spare Parts Lines Editor ───────────
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: <Widget>[
                  // Lines Toolbar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.build_circle_outlined, size: 18, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              AppStrings.servicesAndParts,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: _addServiceLineDialog,
                              icon: const Icon(Icons.handyman_outlined, size: 16),
                              label: const Text(AppStrings.addServiceLine),
                            ),
                            OutlinedButton.icon(
                              onPressed: _addPartLineDialog,
                              icon: const Icon(Icons.inventory_2_outlined, size: 16),
                              label: const Text(AppStrings.addPartLine),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Lines List / Table
                  if (_lines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          AppStrings.noLinesAdded,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _lines.length,
                      separatorBuilder: (ctx, idx) => const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (ctx, index) {
                        final line = _lines[index];
                        final isService = line.isService;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: <Widget>[
                              // Type Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isService
                                      ? AppColors.primaryContainer.withValues(alpha: 0.5)
                                      : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isService ? 'خدمة' : 'قطعة غيار',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isService ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Description
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      line.description,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    if (line.itemUnit != null)
                                      Text(
                                        'الوحدة: ${line.itemUnit}',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),

                              // Qty
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'الكمية: ${line.formattedQuantity}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),

                              // Unit Price
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'السعر: ${line.formattedUnitPrice}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),

                              // Total Price
                              Expanded(
                                flex: 2,
                                child: Text(
                                  line.formattedTotalPrice,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),

                              // Delete Action
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                tooltip: 'حذف البند',
                                onPressed: () => _removeLine(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  // Bottom Totals Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          '${AppStrings.servicesSubtotal} ${MoneyUtils.formatPounds(_servicesTotal)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          '${AppStrings.partsSubtotal} ${MoneyUtils.formatPounds(_partsTotal)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text(
                              AppStrings.grandTotal,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              MoneyUtils.formatPounds(_grandTotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for adding a service / labor line item.
class _AddServiceDialog extends ConsumerStatefulWidget {
  const _AddServiceDialog({required this.onAdd});

  final ValueChanged<WorkOrderLineItem> onAdd;

  @override
  ConsumerState<_AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends ConsumerState<_AddServiceDialog> {
  final _descController = TextEditingController();
  int _unitPricePiasters = 0;
  double _qty = 1.0;
  int? _selectedServiceId;
  List<Service> _services = <Service>[];

  @override
  void initState() {
    super.initState();
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
      AppSnackbar.showError(context, 'يرجى كتابة اسم أو وصف الخدمة.');
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
      maxWidth: 480,
      onSave: _submit,
      saveLabel: 'إضافة الخدمة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
              hintText: 'مثال: مصنعية تغيير تيل فرامل، فحص كمبيوتر...',
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

/// Dialog for selecting and adding a warehouse spare part line item.
class _AddPartDialog extends ConsumerStatefulWidget {
  const _AddPartDialog({required this.onAdd});

  final ValueChanged<WorkOrderLineItem> onAdd;

  @override
  ConsumerState<_AddPartDialog> createState() => _AddPartDialogState();
}

class _AddPartDialogState extends ConsumerState<_AddPartDialog> {
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
      maxWidth: 500,
      onSave: _submit,
      saveLabel: 'صرف الصنف',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButtonFormField<int>(
            initialValue: _selectedItemId,
            decoration: const InputDecoration(labelText: AppStrings.selectItemFromList),
            items: _items.map((it) {
              final stockLabel = '${it.stockOnHand} ${it.item.unit}';
              return DropdownMenuItem<int>(
                value: it.item.id,
                child: Text(
                  '${it.item.name} (المتاح: $stockLabel - ${it.formattedSalePrice})',
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
                  const SizedBox(width: 8),
                  Text(
                    'الرصيد المتاح بالمخزن: ${_selectedItemWithStock!.stockOnHand} ${_selectedItemWithStock!.item.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _selectedItemWithStock!.isOutOfStock ? AppColors.danger : AppColors.primary,
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
