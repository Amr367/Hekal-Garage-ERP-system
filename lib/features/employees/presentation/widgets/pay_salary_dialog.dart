import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/providers.dart';
import '../../../../core/db/repositories/employees_repository.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../employees_controller.dart';

/// Dialog to process and record monthly salary payout for an employee.
class PaySalaryDialog extends ConsumerStatefulWidget {
  const PaySalaryDialog({
    super.key,
    this.preselectedEmployee,
  });

  final EmployeeWithStats? preselectedEmployee;

  static Future<bool?> show(BuildContext context, {EmployeeWithStats? preselectedEmployee}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaySalaryDialog(preselectedEmployee: preselectedEmployee),
    );
  }

  @override
  ConsumerState<PaySalaryDialog> createState() => _PaySalaryDialogState();
}

class _PaySalaryDialogState extends ConsumerState<PaySalaryDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedEmployeeId;
  late int _year;
  late int _month;
  int _basicSalaryPiasters = 0;
  int _advancesDeductedPiasters = 0;
  int _bonusPiasters = 0;
  int _penaltyPiasters = 0;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final _notesController = TextEditingController();

  List<EmployeeAdvanceWithDetails> _pendingAdvances = [];
  bool _deductAllAdvances = true;
  bool _isLoadingAdvances = false;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;

    if (widget.preselectedEmployee != null) {
      _selectedEmployeeId = widget.preselectedEmployee!.id;
      _basicSalaryPiasters = widget.preselectedEmployee!.basicSalaryPiasters;
      _fetchAdvancesForEmployee(_selectedEmployeeId!);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdvancesForEmployee(int empId) async {
    setState(() => _isLoadingAdvances = true);
    try {
      final repo = ref.read(employeesRepositoryProvider);
      final advances = await repo.watchAdvances(employeeId: empId, isDeducted: false).first;
      if (mounted) {
        setState(() {
          _pendingAdvances = advances;
          _isLoadingAdvances = false;
          final totalPending = advances.fold<int>(0, (sum, a) => sum + a.amountPiasters);
          if (_deductAllAdvances) {
            _advancesDeductedPiasters = totalPending;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAdvances = false);
    }
  }

  int get _calculatedNetPaid {
    final net = _basicSalaryPiasters - _advancesDeductedPiasters + _bonusPiasters - _penaltyPiasters;
    return net < 0 ? 0 : net;
  }

  Future<void> _submit() async {
    if (_selectedEmployeeId == null) {
      setState(() => _errorMessage = 'يرجى اختيار الموظف أولاً.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(employeesActionsControllerProvider);
      final advanceIds = _deductAllAdvances ? _pendingAdvances.map((a) => a.id).toList() : null;

      await controller.paySalary(
        employeeId: _selectedEmployeeId!,
        year: _year,
        month: _month,
        basicSalary: _basicSalaryPiasters,
        advancesDeducted: _advancesDeductedPiasters,
        bonusAmount: _bonusPiasters,
        penaltyAmount: _penaltyPiasters,
        netPaid: _calculatedNetPaid,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        advanceIdsToDeduct: advanceIds,
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
      title: 'صرف راتب الموظف',
      maxWidth: 640,
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
                  _basicSalaryPiasters = activeEmployees.first.basicSalaryPiasters;
                  _fetchAdvancesForEmployee(_selectedEmployeeId!);
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
                      child: Text('${e.name} (${e.role}) — الراتب الأساسي: ${MoneyUtils.format(e.basicSalaryPiasters, withCurrency: true)}', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedEmployeeId = val;
                        final emp = activeEmployees.firstWhere((e) => e.id == val);
                        _basicSalaryPiasters = emp.basicSalaryPiasters;
                      });
                      _fetchAdvancesForEmployee(val);
                    }
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ في تحميل الموظفين: $e'),
            ),
            const SizedBox(height: 16),

            // Period (Month & Year)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration: const InputDecoration(
                      labelText: 'عن شهر *',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    items: List.generate(12, (i) => i + 1).map((m) {
                      return DropdownMenuItem(value: m, child: Text('شهر $m'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _month = val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: const InputDecoration(
                      labelText: 'السنة *',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                      items: [DateTime.now().year - 1, DateTime.now().year, DateTime.now().year + 1].map((y) {
                        return DropdownMenuItem(value: y, child: Text('$y'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _year = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Basic Salary
              MoneyField(
                label: 'الراتب الأساسي للشهر (ج.م) *',
                initialPiasters: _basicSalaryPiasters,
                onChangedPiasters: (piasters) => setState(() => _basicSalaryPiasters = piasters ?? 0),
              ),
              const SizedBox(height: 16),

              // Advances Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.price_change_outlined, size: 18, color: AppColors.warning),
                            SizedBox(width: 8),
                            Text('السلفيات والمسحوبات المعلقة:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        if (_isLoadingAdvances)
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          Text(
                            MoneyUtils.format(
                              _pendingAdvances.fold<int>(0, (sum, a) => sum + a.amountPiasters),
                              withCurrency: true,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger, fontSize: 13),
                          ),
                      ],
                    ),
                    if (_pendingAdvances.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('خصم جميع السلف المعلقة من الراتب تلقائياً'),
                        value: _deductAllAdvances,
                        onChanged: (val) {
                          setState(() {
                            _deductAllAdvances = val ?? true;
                            if (_deductAllAdvances) {
                              _advancesDeductedPiasters = _pendingAdvances.fold<int>(0, (sum, a) => sum + a.amountPiasters);
                            } else {
                              _advancesDeductedPiasters = 0;
                            }
                          });
                        },
                      ),
                    ],
                    if (!_deductAllAdvances || _pendingAdvances.isEmpty) ...[
                      const SizedBox(height: 6),
                      MoneyField(
                        label: 'المبلغ المخصوم من السلف (ج.م)',
                        initialPiasters: _advancesDeductedPiasters,
                        onChangedPiasters: (piasters) => setState(() => _advancesDeductedPiasters = piasters ?? 0),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bonuses & Penalties
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MoneyField(
                      label: 'مكافآت وحوافز إضافية (ج.م)',
                      initialPiasters: _bonusPiasters,
                      onChangedPiasters: (piasters) => setState(() => _bonusPiasters = piasters ?? 0),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MoneyField(
                      label: 'خصومات وجزاءات (ج.م)',
                      initialPiasters: _penaltyPiasters,
                      onChangedPiasters: (piasters) => setState(() => _penaltyPiasters = piasters ?? 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Net Paid Preview Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryContainer),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('صافي الراتب المستحق للصرف:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      MoneyUtils.format(_calculatedNetPaid, withCurrency: true),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Method
              DropdownButtonFormField<PaymentMethod>(
                isExpanded: true,
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'طريقة صرف الراتب *',
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
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات الصرف',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
