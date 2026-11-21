import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/supplier_with_balance.dart';
import '../purchases_controller.dart';

/// Modal dialog for recording a payment towards supplier debt.
class SupplierPaymentDialog extends ConsumerStatefulWidget {
  const SupplierPaymentDialog({
    super.key,
    required this.supplier,
  });

  final SupplierWithBalance supplier;

  static Future<bool?> show(BuildContext context, {required SupplierWithBalance supplier}) {
    return showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => SupplierPaymentDialog(supplier: supplier),
    );
  }

  @override
  ConsumerState<SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class _SupplierPaymentDialogState extends ConsumerState<SupplierPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _amountPiasters;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default to the full balance due
    _amountPiasters = widget.supplier.balanceDuePiasters;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_amountPiasters <= 0) {
      AppSnackbar.showError(context, 'المبلغ المسدد يجب أن يكون أكبر من صفر');
      return;
    }

    setState(() => _isSaving = true);
    final actions = ref.read(purchasesActionsControllerProvider);

    try {
      await actions.recordSupplierPayment(
        supplierId: widget.supplier.id,
        amountPiasters: _amountPiasters,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted) {
        AppSnackbar.showSuccess(context, AppStrings.supplierPaymentSuccess);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: AppStrings.recordSupplierPaymentButton,
      maxWidth: 480,
      onSave: _isSaving ? null : _submit,
      isLoading: _isSaving,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Supplier & balance info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.supplier.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      const Text(
                        'إجمالي المديونية المستحقة: ',
                        style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                      ),
                      Text(
                        widget.supplier.formattedBalanceDue,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            MoneyField(
              label: '${AppStrings.supplierPaymentAmountLabel} *',
              initialPiasters: _amountPiasters,
              onChangedPiasters: (p) => setState(() => _amountPiasters = p ?? 0),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات السداد / رقم التحويل',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
