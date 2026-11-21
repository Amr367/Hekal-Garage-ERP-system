import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/employees_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../employees_controller.dart';

/// Common workshop employee roles.
const List<String> kCommonEmployeeRoles = [
  'فني ميكانيكا',
  'فني كهرباء سيارات',
  'فني عفشة وميزان',
  'سمكري ودوكو',
  'مساعد فني ميكانيكا',
  'مهندس استقبال صيانة',
  'مسؤول مخزن وقطع غيار',
  'محاسب وخزينة',
  'إدارة ومبيعات',
  'عامل نظافة وخدمات',
  'سائق وتجربة',
  'أخرى',
];

/// Dialog for adding or editing an employee.
class EmployeeFormDialog extends ConsumerStatefulWidget {
  const EmployeeFormDialog({
    super.key,
    this.existingEmployee,
  });

  final EmployeeWithStats? existingEmployee;

  static Future<bool?> show(BuildContext context, {EmployeeWithStats? existingEmployee}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EmployeeFormDialog(existingEmployee: existingEmployee),
    );
  }

  @override
  ConsumerState<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends ConsumerState<EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late String _role;
  late final TextEditingController _phoneController;
  late final TextEditingController _nationalIdController;
  late final TextEditingController _notesController;
  late int _basicSalaryPiasters;
  late String _salaryType;
  DateTime? _hireDate;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final emp = widget.existingEmployee;
    _nameController = TextEditingController(text: emp?.name ?? '');
    _role = emp?.role ?? kCommonEmployeeRoles.first;
    _phoneController = TextEditingController(text: emp?.phone ?? '');
    _nationalIdController = TextEditingController(text: emp?.nationalId ?? '');
    _notesController = TextEditingController(text: emp?.notes ?? '');
    _basicSalaryPiasters = emp?.basicSalaryPiasters ?? 0;
    _salaryType = emp?.salaryType ?? 'شهري';
    _hireDate = emp?.hireDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final companion = EmployeesCompanion(
        name: drift.Value(_nameController.text.trim()),
        role: drift.Value(_role),
        phone: drift.Value(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
        nationalId: drift.Value(_nationalIdController.text.trim().isEmpty ? null : _nationalIdController.text.trim()),
        basicSalary: drift.Value(_basicSalaryPiasters),
        salaryType: drift.Value(_salaryType),
        hireDate: drift.Value(_hireDate),
        notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
      );

      final controller = ref.read(employeesActionsControllerProvider);
      if (widget.existingEmployee == null) {
        await controller.addEmployee(companion);
      } else {
        await controller.updateEmployee(widget.existingEmployee!.id, companion);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingEmployee != null;

    return AppFormDialog(
      title: isEdit ? 'تعديل بيانات الموظف' : 'إضافة موظف جديد',
      saveLabel: 'حفظ بيانات الموظف',
      maxWidth: 620,
      isLoading: _isSaving,
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Row(
                  children: [
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
            ],

            // Name & Role
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الموظف *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'اسم الموظف مطلوب';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: kCommonEmployeeRoles.contains(_role) ? _role : 'أخرى',
                    decoration: const InputDecoration(
                      labelText: 'المسمى الوظيفي *',
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                    items: kCommonEmployeeRoles.map((r) {
                      return DropdownMenuItem<String>(
                        value: r,
                        child: Text(r),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _role = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Phone & National ID
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _nationalIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الرقم القومي (14 رقم)',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Basic Salary & Salary Type
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MoneyField(
                    label: 'الراتب الأساسي (ج.م) *',
                    initialPiasters: _basicSalaryPiasters,
                    onChangedPiasters: (piasters) => _basicSalaryPiasters = piasters ?? 0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _salaryType,
                    decoration: const InputDecoration(
                      labelText: 'دورية الراتب *',
                      prefixIcon: Icon(Icons.event_repeat_outlined),
                    ),
                      items: const [
                        DropdownMenuItem(value: 'شهري', child: Text('راتب شهري')),
                        DropdownMenuItem(value: 'أسبوعي', child: Text('راتب أسبوعي')),
                        DropdownMenuItem(value: 'يومي', child: Text('يومية')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _salaryType = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hire date
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _hireDate ?? DateTime.now(),
                    firstDate: DateTime(2010),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setState(() => _hireDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ التعيين',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _hireDate != null
                        ? '${_hireDate!.year}/${_hireDate!.month.toString().padLeft(2, '0')}/${_hireDate!.day.toString().padLeft(2, '0')}'
                        : 'لم يحدد',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات إضافية عن الموظف',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
