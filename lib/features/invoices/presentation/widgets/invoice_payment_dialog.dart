import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/invoice_with_details.dart';
import '../invoices_controller.dart';

/// Modal dialog for recording a payment towards an outstanding invoice balance.
class InvoicePaymentDialog extends ConsumerStatefulWidget {
  const InvoicePaymentDialog({
    super.key,
    required this.invoice,
  });

  final InvoiceWithDetails invoice;

  static Future<bool?> show(BuildContext context, {required InvoiceWithDetails invoice}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InvoicePaymentDialog(invoice: invoice),
    );
  }

  @override
  ConsumerState<InvoicePaymentDialog> createState() => _InvoicePaymentDialogState();
}

class _InvoicePaymentDialogState extends ConsumerState<InvoicePaymentDialog> {
  late int _amountPiasters;
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  final _refController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountPiasters = widget.invoice.remainingPiasters;
  }

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_amountPiasters <= 0) {
      AppSnackbar.showError(context, 'يرجى إدخال مبلغ تحصيل صحيح');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(invoicesActionsProvider).recordPayment(
            invoiceId: widget.invoice.id,
            amountPiasters: _amountPiasters,
            method: _selectedMethod,
            notes: _refController.text.trim().isNotEmpty ? _refController.text.trim() : null,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        AppSnackbar.showSuccess(context, 'تم تسجيل الدفعة وتحديث رصيد الفاتورة بنجاح');
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
      title: 'تحصيل دفعة للفاتورة #${widget.invoice.invoiceNumber}',
      maxWidth: 480,
      isLoading: _isLoading,
      onSave: _submit,
      saveLabel: 'تأكيد التحصيل',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header with invoice & customer info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('العميل: ${widget.invoice.customerName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(widget.invoice.customerPhone, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المتبقي الحالي على الفاتورة:', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                    Text(
                      widget.invoice.formattedRemaining,
                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Amount to collect
          MoneyField(
            initialPiasters: _amountPiasters,
            label: 'المبلغ المحصل الآن',
            onChangedPiasters: (p) => setState(() => _amountPiasters = p ?? 0),
          ),

          const SizedBox(height: 16),

          // Payment method
          const Text('طريقة التحصيل والدفع:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MethodChip(
                label: 'خزنة الفرع (كاش)',
                icon: Icons.payments_outlined,
                isSelected: _selectedMethod == PaymentMethod.cash,
                onSelected: () => setState(() => _selectedMethod = PaymentMethod.cash),
              ),
              _MethodChip(
                label: 'انستاباي (InstaPay)',
                icon: Icons.bolt,
                isSelected: _selectedMethod == PaymentMethod.instapay,
                onSelected: () => setState(() => _selectedMethod = PaymentMethod.instapay),
              ),
              _MethodChip(
                label: 'فودافون كاش ومحافظ',
                icon: Icons.phone_android,
                isSelected: _selectedMethod == PaymentMethod.wallet,
                onSelected: () => setState(() => _selectedMethod = PaymentMethod.wallet),
              ),
              _MethodChip(
                label: 'فيزا / كارت',
                icon: Icons.credit_card,
                isSelected: _selectedMethod == PaymentMethod.card,
                onSelected: () => setState(() => _selectedMethod = PaymentMethod.card),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Reference or Notes
          TextFormField(
            controller: _refController,
            decoration: const InputDecoration(
              labelText: 'رقم مرجع التحويل أو ملاحظات الدفعة (اختياري)',
              hintText: 'مثال: مرجع إنستاباي 928374 أو كود العملية',
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => onSelected(),
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.onSurfaceVariant),
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.onSurface),
    );
  }
}
