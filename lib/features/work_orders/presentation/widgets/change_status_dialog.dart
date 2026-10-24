import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/work_order_with_details.dart';
import '../work_orders_controller.dart';

import 'deliver_work_order_dialog.dart';

/// Modal dialog for transitioning work order status.
class ChangeStatusDialog extends ConsumerStatefulWidget {
  const ChangeStatusDialog({
    super.key,
    required this.order,
  });

  final WorkOrderWithDetails order;

  static Future<void> show(BuildContext context, {required WorkOrderWithDetails order}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeStatusDialog(order: order),
    );
  }

  @override
  ConsumerState<ChangeStatusDialog> createState() => _ChangeStatusDialogState();
}

class _ChangeStatusDialogState extends ConsumerState<ChangeStatusDialog> {
  late WorkOrderStatus _selectedStatus;
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order.status;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedStatus == widget.order.status) {
      Navigator.of(context).pop();
      return;
    }

    if (_selectedStatus == WorkOrderStatus.delivered) {
      Navigator.of(context).pop();
      DeliverWorkOrderDialog.show(context, order: widget.order);
      return;
    }

    if (_selectedStatus == WorkOrderStatus.cancelled && _reasonController.text.trim().isEmpty) {
      AppSnackbar.showError(context, 'يرجى كتابة سبب إلغاء أمر الشغل.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(workOrdersActionsControllerProvider).updateStatus(
            id: widget.order.id,
            status: _selectedStatus,
            cancellationReason: _selectedStatus == WorkOrderStatus.cancelled
                ? _reasonController.text.trim()
                : null,
          );

      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.showSuccess(context, 'تم تحديث حالة أمر الشغل بنجاح');
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
      title: AppStrings.changeStatusButton,
      maxWidth: 480,
      isLoading: _isLoading,
      onSave: _submit,
      saveLabel: 'حفظ التغيير',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'أمر شغل ${widget.order.orderNumberFormatted} - ${widget.order.customer.name}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // Status Options
          ...WorkOrderStatus.values.map((status) {
            final isCurrent = status == widget.order.status;
            final isSelected = status == _selectedStatus;
            final isDeliveredAndCancelled = widget.order.isDelivered && status == WorkOrderStatus.cancelled;

            return InkWell(
              onTap: isDeliveredAndCancelled
                  ? null
                  : () {
                      setState(() => _selectedStatus = status);
                    },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.35) : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _statusTitle(status),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                        color: isDeliveredAndCancelled ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('الحالية', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                      ),
                    ],
                    if (isDeliveredAndCancelled) ...[
                      const Spacer(),
                      const Text(
                        'لا يمكن إلغاء أمر تم تسليمه',
                        style: TextStyle(color: AppColors.danger, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),

          // Cancellation Reason input if cancelled is selected
          if (_selectedStatus == WorkOrderStatus.cancelled) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: AppStrings.cancellationReasonLabel,
                hintText: 'اكتب سبب الإلغاء (مثل: رغبة العميل، قطع الغيار غير متوفرة...)',
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }

  String _statusTitle(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.open:
        return AppStrings.statusOpen;
      case WorkOrderStatus.inProgress:
        return AppStrings.statusInProgress;
      case WorkOrderStatus.ready:
        return AppStrings.statusReady;
      case WorkOrderStatus.delivered:
        return AppStrings.statusDelivered;
      case WorkOrderStatus.cancelled:
        return AppStrings.statusCancelled;
    }
  }
}
