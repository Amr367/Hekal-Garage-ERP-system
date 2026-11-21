import 'dart:async';
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
import '../../../../core/widgets/state_views.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/db/repositories/employees_repository.dart';
import '../../../customers/domain/customer_summary.dart';
import '../../../customers/presentation/widgets/customer_form_dialog.dart';
import '../../../customers/presentation/widgets/vehicle_form_dialog.dart';
import '../../../employees/presentation/widgets/employee_form_dialog.dart';
import '../../../services/presentation/widgets/services_manager_dialog.dart';
import '../../../settings/presentation/settings_controller.dart';
import '../../domain/work_order_line_item.dart';
import '../../domain/work_order_with_details.dart';
import '../printing/job_card_builder.dart';
import '../work_orders_controller.dart';
import 'add_line_item_dialogs.dart';

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
  Customer? _selectedCustomer;
  CustomerSummary? _customerSummary;
  WorkOrderWithDetails? _lastWorkOrder;
  bool _isLoadingCustomerHistory = false;

  late final TextEditingController _customerSearchController;
  List<Customer> _searchResults = <Customer>[];
  bool _isSearchingCustomer = false;
  Timer? _searchDebounceTimer;

  int? _selectedVehicleId;
  int? _selectedEmployeeId;
  bool _isCustomMechanic = false;
  late final TextEditingController _customMechanicController;
  late final TextEditingController _odometerController;
  late final TextEditingController _complaintController;
  late final TextEditingController _notesController;

  late DateTime _entryDate;
  DateTime? _expectedExitDate;

  final List<WorkOrderLineItem> _lines = <WorkOrderLineItem>[];
  bool _isLoading = false;

  // Cached lists for dropdowns
  List<Vehicle> _vehicles = <Vehicle>[];
  List<EmployeeWithStats> _employees = <EmployeeWithStats>[];

  @override
  void initState() {
    super.initState();
    final existing = widget.order;
    if (existing != null) {
      _selectedCustomerId = existing.customer.id;
      _selectedCustomer = existing.customer;
      _customerSearchController = TextEditingController(text: existing.customer.name);
      _selectedVehicleId = existing.vehicle.id;
      _entryDate = existing.entryDate;
      _expectedExitDate = existing.expectedExitDate;
      _odometerController = TextEditingController(
        text: existing.workOrder.odometer?.toString() ?? '',
      );
      _complaintController = TextEditingController(
        text: existing.workOrder.complaint ?? '',
      );
      _customMechanicController = TextEditingController(
        text: existing.workOrder.mechanicName ?? '',
      );
      _notesController = TextEditingController(
        text: existing.workOrder.notes ?? '',
      );
      _lines.addAll(existing.lines);
    } else {
      _entryDate = DateTime.now();
      _expectedExitDate = null;
      _customerSearchController = TextEditingController();
      _odometerController = TextEditingController();
      _complaintController = TextEditingController();
      _customMechanicController = TextEditingController();
      _notesController = TextEditingController();
    }

    _loadData();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _customerSearchController.dispose();
    _odometerController.dispose();
    _complaintController.dispose();
    _customMechanicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final customersRepo = ref.read(customersRepositoryProvider);
    final vehiclesRepo = ref.read(vehiclesRepositoryProvider);
    final employeesRepo = ref.read(employeesRepositoryProvider);
    final workOrdersRepo = ref.read(workOrdersRepositoryProvider);

    final allEmployees = await employeesRepo.getAllEmployees(activeOnly: true);

    int? autoEmpId = _selectedEmployeeId;
    bool isCustom = _isCustomMechanic;

    if (autoEmpId == null && !isCustom) {
      final existingName = widget.order?.workOrder.mechanicName?.trim();
      if (existingName != null && existingName.isNotEmpty) {
        final match = allEmployees.where((e) => e.name == existingName).firstOrNull;
        if (match != null) {
          autoEmpId = match.id;
          isCustom = false;
        } else {
          autoEmpId = -1;
          isCustom = true;
          _customMechanicController.text = existingName;
        }
      } else if (allEmployees.length == 1 && widget.order == null) {
        autoEmpId = allEmployees.first.id;
      }
    }

    Customer? loadedCust = _selectedCustomer;
    CustomerSummary? loadedSummary;
    WorkOrderWithDetails? loadedLastOrder;
    List<Vehicle> initialVehicles = <Vehicle>[];
    int? autoVehId = _selectedVehicleId;

    if (_selectedCustomerId != null) {
      loadedCust ??= await customersRepo.getById(_selectedCustomerId!);
      loadedSummary = await customersRepo.getCustomerSummary(_selectedCustomerId!);
      initialVehicles = await vehiclesRepo.getByCustomerId(_selectedCustomerId!);
      loadedLastOrder = await workOrdersRepo.getLastWorkOrderForCustomer(
        _selectedCustomerId!,
        excludeWorkOrderId: widget.order?.id,
      );

      if (autoVehId == null && initialVehicles.length == 1) {
        autoVehId = initialVehicles.first.id;
        if (initialVehicles.first.lastOdometer != null && _odometerController.text.isEmpty) {
          _odometerController.text = initialVehicles.first.lastOdometer.toString();
        }
      }
    }

    if (mounted) {
      setState(() {
        _selectedCustomer = loadedCust;
        _customerSummary = loadedSummary;
        _lastWorkOrder = loadedLastOrder;
        _vehicles = initialVehicles;
        _selectedVehicleId = autoVehId;
        _employees = allEmployees;
        _selectedEmployeeId = autoEmpId;
        _isCustomMechanic = isCustom;
      });
    }
  }

  void _onCustomerSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = <Customer>[];
        _isSearchingCustomer = false;
      });
      return;
    }

    setState(() => _isSearchingCustomer = true);
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () async {
      final customersRepo = ref.read(customersRepositoryProvider);
      final results = await customersRepo.search(trimmed);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearchingCustomer = false;
        });
      }
    });
  }

  Future<void> _selectCustomer(Customer customer) async {
    setState(() {
      _selectedCustomerId = customer.id;
      _selectedCustomer = customer;
      _searchResults = <Customer>[];
      _isSearchingCustomer = false;
      _customerSearchController.text = customer.name;
      _selectedVehicleId = null;
      _vehicles = <Vehicle>[];
      _isLoadingCustomerHistory = true;
    });

    final customersRepo = ref.read(customersRepositoryProvider);
    final vehiclesRepo = ref.read(vehiclesRepositoryProvider);
    final workOrdersRepo = ref.read(workOrdersRepositoryProvider);

    try {
      final summary = await customersRepo.getCustomerSummary(customer.id);
      final custVehicles = await vehiclesRepo.getByCustomerId(customer.id);
      final lastOrder = await workOrdersRepo.getLastWorkOrderForCustomer(
        customer.id,
        excludeWorkOrderId: widget.order?.id,
      );

      int? autoVehId;
      if (custVehicles.length == 1) {
        autoVehId = custVehicles.first.id;
        if (custVehicles.first.lastOdometer != null && _odometerController.text.isEmpty) {
          _odometerController.text = custVehicles.first.lastOdometer.toString();
        }
      }

      if (mounted) {
        setState(() {
          _customerSummary = summary;
          _vehicles = custVehicles;
          _selectedVehicleId = autoVehId;
          _lastWorkOrder = lastOrder;
          _isLoadingCustomerHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCustomerHistory = false);
      }
    }
  }

  void _clearSelectedCustomer() {
    setState(() {
      _selectedCustomerId = null;
      _selectedCustomer = null;
      _customerSummary = null;
      _lastWorkOrder = null;
      _selectedVehicleId = null;
      _vehicles = <Vehicle>[];
      _customerSearchController.clear();
      _searchResults = <Customer>[];
    });
  }

  Future<void> _addNewCustomer() async {
    final newId = await CustomerFormDialog.show(context);
    if (newId != null && mounted) {
      final customersRepo = ref.read(customersRepositoryProvider);
      final newCustomer = await customersRepo.getById(newId);
      await _selectCustomer(newCustomer);
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

  Future<void> _addNewEmployee() async {
    final newEmployeeAdded = await EmployeeFormDialog.show(context);
    if (newEmployeeAdded == true && mounted) {
      final employeesRepo = ref.read(employeesRepositoryProvider);
      final allEmployees = await employeesRepo.getAllEmployees(activeOnly: true);
      setState(() {
        _employees = allEmployees;
        if (allEmployees.isNotEmpty) {
          final newest = allEmployees.reduce((curr, next) => curr.id > next.id ? curr : next);
          _selectedEmployeeId = newest.id;
          _isCustomMechanic = false;
        }
      });
    }
  }

  Future<void> _pickEntryDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar'),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_entryDate),
    );
    if (pickedTime == null || !mounted) {
      setState(() {
        _entryDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _entryDate.hour,
          _entryDate.minute,
        );
      });
      return;
    }

    setState(() {
      _entryDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickExpectedExitDateTime() async {
    final baseDate = _expectedExitDate ?? _entryDate.add(const Duration(hours: 4));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: baseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar'),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(baseDate),
    );
    if (pickedTime == null || !mounted) {
      setState(() {
        _expectedExitDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          baseDate.hour,
          baseDate.minute,
        );
      });
      return;
    }

    setState(() {
      _expectedExitDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _setExpectedExitPreset(Duration offset, int hour) {
    final base = _entryDate;
    final targetDay = base.add(offset);
    setState(() {
      _expectedExitDate = DateTime(
        targetDay.year,
        targetDay.month,
        targetDay.day,
        hour,
        0,
      );
    });
  }

  String _formatDateTimeDisplay(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hourInt = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final hour = hourInt.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    final amPm = d.hour >= 12 ? 'م' : 'ص';
    return '$year/$month/$day $hour:$min $amPm';
  }

  void _addServiceLineDialog() {
    AddServiceLineDialog.show(
      context,
      onAdd: (line) {
        setState(() => _lines.add(line));
      },
    );
  }

  void _addPartLineDialog() {
    AddPartLineDialog.show(
      context,
      onAdd: (line) {
        setState(() => _lines.add(line));
      },
    );
  }

  void _removeLine(int index) {
    setState(() => _lines.removeAt(index));
  }

  int get _servicesTotal => _lines.where((l) => l.isService).fold<int>(0, (sum, l) => sum + l.totalPrice);
  int get _partsTotal => _lines.where((l) => l.isPart).fold<int>(0, (sum, l) => sum + l.totalPrice);
  int get _grandTotal => _servicesTotal + _partsTotal;

  Future<void> _save({bool andPrint = false}) async {
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

    String? resolvedMechanic;
    if (_selectedEmployeeId != null && _selectedEmployeeId! > 0) {
      final emp = _employees.where((e) => e.id == _selectedEmployeeId).firstOrNull;
      resolvedMechanic = emp?.name;
    } else if (_isCustomMechanic && _customMechanicController.text.trim().isNotEmpty) {
      resolvedMechanic = _customMechanicController.text.trim();
    }

    try {
      final actions = ref.read(workOrdersActionsControllerProvider);

      if (widget.order == null) {
        // Create new
        final created = await actions.createWorkOrder(
          customerId: _selectedCustomerId!,
          vehicleId: _selectedVehicleId!,
          odometer: odo,
          complaint: _complaintController.text.trim(),
          mechanicName: resolvedMechanic,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          entryDate: _entryDate,
          expectedExitDate: _expectedExitDate,
          lines: _lines,
        );
        if (mounted) {
          Navigator.of(context).pop();
          AppSnackbar.showSuccess(
            context,
            andPrint
                ? 'تم فتح أمر الشغل بنجاح، جاري فتح كارت أمر الشغل للطباعة...'
                : 'تم فتح أمر الشغل بنجاح',
          );
        }
        if (andPrint) {
          try {
            final profile = ref.read(garageProfileProvider).value;
            final builder = JobCardBuilder(order: created, garageProfile: profile);
            await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) => builder.buildPdf(),
              name: 'كارت_امر_شغل_${created.orderNumber}.pdf',
            );
          } catch (e) {
            debugPrint('Failed to open print dialog: $e');
          }
        }
      } else {
        // Update existing
        final updated = await actions.updateWorkOrder(
          id: widget.order!.id,
          odometer: odo,
          complaint: _complaintController.text.trim(),
          mechanicName: resolvedMechanic,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          entryDate: _entryDate,
          expectedExitDate: _expectedExitDate,
          lines: _lines,
        );
        if (mounted) {
          Navigator.of(context).pop();
          AppSnackbar.showSuccess(
            context,
            andPrint
                ? 'تم حفظ التعديلات، جاري فتح كارت أمر الشغل للطباعة...'
                : 'تم حفظ تعديلات أمر الشغل بنجاح',
          );
        }
        if (andPrint) {
          try {
            final profile = ref.read(garageProfileProvider).value;
            final builder = JobCardBuilder(order: updated, garageProfile: profile);
            await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) => builder.buildPdf(),
              name: 'كارت_امر_شغل_${updated.orderNumber}.pdf',
            );
          } catch (e) {
            debugPrint('Failed to open print dialog: $e');
          }
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
      maxWidth: 840,
      isLoading: _isLoading,
      onSave: () => _save(andPrint: false),
      saveLabel: isEditing ? 'حفظ التعديلات' : 'فتح أمر الشغل',
      extraActions: <Widget>[
        FilledButton.icon(
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('حفظ وطباعة كارت أمر الشغل'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : () => _save(andPrint: true),
        ),
      ],
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_selectedCustomer == null) ...[
                    // Customer Search Field
                    TextFormField(
                      controller: _customerSearchController,
                      onChanged: _onCustomerSearchChanged,
                      decoration: InputDecoration(
                        labelText: 'ابحث عن العميل (الاسم أو رقم الهاتف أو رقم اللوحة)',
                        hintText: 'اكتب اسم العميل أو رقم هاتفه للبحث والتحقق من بياناته...',
                        prefixIcon: const Icon(Icons.person_search_outlined, size: 20),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isSearchingCustomer)
                              const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            if (_customerSearchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                tooltip: 'مسح البحث',
                                onPressed: () {
                                  _customerSearchController.clear();
                                  _onCustomerSearchChanged('');
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                              tooltip: 'تسجيل عميل جديد بالمركز',
                              onPressed: _addNewCustomer,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Search Results List
                    if (_searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        constraints: const BoxConstraints(maxHeight: 190),
                        child: Material(
                          color: AppColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
                          ),
                          elevation: 1,
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final cust = _searchResults[index];
                              return ListTile(
                                dense: true,
                                leading: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primary,
                                  child: Icon(Icons.person, size: 16, color: Colors.white),
                                ),
                                title: Text(
                                  cust.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                subtitle: Text(
                                  cust.phone != null && cust.phone!.isNotEmpty ? 'رقم الهاتف: ${cust.phone}' : 'بدون رقم هاتف',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                trailing: const Icon(Icons.arrow_back_ios_new, size: 12, color: AppColors.textSecondary),
                                onTap: () => _selectCustomer(cust),
                              );
                            },
                          ),
                        ),
                      )
                    else if (_customerSearchController.text.trim().isNotEmpty && !_isSearchingCustomer)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_off_outlined, color: AppColors.warning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'لا يوجد عميل مطابق للبحث "${_customerSearchController.text.trim()}"',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
                              label: const Text('تسجيل كعميل جديد', style: TextStyle(fontSize: 12)),
                              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: _addNewCustomer,
                            ),
                          ],
                        ),
                      ),
                  ] else ...[
                    // Customer Card (When Selected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.person, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _selectedCustomer!.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    if (_customerSummary != null && _customerSummary!.hasDebt) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'مديونية سابقة: ${_customerSummary!.formattedBalance}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.danger),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'رقم الهاتف: ${_selectedCustomer!.phone ?? "بدون هاتف"} • إجمالي الصيانات السابقة: ${_customerSummary?.workOrdersCount ?? 0}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (!isEditing)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.swap_horiz, size: 16),
                              label: const Text('تغيير العميل', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              onPressed: _clearSelectedCustomer,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Vehicle & Odometer
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
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
                              hintText: 'مثال: 45000',
                              suffixText: 'كم',
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Last Maintenance Box (سجل آخر صيانة للعميل)
                    if (_isLoadingCustomerHistory)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    else if (_lastWorkOrder != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.history_toggle_off_outlined, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'آخر صيانة مسجلة للعميل: أمر شغل #${_lastWorkOrder!.orderNumber} (${_lastWorkOrder!.formattedCreatedAt})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _lastWorkOrder!.statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _lastWorkOrder!.statusArabic,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _lastWorkOrder!.statusColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                if (_lastWorkOrder!.workOrder.odometer != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('العداد السابق: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      Text('${_lastWorkOrder!.workOrder.odometer} كم', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('السيارة: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    Text(_lastWorkOrder!.vehicleDisplayTitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                if (_lastWorkOrder!.workOrder.mechanicName != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('المستلم السابق: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      Text(_lastWorkOrder!.workOrder.mechanicName!, style: const TextStyle(fontSize: 11)),
                                    ],
                                  ),
                              ],
                            ),
                            if (_lastWorkOrder!.workOrder.complaint != null && _lastWorkOrder!.workOrder.complaint!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'الشكوى / ما تم تنفيذه: ${_lastWorkOrder!.workOrder.complaint}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (_lastWorkOrder!.lines.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                'أهم البنود: ${_lastWorkOrder!.lines.map((l) => l.description).take(3).join(' • ')}',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                            SizedBox(width: 6),
                            Text(
                              'عميل جديد — هذه أول صيانة يتم تسجيلها لهذا العميل بالمركز.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Section: Car Entry Date & Expected Exit Time ────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'مواعيد أمر الشغل (دخول وخروج السيارة من الصيانة)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.restore, size: 14),
                        label: const Text('تعيين الدخول للآن', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () => setState(() => _entryDate = DateTime.now()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Car Entry Date Box
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _pickEntryDateTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.login_rounded, size: 20, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'تاريخ ووقت دخول السيارة للمركز',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDateTimeDisplay(_entryDate),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Expected Exit Date Box
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _pickExpectedExitDateTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _expectedExitDate != null
                                  ? AppColors.primary.withValues(alpha: 0.05)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _expectedExitDate != null
                                    ? AppColors.primary.withValues(alpha: 0.4)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.event_available_outlined,
                                  size: 20,
                                  color: _expectedExitDate != null ? AppColors.primary : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ميعاد خروج السيارة من الصيانة (المتوقع)',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _expectedExitDate != null
                                            ? _formatDateTimeDisplay(_expectedExitDate!)
                                            : 'اضغط لتحديد ميعاد خروج السيارة...',
                                        style: TextStyle(
                                          fontWeight: _expectedExitDate != null ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 13,
                                          color: _expectedExitDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_expectedExitDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                                    tooltip: 'إلغاء ميعاد الخروج',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(() => _expectedExitDate = null),
                                  )
                                else
                                  const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quick presets for expected exit
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('مواعيد خروج سريعة مقترحة: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ActionChip(
                        label: const Text('اليوم 6:00 م', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _setExpectedExitPreset(Duration.zero, 18),
                      ),
                      ActionChip(
                        label: const Text('غداً 12:00 ظ', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _setExpectedExitPreset(const Duration(days: 1), 12),
                      ),
                      ActionChip(
                        label: const Text('غداً 6:00 م', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _setExpectedExitPreset(const Duration(days: 1), 18),
                      ),
                      ActionChip(
                        label: const Text('بعد يومين (6:00 م)', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _setExpectedExitPreset(const Duration(days: 2), 18),
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

                // Receiving Employee Dropdown & Add button
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      DropdownButtonFormField<int?>(
                        key: ValueKey<String>('employee_$_selectedEmployeeId'),
                        isExpanded: true,
                        initialValue: (_selectedEmployeeId == -1 || _employees.any((e) => e.id == _selectedEmployeeId))
                            ? _selectedEmployeeId
                            : null,
                        decoration: InputDecoration(
                          labelText: AppStrings.mechanicLabel,
                          hintText: _employees.isEmpty ? 'لا يوجد موظفين مسجلين' : AppStrings.mechanicHint,
                          prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                            tooltip: 'إضافة موظف جديد للمركز',
                            onPressed: _addNewEmployee,
                          ),
                        ),
                        items: <DropdownMenuItem<int?>>[
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('— بدون تحديد موظف —', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          ..._employees.map((e) {
                            return DropdownMenuItem<int?>(
                              value: e.id,
                              child: Text(
                                '${e.name} (${e.role})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                          const DropdownMenuItem<int?>(
                            value: -1,
                            child: Text('✍️ إدخال اسم فني يدوي / خارجي...', style: TextStyle(color: AppColors.primary)),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedEmployeeId = val;
                            _isCustomMechanic = (val == -1);
                          });
                        },
                      ),
                      if (_isCustomMechanic) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _customMechanicController,
                          decoration: InputDecoration(
                            labelText: 'اسم الفني / المستلم الخارجي',
                            hintText: 'اكتب الاسم يدوياً...',
                            prefixIcon: const Icon(Icons.edit_outlined, size: 16),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              tooltip: 'إلغاء الاسم اليدوي',
                              onPressed: () {
                                setState(() {
                                  _selectedEmployeeId = null;
                                  _isCustomMechanic = false;
                                  _customMechanicController.clear();
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
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
                            OutlinedButton.icon(
                              onPressed: () => ServicesManagerDialog.show(context),
                              icon: const Icon(Icons.tune_outlined, size: 16),
                              label: const Text('دليل الخدمات والأسعار'),
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

