import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/invoice_with_details.dart';
import '../invoices_controller.dart';
import 'cancel_invoice_dialog.dart';
import 'invoice_payment_dialog.dart';
import 'invoice_preview_dialog.dart';

/// Desktop right-side inspector panel for viewing, printing, and managing selected invoice.
class InvoiceDetailsPane extends ConsumerWidget {
  const InvoiceDetailsPane({
    super.key,
    required this.invoice,
    this.width = 380,
  });

  final InvoiceWithDetails invoice;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Pane Header ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      invoice.invoiceNumberFormatted,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(invoice: invoice),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'إغلاق التفاصيل',
                  onPressed: () => ref.read(selectedInvoiceIdProvider.notifier).select(null),
                ),
              ],
            ),
          ),

          // ── Scrollable Content ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Quick Actions Bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: () => InvoicePreviewDialog.show(context, invoice: invoice),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('معاينة الفاتورة'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryContainer,
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref.read(invoicesActionsProvider).printA4(context, invoice),
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('طباعة الفاتورة'),
                      ),
                      if (invoice.remainingPiasters > 0 && !invoice.isCancelled)
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.successContainer,
                            foregroundColor: AppColors.success,
                          ),
                          onPressed: () => InvoicePaymentDialog.show(context, invoice: invoice),
                          icon: const Icon(Icons.payments_outlined, size: 16),
                          label: const Text('تحصيل دفعة'),
                        ),
                      if (!invoice.isCancelled)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                          ),
                          onPressed: () => CancelInvoiceDialog.show(context, invoice: invoice),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('إلغاء الفاتورة'),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Customer & Car Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _InfoRow(label: 'العميل:', value: invoice.customerName, isBold: true),
                        const SizedBox(height: 6),
                        _InfoRow(label: 'الهاتف:', value: invoice.customerPhone),
                        if (invoice.vehicle != null) ...[
                          const SizedBox(height: 6),
                          _InfoRow(label: 'المركبة:', value: invoice.vehicleTitle),
                        ],
                        if (invoice.workOrder != null) ...[
                          const SizedBox(height: 6),
                          _InfoRow(label: 'أمر الشغل:', value: '#${invoice.workOrder!.orderNumber}'),
                        ],
                        const SizedBox(height: 6),
                        _InfoRow(label: 'تاريخ الإصدار:', value: invoice.formattedDate),
                        const SizedBox(height: 6),
                        _InfoRow(label: 'طريقة التحصيل:', value: invoice.paymentMethodLabel),
                      ],
                    ),
                  ),

                  if (invoice.isCancelled) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.cancel, color: AppColors.danger, size: 16),
                              SizedBox(width: 6),
                              Text('تفاصيل الإلغاء', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('سبب الإلغاء: ${invoice.invoice.cancellationReason ?? "-"}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Line Items
                  const Text('بنود ومحتويات الفاتورة', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: invoice.lines.map((l) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    Text(
                                      '${l.formattedQuantity} × ${l.formattedUnitPrice}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(l.formattedTotalPrice, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Financial Totals
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _TotalRow(label: 'المجموع الفرعي:', value: invoice.formattedSubtotal),
                        if (invoice.discountPiasters > 0)
                          _TotalRow(label: 'الخصم:', value: '- ${invoice.formattedDiscount}'),
                        const Divider(height: 12),
                        _TotalRow(
                          label: 'إجمالي الفاتورة الصافي:',
                          value: invoice.formattedTotal,
                          isBold: true,
                          color: AppColors.primary,
                          fontSize: 15,
                        ),
                        const Divider(height: 12),
                        _TotalRow(label: 'المبلغ المسدد:', value: invoice.formattedPaid, color: AppColors.success),
                        _TotalRow(
                          label: 'المتبقي المستحق:',
                          value: invoice.formattedRemaining,
                          isBold: true,
                          color: invoice.remainingPiasters > 0 ? AppColors.danger : AppColors.success,
                          fontSize: 14,
                        ),
                      ],
                    ),
                  ),

                  // Payments history
                  if (invoice.payments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('سجل الدفعات والتحصيلات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...invoice.payments.map((p) {
                      final methodText = switch (p.paymentMethod) {
                        PaymentMethod.cash => 'خزنة (كاش)',
                        PaymentMethod.instapay => 'انستاباي',
                        PaymentMethod.wallet => 'فودافون كاش',
                        PaymentMethod.card => 'فيزا / كارت',
                        PaymentMethod.transfer => 'تحويل بنكي',
                      };
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(methodText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  if (p.notes != null)
                                    Text(
                                      p.notes!,
                                      style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(p.amount / 100).toStringAsFixed(2)} ج.م',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.invoice});

  final InvoiceWithDetails invoice;

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = switch (true) {
      _ when invoice.isCancelled => (AppColors.danger, AppColors.dangerContainer),
      _ when invoice.isPaid => (AppColors.success, AppColors.successContainer),
      _ when invoice.isPartiallyPaid => (AppColors.warning, AppColors.warningContainer),
      _ => (AppColors.danger, AppColors.dangerContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        invoice.statusLabel,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
    this.fontSize = 13,
  });

  final String label;
  final String value;
  final bool isBold;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, fontSize: fontSize),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              fontSize: fontSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
