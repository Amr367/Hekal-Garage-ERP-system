import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/providers.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../invoices/presentation/widgets/invoice_preview_dialog.dart';
import '../../../settings/presentation/settings_controller.dart';
import '../../domain/work_order_with_details.dart';
import '../printing/job_card_builder.dart';
import '../work_orders_controller.dart';
import 'change_status_dialog.dart';
import 'deliver_work_order_dialog.dart';
import 'job_card_preview_dialog.dart';
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

  Future<void> _previewJobCard(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(garageProfileProvider).value;
    await JobCardPreviewDialog.show(
      context,
      order: order,
      garageProfile: profile,
    );
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

  Future<void> _previewInvoice(BuildContext context, WidgetRef ref) async {
    if (order.invoice == null) return;
    try {
      final invoicesRepo = ref.read(invoicesRepositoryProvider);
      final invoice = await invoicesRepo.getById(order.invoice!.id);
      if (invoice != null && context.mounted) {
        InvoicePreviewDialog.show(context, invoice: invoice);
      } else if (context.mounted) {
        AppSnackbar.showError(context, 'لم يتم العثور على سجل الفاتورة.');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'تعذر تحميل بيانات الفاتورة: $e');
      }
    }
  }

  Future<void> _editDiagnosis(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: order.workOrder.notes ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('تسجيل / تعديل التشخيص الفني (يدوي)'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اكتب هنا تقرير الفحص والتشخيص الفني الذي سجله الفني بعد فحص السيارة:',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'تقرير الفحص والتشخيص الفني',
                    hintText: 'اكتب تقرير التشخيص هنا...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('حفظ التشخيص'),
          ),
        ],
      ),
    );

    if (saved == true && context.mounted) {
      try {
        await ref.read(workOrdersActionsControllerProvider).updateWorkOrder(
              id: order.id,
              notes: controller.text.trim().isEmpty ? null : controller.text.trim(),
            );
        if (context.mounted) {
          AppSnackbar.showSuccess(context, 'تم حفظ التشخيص الفني بنجاح');
        }
      } catch (e) {
        if (context.mounted) {
          AppSnackbar.showError(context, 'تعذر حفظ التشخيص: $e');
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

                // Preview Invoice (if issued)
                if (order.hasInvoice && order.invoice != null)
                  FilledButton.tonalIcon(
                    onPressed: () => _previewInvoice(context, ref),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('معاينة الفاتورة'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.successContainer,
                      foregroundColor: AppColors.success,
                    ),
                  ),

                // Preview & Print Job Card
                FilledButton.tonalIcon(
                  onPressed: () => _previewJobCard(context, ref),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('معاينة كارت أمر الشغل'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.primary,
                  ),
                ),

                // Direct Print Job Card
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
                  // Schedule & Dates Box
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_outlined, color: AppColors.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 24,
                            runSpacing: 6,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('تاريخ دخول السيارة: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Text(
                                    order.formattedEntryDate,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('ميعاد الخروج المتوقع: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Text(
                                    order.formattedExpectedExitDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: order.expectedExitDate != null ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              if (order.isDelivered && order.actualExitDate != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('تاريخ الخروج الفعلي: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    Text(
                                      order.formattedActualExitDate,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

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
                          label: 'الموظف المستلم:',
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
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'تقرير الفحص والتشخيص الفني:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                          InkWell(
                            onTap: () => _editDiagnosis(context, ref),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    order.workOrder.notes?.trim().isNotEmpty == true
                                        ? Icons.edit_outlined
                                        : Icons.add_circle_outline,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    order.workOrder.notes?.trim().isNotEmpty == true
                                        ? 'تعديل التشخيص'
                                        : 'تسجيل التشخيص الفني',
                                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (order.workOrder.notes?.trim().isNotEmpty == true)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            order.workOrder.notes!,
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                          ),
                        )
                      else
                        const Text(
                          'لم يتم إدخال تشخيص بعد (يُكتب يدوياً بالقلم على كارت أمر الشغل المطبوع)',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                        ),
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
