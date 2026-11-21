import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/invoice_with_details.dart';
import '../invoices_controller.dart';

/// Modal dialog for cancelling or voiding an invoice with a required cancellation reason.
class CancelInvoiceDialog extends ConsumerStatefulWidget {
  const CancelInvoiceDialog({
    super.key,
    required this.invoice,
  });

  final InvoiceWithDetails invoice;

  static Future<bool?> show(BuildContext context, {required InvoiceWithDetails invoice}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CancelInvoiceDialog(invoice: invoice),
    );
  }

  @override
  ConsumerState<CancelInvoiceDialog> createState() => _CancelInvoiceDialogState();
}

class _CancelInvoiceDialogState extends ConsumerState<CancelInvoiceDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(invoicesActionsProvider).cancelInvoice(
            invoiceId: widget.invoice.id,
            reason: _reasonController.text.trim(),
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        AppSnackbar.showSuccess(context, 'تم إلغاء الفاتورة وإعادة الأصناف للمخزن بنجاح');
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
    return AppFormDialog(
      title: 'إلغاء الفاتورة #${widget.invoice.invoiceNumber}',
      maxWidth: 480,
      isLoading: _isLoading,
      onSave: _submit,
      saveLabel: 'تأكيد إلغاء الفاتورة',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تنبيه: سيؤدي إلغاء الفاتورة إلى إبطال مبيعاتها وإرجاع أي قطع غيار تم سحبها إلى رصيد المخزن تلقائياً.',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurface, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء (إلزامي)',
                hintText: 'يرجى كتابة سبب إلغاء الفاتورة...',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'يرجى توضيح سبب الإلغاء';
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
