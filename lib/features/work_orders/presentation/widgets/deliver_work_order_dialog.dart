import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/money/money.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/work_order_line_item.dart';
import '../../domain/work_order_with_details.dart';
import '../work_orders_controller.dart';
import 'add_line_item_dialogs.dart';

/// Modal dialog for delivering a vehicle to the customer, reviewing the invoice,
/// verifying warehouse parts withdrawals and labor cost, and capturing payment.
class DeliverWorkOrderDialog extends ConsumerStatefulWidget {
  const DeliverWorkOrderDialog({
    super.key,
    required this.order,
  });

  final WorkOrderWithDetails order;

  static Future<bool?> show(BuildContext context, {required WorkOrderWithDetails order}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeliverWorkOrderDialog(order: order),
    );
  }

  @override
  ConsumerState<DeliverWorkOrderDialog> createState() => _DeliverWorkOrderDialogState();
}

class _DeliverWorkOrderDialogState extends ConsumerState<DeliverWorkOrderDialog> {
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  late int _discountPiasters;
  late int _paidAmountPiasters;
  bool _userManuallyEditedPaid = false;

  final _refController = TextEditingController();
  final _notesController = TextEditingController();
  final _quickLaborDescController = TextEditingController(text: 'أتعاب صيانة ومصنعية');
  int _quickLaborPiasters = 0;

