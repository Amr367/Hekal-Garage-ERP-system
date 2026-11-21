import 'package:flutter/material.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/purchase_invoice_with_details.dart';
import 'purchase_preview_dialog.dart';

/// Desktop right-side master-detail panel displaying purchase invoice details.
class PurchaseDetailsPane extends StatelessWidget {
  const PurchaseDetailsPane({
    super.key,
    required this.purchase,
    required this.onClose,
  });

  final PurchaseInvoiceWithDetails purchase;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final statusColor = purchase.paymentStatus == PurchasePaymentStatus.paid
        ? AppColors.success
        : (purchase.paymentStatus == PurchasePaymentStatus.partial
            ? AppColors.warning
            : AppColors.danger);

    final statusContainerColor = purchase.paymentStatus == PurchasePaymentStatus.paid
        ? AppColors.successContainer
        : (purchase.paymentStatus == PurchasePaymentStatus.partial
            ? AppColors.warningContainer
            : AppColors.dangerContainer);

    return Container(
      width: 440,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 1),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${AppStrings.purchaseInvoiceNumberPrefix}${purchase.id}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      if (purchase.supplierInvoiceNumber != null &&
                          purchase.supplierInvoiceNumber!.isNotEmpty)
                        Text(
                          '${AppStrings.supplierInvoiceNumPrefix}${purchase.supplierInvoiceNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => PurchasePreviewDialog.show(context, purchase: purchase),
                  icon: const Icon(Icons.print_outlined),
                  tooltip: AppStrings.printPurchaseButton,
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: AppStrings.close,
                ),
              ],
            ),
          ),

          // ── Scrollable Body ────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                // Supplier Info Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(Icons.store, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              purchase.supplier.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (purchase.supplier.phone != null &&
                          purchase.supplier.phone!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            const Icon(Icons.phone, size: 16, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(
                              purchase.supplier.phone!,
                              style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          const Icon(Icons.calendar_today, size: 16, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            '${AppStrings.invoiceDateLabel}: ${purchase.formattedDate}',
                            style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Financial Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              AppStrings.purchaseAccountStatus,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusContainerColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              purchase.paymentStatusArabic,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _AmountRow(
                        label: AppStrings.invoiceTotalAmount,
                        value: purchase.formattedTotal,
                        isBold: true,
                      ),
                      const SizedBox(height: 6),
                      _AmountRow(
                        label: AppStrings.invoicePaidAmount,
                        value: purchase.formattedPaid,
                        valueColor: AppColors.success,
                      ),
                      const SizedBox(height: 6),
                      _AmountRow(
                        label: AppStrings.invoiceRemainingAmount,
                        value: purchase.formattedRemaining,
                        valueColor: purchase.remainingAmountPiasters > 0
                            ? AppColors.danger
                            : AppColors.onSurfaceVariant,
                        isBold: purchase.remainingAmountPiasters > 0,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Lines Title
                Row(
                  children: <Widget>[
                    const Icon(Icons.list_alt, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${AppStrings.purchaseLinesTitle} (${purchase.lines.length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Lines List
                ...purchase.lines.map((line) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                line.itemName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              line.formattedTotal,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            if (line.itemSku != null && line.itemSku!.isNotEmpty) ...<Widget>[
                              Text(
                                '${line.itemSku!}  •  ',
                                style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                '${AppStrings.lineQty}: ${line.formattedQuantity} ${line.itemUnit} × ${line.formattedUnitCost}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                if (purchase.notes != null && purchase.notes!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          AppStrings.columnNotes,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          purchase.notes!,
                          style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Actions Footer ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 1),
              ),
            ),
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => PurchasePreviewDialog.show(context, purchase: purchase),
                icon: const Icon(Icons.print_outlined),
                label: const Text(AppStrings.printPurchaseButton),
              ),
            ),
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
    this.valueColor,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
