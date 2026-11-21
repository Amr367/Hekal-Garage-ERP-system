import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/domain/garage_profile.dart';
import '../../../settings/presentation/settings_controller.dart';
import '../../domain/purchase_invoice_with_details.dart';
import '../../domain/purchase_print_builder.dart';

/// Interactive modal preview for Purchase Invoices and Inbound Stock Receipts.
class PurchasePreviewDialog extends ConsumerWidget {
  const PurchasePreviewDialog({
    super.key,
    required this.purchase,
    this.garageProfile,
  });

  final PurchaseInvoiceWithDetails purchase;
  final GarageProfile? garageProfile;

  static Future<void> show(
    BuildContext context, {
    required PurchaseInvoiceWithDetails purchase,
    GarageProfile? garageProfile,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PurchasePreviewDialog(
        purchase: purchase,
        garageProfile: garageProfile,
      ),
    );
  }

  Future<Uint8List> _generatePdf(WidgetRef ref) async {
    final GarageProfile profile = garageProfile ?? await ref.read(garageProfileProvider.future);
    final doc = PurchasePrintBuilder.buildA4(purchase, profile);
    return doc.save();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 880),
        child: Column(
          children: [
            // ── Header Bar ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              '${AppStrings.purchasePreviewTitle} - #${purchase.id}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: purchase.paymentStatus == PurchasePaymentStatus.paid
                                    ? AppColors.successContainer
                                    : (purchase.paymentStatus == PurchasePaymentStatus.partial
                                        ? AppColors.warningContainer
                                        : AppColors.dangerContainer),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                purchase.paymentStatusArabic,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: purchase.paymentStatus == PurchasePaymentStatus.paid
                                      ? AppColors.success
                                      : (purchase.paymentStatus == PurchasePaymentStatus.partial
                                          ? AppColors.warning
                                          : AppColors.danger),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${purchase.supplier.name} • ${purchase.formattedDate} • ${purchase.lines.length} صنف',
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: AppStrings.close,
                  ),
                ],
              ),
            ),

            // ── PDF Interactive Viewer ─────────────────────────────────────────
            Expanded(
              child: PdfPreview(
                build: (PdfPageFormat format) => _generatePdf(ref),
                allowPrinting: true,
                allowSharing: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                initialPageFormat: PdfPageFormat.a4,
                pdfFileName: 'purchase_invoice_${purchase.id}.pdf',
                loadingWidget: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(AppStrings.loadingData),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
