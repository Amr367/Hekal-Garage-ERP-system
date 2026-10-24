import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/db/database.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../settings/presentation/settings_controller.dart';
import '../../domain/work_order_with_details.dart';
import '../printing/job_card_builder.dart';
import '../work_orders_controller.dart';
import 'change_status_dialog.dart';
import 'deliver_work_order_dialog.dart';
import 'work_order_form_dialog.dart';

/// Desktop right-side master-detail pane for inspecting and managing a work order.
class WorkOrderDetailsPane extends ConsumerWidget {
  const WorkOrderDetailsPane({
    super.key,
    required this.order,
  });

  final WorkOrderWithDetails order;

  Future<void> _advanceStatus(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(workOrdersActionsControllerProvider);
    WorkOrderStatus nextStatus;
    String successMsg;

    switch (order.status) {
      case WorkOrderStatus.open:
        nextStatus = WorkOrderStatus.inProgress;
        successMsg = 'تم بدء العمل بالسيارة';
        break;
      case WorkOrderStatus.inProgress:
        nextStatus = WorkOrderStatus.ready;
        successMsg = 'تم إنهاء العمل وجاهزية السيارة للاستلام';
        break;
      case WorkOrderStatus.ready:
        await DeliverWorkOrderDialog.show(context, order: order);
        return;
      default:
        return;
    }

    try {
      await actions.updateStatus(id: order.id, status: nextStatus);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, successMsg);
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, e.toString());
      }
    }
  }

  Future<void> _printJobCard(BuildContext context, WidgetRef ref) async {
    try {
      final profile = ref.read(garageProfileProvider).value;
      final builder = JobCardBuilder(order: order, garageProfile: profile);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) => builder.buildPdf(),
        name: 'كارت_ورشة_${order.orderNumber}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'فشل إنشاء كارت الورشة: $e');
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: AppStrings.deleteWorkOrderButton,
      message: 'هل أنت متأكد من حذف أمر الشغل ${order.orderNumberFormatted}؟ سيتم حذف جميع البنود المسجلة به نهائياً.',
      isDestructive: true,
      confirmLabel: 'حذف الأمر',
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(workOrdersActionsControllerProvider).deleteWorkOrder(order.id);
        if (context.mounted) {
          AppSnackbar.showSuccess(context, 'تم حذف أمر الشغل بنجاح');
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackbar.showError(context, e.toString());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Pane Header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: order.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.statusArabic,
                        style: TextStyle(
                          color: order.statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      order.orderNumberFormatted,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'إغلاق المعاينة',
                  onPressed: () {
                    ref.read(selectedWorkOrderIdProvider.notifier).set(null);
                  },
                ),
              ],
            ),
          ),

          // ── Quick Actions Bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppColors.background,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                // Primary Status Advancement Button
                if (order.isOpen)
                  ElevatedButton.icon(
                    onPressed: () => _advanceStatus(context, ref),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text(AppStrings.startWork),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                  )
                else if (order.isInProgress)
                  ElevatedButton.icon(
                    onPressed: () => _advanceStatus(context, ref),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text(AppStrings.markReady),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.onPrimary,
                    ),
                  )
                else if (order.isReady)
                  ElevatedButton.icon(
                    onPressed: () => DeliverWorkOrderDialog.show(context, order: order),
                    icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                    label: const Text(AppStrings.deliverWorkOrderButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.onPrimary,
                    ),
                  ),

                // Print Job Card
                OutlinedButton.icon(
                  onPressed: () => _printJobCard(context, ref),
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text(AppStrings.printJobCardButton),
                ),

                // Edit Button
                if (order.canEdit)
                  OutlinedButton.icon(
                    onPressed: () => WorkOrderFormDialog.show(context, order: order),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text(AppStrings.editWorkOrderButton),
                  ),

                // Change Status Dropdown
                OutlinedButton.icon(
                  onPressed: () => ChangeStatusDialog.show(context, order: order),
                  icon: const Icon(Icons.sync_alt_rounded, size: 16),
                  label: const Text(AppStrings.changeStatusButton),
                ),

                // Delete Button
                if (order.canDelete)
                  OutlinedButton.icon(
                    onPressed: () => _delete(context, ref),
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                    label: const Text(
                      AppStrings.deleteWorkOrderButton,
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ),

          // ── Scrollable Details Body ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Customer & Vehicle Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Customer Box
                      Expanded(
                        child: _DetailBox(
                          title: 'بيانات العميل',
                          icon: Icons.person_outline,
                          children: <Widget>[
                            _InfoRow(label: 'الاسم:', value: order.customer.name, isBold: true),
                            _InfoRow(label: 'الهاتف:', value: order.customer.phone ?? '-'),
                            _InfoRow(label: 'تاريخ الفتح:', value: order.formattedCreatedAt),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Vehicle Box
                      Expanded(
                        child: _DetailBox(
                          title: 'بيانات المركبة',
                          icon: Icons.directions_car_outlined,
                          children: <Widget>[
                            _InfoRow(label: 'رقم اللوحة:', value: order.normalizedPlate, isBold: true),
                            _InfoRow(
                              label: 'السيارة:',
                              value: '${order.vehicle.make} ${order.vehicle.model} ${order.vehicle.year ?? ''}'.trim(),
                            ),
                            _InfoRow(
                              label: 'العداد:',
                              value: order.workOrder.odometer != null ? '${order.workOrder.odometer} كم' : 'غير مسجل',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Complaint & Diagnosis
                  _DetailBox(
                    title: 'الشكوى والفحص الفني',
                    icon: Icons.assignment_outlined,
                    children: <Widget>[
                      if (order.workOrder.mechanicName != null)
                        _InfoRow(
                          label: 'الفني المسؤول:',
                          value: order.workOrder.mechanicName!,
                          isBold: true,
                        ),
                      const SizedBox(height: 4),
                      const Text(
                        'شكوى العميل / المطلوب:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.workOrder.complaint ?? 'صيانة دورية وفحص عام',
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                      if (order.workOrder.notes != null && order.workOrder.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'ملاحظات الفحص والتشخيص الأولي:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.workOrder.notes!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Lines Table
                  const Text(
                    'بنود الصيانة وقطع الغيار المطلوبة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),

                  if (order.lines.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'لم يتم تسجيل مصنعيات أو قطع غيار بعد',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            color: AppColors.surfaceVariant,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: const Row(
                              children: <Widget>[
                                SizedBox(width: 60, child: Text('النوع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 3, child: Text('البيان', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                SizedBox(width: 60, child: Text('الكمية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                SizedBox(width: 80, child: Text('السعر', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                SizedBox(width: 90, child: Text('الإجمالي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          ...order.lines.map((l) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: AppColors.divider)),
                              ),
                              child: Row(
                                children: <Widget>[
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      l.isService ? 'خدمة' : 'قطعة',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: l.isService ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      l.description,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      l.formattedQuantity,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      l.formattedUnitPrice,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      l.formattedTotalPrice,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),

                  // Financial Totals Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: <Widget>[
                        _TotalLine(label: 'إجمالي المصنعيات:', value: order.formattedServicesTotal),
                        const SizedBox(height: 6),
                        _TotalLine(label: 'إجمالي قطع الغيار:', value: order.formattedPartsTotal),
                        const Divider(height: 16, color: AppColors.divider),
                        _TotalLine(
                          label: order.hasInvoice ? 'إجمالي الفاتورة:' : 'الإجمالي التقديري للصيانة:',
                          value: order.formattedTotal,
                          isGrand: true,
                        ),
                        if (order.hasInvoice) ...[
                          const Divider(height: 16, color: AppColors.divider),
                          _TotalLine(
                            label: 'رقم الفاتورة الصادرة:',
                            value: order.invoiceNumberFormatted ?? '-',
                          ),
                          if (order.paymentMethodArabic != null) ...[
                            const SizedBox(height: 6),
                            _TotalLine(
                              label: 'طريقة السداد:',
                              value: order.paymentMethodArabic!,
                            ),
                          ],
                          if (order.paymentReference != null && order.paymentReference!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _TotalLine(
                              label: 'مرجع التحويل / العملية:',
                              value: order.paymentReference!,
                            ),
                          ],
                          const SizedBox(height: 6),
                          _TotalLine(
                            label: 'المبلغ المسدد:',
                            value: order.formattedPaidAmount,
                          ),
                          if (order.remainingAmountPiasters > 0) ...[
                            const SizedBox(height: 6),
                            _TotalLine(
                              label: 'المتبقي على العميل:',
                              value: order.formattedRemainingAmount,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBox extends StatelessWidget {
  const _DetailBox({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.value,
    this.isGrand = false,
  });

  final String label;
  final String value;
  final bool isGrand;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: isGrand ? 13 : 11,
            fontWeight: isGrand ? FontWeight.bold : FontWeight.w500,
            color: isGrand ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isGrand ? 16 : 12,
            fontWeight: FontWeight.bold,
            color: isGrand ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
