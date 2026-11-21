import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/domain/garage_profile.dart';
import '../../../settings/presentation/settings_controller.dart';
import '../../domain/invoice_print_builder.dart';
import '../../domain/invoice_with_details.dart';

/// Interactive modal preview for Invoices (A4 standard format).
class InvoicePreviewDialog extends ConsumerWidget {
  const InvoicePreviewDialog({
    super.key,
    required this.invoice,
    this.garageProfile,
  });

  final InvoiceWithDetails invoice;
  final GarageProfile? garageProfile;

  static Future<void> show(
    BuildContext context, {
    required InvoiceWithDetails invoice,
    GarageProfile? garageProfile,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => InvoicePreviewDialog(
        invoice: invoice,
        garageProfile: garageProfile,
      ),
    );
  }

  Future<Uint8List> _generatePdf(WidgetRef ref) async {
    final GarageProfile profile = garageProfile ?? await ref.read(garageProfileProvider.future);
    final doc = InvoicePrintBuilder.buildA4(invoice, profile);
    return doc.save();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = invoice;

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
                border: Border(bottom: BorderSide(color: AppColors.border)),
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
                              'معاينة الفاتورة - ${inv.invoiceNumberFormatted}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: inv.isCancelled
                                    ? AppColors.dangerContainer
                                    : AppColors.successContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                inv.statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: inv.isCancelled ? AppColors.danger : AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${inv.customerName} • ${inv.vehicleTitle}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── PDF Preview Viewport ──────────────────────────────────────────
            Expanded(
              child: PdfPreview(
                build: (PdfPageFormat _) => _generatePdf(ref),
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                pdfFileName: 'فاتورة_${inv.invoiceNumber}.pdf',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