  late final List<WorkOrderLineItem> _lines;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _lines = List<WorkOrderLineItem>.from(widget.order.lines);
    _discountPiasters = widget.order.invoice?.discountAmount ?? 0;
    _paidAmountPiasters = _computedTotalPiasters;
  }

  @override
  void dispose() {
    _refController.dispose();
    _notesController.dispose();
    _quickLaborDescController.dispose();
    super.dispose();
  }

  int get _servicesTotalPiasters {
    return _lines
        .where((l) => l.isService)
        .fold<int>(0, (sum, l) => sum + l.totalPrice);
  }

  int get _partsTotalPiasters {
    return _lines
        .where((l) => l.isPart)
        .fold<int>(0, (sum, l) => sum + l.totalPrice);
  }

  int get _subtotalPiasters => _servicesTotalPiasters + _partsTotalPiasters;

  int get _computedTotalPiasters {
    final total = (_subtotalPiasters - _discountPiasters).clamp(0, double.maxFinite.toInt());
    return total;
  }

  int get _remainingPiasters {
    final rem = (_computedTotalPiasters - _paidAmountPiasters).clamp(0, double.maxFinite.toInt());
    return rem;
  }

  void _syncPaidAmount() {
    if (!_userManuallyEditedPaid) {
      _paidAmountPiasters = _computedTotalPiasters;
    }
  }

  void _addQuickLabor() {
    if (_quickLaborPiasters <= 0) {
      AppSnackbar.showError(context, 'يرجى كتابة تكلفة مصنعية أكبر من صفر.');
      return;
    }
    final desc = _quickLaborDescController.text.trim().isNotEmpty
        ? _quickLaborDescController.text.trim()
        : 'أتعاب صيانة ومصنعية';

    setState(() {
      _lines.add(
        WorkOrderLineItem(
          lineType: LineType.service,
          description: desc,
          quantity: 1,
          unitPrice: _quickLaborPiasters,
          totalPrice: _quickLaborPiasters,
        ),
      );
      _quickLaborPiasters = 0;
      _syncPaidAmount();
    });

    AppSnackbar.showSuccess(context, 'تمت إضافة تكلفة المصنعية بنجاح.');
  }

  Future<void> _submit() async {
    final isAlreadyInvoiced = widget.order.hasInvoice;

    if (!isAlreadyInvoiced && _lines.isEmpty) {
      AppSnackbar.showError(
        context,
        'لا يمكن إصدار فاتورة بدون بنود! يرجى تحديد تكلفة المصنعية أو إضافة القطع المسحوبة من المخزن.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Update lines if they were modified and not already invoiced
      if (!isAlreadyInvoiced) {
        await ref.read(workOrdersActionsControllerProvider).updateWorkOrder(
              id: widget.order.id,
              lines: _lines,
            );
      }

      // 2. Execute delivery and invoicing
      await ref.read(workOrdersActionsControllerProvider).deliverWorkOrder(
            id: widget.order.id,
            paymentMethod: _selectedPaymentMethod,
            paidAmountPiasters: _paidAmountPiasters,
            discountAmountPiasters: _discountPiasters,
            paymentReference: _refController.text.trim().isNotEmpty ? _refController.text.trim() : null,
            deliveryNotes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        AppSnackbar.showSuccess(context, AppStrings.deliverySuccessMessage);
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
    final isAlreadyInvoiced = widget.order.hasInvoice;
    final partLines = _lines.where((l) => l.isPart).toList();
    final serviceLines = _lines.where((l) => l.isService).toList();

    return AppFormDialog(
      title: AppStrings.deliverWorkOrderTitle,
      maxWidth: 720,
      isLoading: _isLoading,
      onSave: _submit,
      saveLabel: AppStrings.confirmDeliveryAndPayment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── 1. Order & Vehicle Identification Header ───────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.order.orderNumberFormatted,
                            style: const TextStyle(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.order.customer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Text(
                      widget.order.customer.phone ?? '',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    const Icon(Icons.directions_car_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${widget.order.vehicleDisplayTitle} • عداد: ${widget.order.workOrder.odometer ?? "غير مسجل"} كم',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                if (widget.order.workOrder.complaint != null && widget.order.workOrder.complaint!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.assignment_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'شكوى العميل: ${widget.order.workOrder.complaint}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 2. Verification of Warehouse Parts & Labor (Mandatory Check) ──
          if (!isAlreadyInvoiced) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            '١. مراجعة قطع الغيار المسحوبة من المخزن',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: () => AddPartLineDialog.show(
                          context,
                          onAdd: (line) {
                            setState(() {
                              _lines.add(line);
                              _syncPaidAmount();
                            });
                          },
                        ),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('+ سحب قطعة من المخزن', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Parts List or Empty Warning
                  if (partLines.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'لم يتم سحب أي قطع غيار من المخزن لهذا الأمر (أو قام العميل بإحضار القطع بنفسه).',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: partLines.map((part) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  part.description,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                              Text(
                                '${part.formattedQuantity} × ${part.formattedUnitPrice}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                part.formattedTotalPrice,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
                                tooltip: 'إلغاء هذا البند',
                                onPressed: () {
                                  setState(() {
                                    _lines.remove(part);
                                    _syncPaidAmount();
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 14),

                  // ── Services & Labor Cost Section ─────────────────────────
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.handyman_outlined, size: 18, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            '٢. تكلفة المصنعية وأتعاب الصيانة',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: () => AddServiceLineDialog.show(
                          context,
                          onAdd: (line) {
                            setState(() {
                              _lines.add(line);
                              _syncPaidAmount();
                            });
                          },
                        ),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('+ إضافة خدمة من الدليل', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Existing Services List
                  if (serviceLines.isNotEmpty) ...[
                    Column(
                      children: serviceLines.map((srv) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.build_circle_outlined, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  srv.description,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                              Text(
                                '${srv.formattedQuantity} × ${srv.formattedUnitPrice}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                srv.formattedTotalPrice,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
                                tooltip: 'إلغاء هذا البند',
                                onPressed: () {
                                  setState(() {
                                    _lines.remove(srv);
                                    _syncPaidAmount();
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Quick Labor Input Row (especially when no parts were taken)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: serviceLines.isEmpty
                          ? AppColors.primaryContainer.withValues(alpha: 0.25)
                          : AppColors.surfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: serviceLines.isEmpty ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceLines.isEmpty
                              ? '💡 لم تسحب قطعاً من المخزن؟ اكتب هنا تكلفة المصنعية الخاصة بك:'
                              : 'إضافة مصنعية أو أتعاب إضافية سريعة:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: serviceLines.isEmpty ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 460) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _quickLaborDescController,
                                    decoration: const InputDecoration(
                                      labelText: 'بيان المصنعية',
                                      hintText: 'مثال: مصنعية صيانة وإصلاح...',
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  MoneyField(
                                    initialPiasters: _quickLaborPiasters,
                                    label: 'المصنعية (جنيه)',
                                    onChangedPiasters: (p) => _quickLaborPiasters = p ?? 0,
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton.tonal(
                                    onPressed: _addQuickLabor,
                                    child: const Text('تسجيل المصنعية'),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _quickLaborDescController,
                                    decoration: const InputDecoration(
                                      labelText: 'بيان المصنعية',
                                      hintText: 'مثال: مصنعية صيانة وإصلاح...',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: MoneyField(
                                    initialPiasters: _quickLaborPiasters,
                                    label: 'المصنعية (جنيه)',
                                    onChangedPiasters: (p) => _quickLaborPiasters = p ?? 0,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton.tonal(
                                  onPressed: _addQuickLabor,
                                  child: const Text('تسجيل المصنعية'),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Warning if completely empty
                  if (_lines.isEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تنبيه: لا يمكن إصدار الفاتورة بدون بنود! يرجى كتابة تكلفة المصنعية أو تحديد قطع الغيار المسحوبة من المخزن.',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── 3. Invoice & Financial Breakdown ────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          AppStrings.invoiceSummaryTitle,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAlreadyInvoiced
                            ? AppColors.successContainer
                            : AppColors.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isAlreadyInvoiced
                            ? '${AppStrings.invoiceAlreadyIssued} (${widget.order.invoiceNumberFormatted})'
                            : AppStrings.invoiceWillBeCreated,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAlreadyInvoiced ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16, color: AppColors.divider),
                _AmountRow(
                  label: 'إجمالي المصنعيات والخدمات:',
                  value: MoneyUtils.formatPounds(_servicesTotalPiasters),
                ),
                const SizedBox(height: 4),
                _AmountRow(
                  label: 'إجمالي قطع الغيار المسحوبة:',
                  value: MoneyUtils.formatPounds(_partsTotalPiasters),
                ),
                const SizedBox(height: 8),

                // Discount Input
                if (!isAlreadyInvoiced) ...[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        flex: 3,
                        child: Text(
                          AppStrings.discountAmountLabel,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: MoneyField(
                          initialPiasters: _discountPiasters,
                          label: 'الخصم',
                          onChangedPiasters: (p) {
                            setState(() {
                              _discountPiasters = p ?? 0;
                              _syncPaidAmount();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                const Divider(height: 12, color: AppColors.divider),
                _AmountRow(
                  label: 'صافي الفاتورة الإجمالي المستحق:',
                  value: MoneyUtils.formatPounds(_computedTotalPiasters),
                  isBold: true,
                  valueColor: AppColors.primary,
                  fontSize: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 4. Payment Method Selector ─────────────────────────────────
          const Text(
            AppStrings.paymentMethodLabel,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              // خزنة الفرع (نقدي / كاش)
              _PaymentMethodChip(
                label: 'خزنة الفرع (كاش)',
                icon: Icons.payments_outlined,
                isSelected: _selectedPaymentMethod == PaymentMethod.cash,
                selectedColor: AppColors.success,
                onTap: () => setState(() => _selectedPaymentMethod = PaymentMethod.cash),
              ),

              // فودافون كاش
              _PaymentMethodChip(
                label: 'فودافون كاش',
                icon: Icons.phone_android_rounded,
                isSelected: _selectedPaymentMethod == PaymentMethod.wallet,
                selectedColor: Colors.red.shade700,
                onTap: () => setState(() => _selectedPaymentMethod = PaymentMethod.wallet),
              ),

              // إنستاباي InstaPay
              _PaymentMethodChip(
                label: 'إنستاباي (InstaPay)',
                icon: Icons.flash_on_rounded,
                isSelected: _selectedPaymentMethod == PaymentMethod.instapay,
                selectedColor: Colors.deepPurple.shade700,
                onTap: () => setState(() => _selectedPaymentMethod = PaymentMethod.instapay),
              ),

              // فيزا / كارت
              _PaymentMethodChip(
                label: 'بطاقة / فيزا',
                icon: Icons.credit_card_outlined,
                isSelected: _selectedPaymentMethod == PaymentMethod.card,
                selectedColor: Colors.blue.shade700,
                onTap: () => setState(() => _selectedPaymentMethod = PaymentMethod.card),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 5. Paid Amount & Remaining ─────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Paid Amount Field
              Expanded(
                flex: 3,
                child: MoneyField(
                  initialPiasters: _paidAmountPiasters,
                  label: AppStrings.paidAmountLabel,
                  onChangedPiasters: (p) {
                    setState(() {
                      _paidAmountPiasters = p ?? 0;
                      _userManuallyEditedPaid = true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Remaining Amount Display
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _remainingPiasters > 0 ? AppColors.errorContainer : AppColors.successContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _remainingPiasters > 0 ? AppColors.danger.withValues(alpha: 0.3) : AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppStrings.remainingAmountLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _remainingPiasters > 0 ? AppColors.danger : AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        MoneyUtils.formatPounds(_remainingPiasters),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _remainingPiasters > 0 ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Payment Reference field (important for Vodafone Cash & InstaPay)
          TextFormField(
            controller: _refController,
            decoration: InputDecoration(
              labelText: AppStrings.paymentReferenceLabel,
              hintText: _selectedPaymentMethod == PaymentMethod.wallet
                  ? 'رقم محفظة فودافون كاش أو كود التأكيد...'
                  : _selectedPaymentMethod == PaymentMethod.instapay
                      ? 'رقم المعاملة من تطبيق إنستاباي...'
                      : AppStrings.paymentReferenceHint,
              prefixIcon: const Icon(Icons.tag_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 10),

          // Delivery Notes
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'ملاحظات تسليم السيارة (اختياري)',
              hintText: 'أي ملاحظات خاصة بالتسليم أو حالة السيارة...',
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
    this.fontSize = 12,
  });

  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? selectedColor : AppColors.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: isSelected ? selectedColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
                color: isSelected ? selectedColor : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
