import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/expenses_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../expenses_controller.dart';

/// Common workshop expense categories.
const List<String> kCommonExpenseCategories = [
  'إيجار الورشة',
  'كهرباء ومياه وغاز',
  'بوفيه وضيافة وعمالة',
  'شراء وصيانة عدد وأدوات',
  'نظافة ومهمات ومستلزمات',
  'أدوات مكتبية ومطبوعات',
  'وقود وانتقالات',
  'تراخيص واشتراكات ورسوم',
  'نثريات ومصاريف عامة',
  'أخرى',
];

/// Dialog for creating or editing an expense record.
class ExpenseFormDialog extends ConsumerStatefulWidget {
  const ExpenseFormDialog({
    super.key,
    this.existingExpense,
  });

  final ExpenseWithDetails? existingExpense;

  static Future<bool?> show(BuildContext context, {ExpenseWithDetails? existingExpense}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExpenseFormDialog(existingExpense: existingExpense),
    );
  }

  @override
  ConsumerState<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _category;
  late int _amountPiasters;
  late final TextEditingController _descriptionController;
  late final TextEditingController _paidToController;
  late final TextEditingController _receiptController;
  late final TextEditingController _notesController;
  late DateTime _expenseDate;
  PaymentMethod _paymentMethod = PaymentMethod.cash;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final exp = widget.existingExpense;
    _category = exp?.category ?? kCommonExpenseCategories.first;
    _amountPiasters = exp?.amountPiasters ?? 0;
    _descriptionController = TextEditingController(text: exp?.description ?? '');
    _paidToController = TextEditingController(text: exp?.paidTo ?? '');
    _receiptController = TextEditingController(text: exp?.receiptNumber ?? '');
    _notesController = TextEditingController(text: exp?.notes ?? '');
    _expenseDate = exp?.expenseDate ?? DateTime.now();
    _paymentMethod = exp?.paymentMethod ?? PaymentMethod.cash;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _paidToController.dispose();
    _receiptController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_amountPiasters <= 0) {
      setState(() => _errorMessage = 'يرجى إدخال مبلغ صحيح أكبر من الصفر.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final companion = ExpensesCompanion(
        category: drift.Value(_category),
        amount: drift.Value(_amountPiasters),
        description: drift.Value(_descriptionController.text.trim()),
        paidTo: drift.Value(_paidToController.text.trim().isEmpty ? null : _paidToController.text.trim()),
        receiptNumber: drift.Value(_receiptController.text.trim().isEmpty ? null : _receiptController.text.trim()),
        notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
        expenseDate: drift.Value(_expenseDate),
        paymentMethod: drift.Value(_paymentMethod),
      );

      final controller = ref.read(expensesActionsControllerProvider);
      if (widget.existingExpense == null) {
        await controller.addExpense(companion);
      } else {
        await controller.updateExpense(widget.existingExpense!.id, companion);
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
    final isEdit = widget.existingExpense != null;

    return AppFormDialog(
      title: isEdit ? 'تعديل المصروف' : 'تسجيل مصروف جديد',
      saveLabel: 'حفظ المصروف',
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

            // Category & Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: kCommonExpenseCategories.contains(_category) ? _category : 'أخرى',
                    decoration: const InputDecoration(
                      labelText: 'تصنيف المصروف *',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: kCommonExpenseCategories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c,
                        child: Text(c),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MoneyField(
                    label: 'مبلغ المصروف (ج.م) *',
                    initialPiasters: _amountPiasters,
                    onChangedPiasters: (piasters) => _amountPiasters = piasters ?? 0,
                  ),
                ),
              ],
            ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'بيان وتفاصيل المصروف *',
                  hintText: 'مثال: سداد فاتورة كهرباء شهر أكتوبر / شراء طقم مفاتيح للورشة',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'البيان مطلوب ولا يمكن تركه فارغاً';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Paid to & Receipt Number
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _paidToController,
                      decoration: const InputDecoration(
                        labelText: 'المدفوع له / الجهة المستفيدة',
                        hintText: 'مثال: شركة الكهرباء / محل الأمانة',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _receiptController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الإيصال / الفاتورة (إن وجد)',
                        hintText: 'مثال: 94821',
                        prefixIcon: Icon(Icons.tag),
                      ),
                    ),
                  ),
                ],
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
                        labelText: 'طريقة الدفع *',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: PaymentMethod.cash, child: Text('خزنة الفرع (كاش)')),
                        DropdownMenuItem(value: PaymentMethod.instapay, child: Text('انستاباي (InstaPay)')),
                        DropdownMenuItem(value: PaymentMethod.wallet, child: Text('فودافون كاش / محفظة')),
                        DropdownMenuItem(value: PaymentMethod.card, child: Text('فيزا / كارت بنكي')),
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
                          initialDate: _expenseDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setState(() => _expenseDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ الصرف',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          '${_expenseDate.year}/${_expenseDate.month.toString().padLeft(2, '0')}/${_expenseDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات إضافية',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
