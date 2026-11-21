import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/employees_repository.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../employees_controller.dart';

/// Dialog to record an advance or withdrawal for an employee.
class RecordAdvanceDialog extends ConsumerStatefulWidget {
  const RecordAdvanceDialog({
    super.key,
    this.preselectedEmployee,
  });

  final EmployeeWithStats? preselectedEmployee;

  static Future<bool?> show(BuildContext context, {EmployeeWithStats? preselectedEmployee}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordAdvanceDialog(preselectedEmployee: preselectedEmployee),
    );
  }

  @override
  ConsumerState<RecordAdvanceDialog> createState() => _RecordAdvanceDialogState();
}

class _RecordAdvanceDialogState extends ConsumerState<RecordAdvanceDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedEmployeeId;
  int _amountPiasters = 0;
  DateTime _date = DateTime.now();
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final _notesController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.preselectedEmployee?.id;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedEmployeeId == null) {
      setState(() => _errorMessage = 'يرجى اختيار الموظف أولاً.');
      return;
    }
    if (_amountPiasters <= 0) {
      setState(() => _errorMessage = 'يرجى إدخال مبلغ سلفة صحيح أكبر من الصفر.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(employeesActionsControllerProvider);
      await controller.recordAdvance(
        employeeId: _selectedEmployeeId!,
        amount: _amountPiasters,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        date: _date,
      );

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
    final employeesAsync = ref.watch(employeesListProvider);

    return AppFormDialog(
      title: 'تسجيل سلفة / مسحوبات موظف',
      maxWidth: 540,
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

            // Employee Selector
            employeesAsync.when(
              data: (employees) {
                final activeEmployees = employees.where((e) => e.isActive).toList();
                if (_selectedEmployeeId == null && activeEmployees.isNotEmpty) {
                  _selectedEmployeeId = activeEmployees.first.id;
                }

                return DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _selectedEmployeeId,
                  decoration: const InputDecoration(
                    labelText: 'اختر الموظف *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: activeEmployees.map((e) {
                    return DropdownMenuItem<int>(
                      value: e.id,
                      child: Text('${e.name} (${e.role}) — راتبه: ${MoneyUtils.format(e.basicSalaryPiasters, withCurrency: true)}', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: widget.preselectedEmployee != null
                      ? null
                      : (val) {
                          if (val != null) setState(() => _selectedEmployeeId = val);
                        },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ في تحميل الموظفين: $e'),
            ),
            const SizedBox(height: 16),

            // Advance Amount
            MoneyField(
              label: 'مبلغ السلفة / المسحوب (ج.م) *',
              initialPiasters: _amountPiasters,
              onChangedPiasters: (piasters) => _amountPiasters = piasters ?? 0,
            ),
            const SizedBox(height: 16),

            // Payment Method & Date
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<PaymentMethod>(
                    isExpanded: true,
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'طريقة الصرف *',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                      items: const [
                        DropdownMenuItem(value: PaymentMethod.cash, child: Text('خزنة الفرع (كاش)')),
                        DropdownMenuItem(value: PaymentMethod.instapay, child: Text('انستاباي (InstaPay)')),
                        DropdownMenuItem(value: PaymentMethod.wallet, child: Text('فودافون كاش / محفظة')),
                        DropdownMenuItem(value: PaymentMethod.transfer, child: Text('تحويل بنكي')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMethod = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 15)),
                        );
                        if (picked != null) {
                          setState(() => _date = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ السحب',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          '${_date.year}/${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reason / Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'سبب السلفة / ملاحظات',
                  hintText: 'مثال: سلفة علاجية / سحب على حساب الراتب',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
