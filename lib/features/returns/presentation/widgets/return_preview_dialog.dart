import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/domain/garage_profile.dart';
import '../../../settings/presentation/settings_controller.dart';
import '../../domain/return_with_details.dart';
import '../printing/return_receipt_builder.dart';

enum ReturnPrintFormat { a4, thermal }

/// Interactive modal preview for Returns (A4 & 80mm thermal receipt formats).
class ReturnPreviewDialog extends ConsumerStatefulWidget {
  const ReturnPreviewDialog({
    super.key,
    required this.returnData,
    this.garageProfile,
  });

  final ReturnWithDetails returnData;
  final GarageProfile? garageProfile;

  static Future<void> show(
    BuildContext context, {
    required ReturnWithDetails returnData,
    GarageProfile? garageProfile,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ReturnPreviewDialog(
        returnData: returnData,
        garageProfile: garageProfile,
      ),
    );
  }

  @override
  ConsumerState<ReturnPreviewDialog> createState() => _ReturnPreviewDialogState();
}

class _ReturnPreviewDialogState extends ConsumerState<ReturnPreviewDialog> {
  ReturnPrintFormat _format = ReturnPrintFormat.a4;

  Future<Uint8List> _generatePdf() async {
    final GarageProfile profile = widget.garageProfile ??
        await ref.read(garageProfileProvider.future);

    final doc = _format == ReturnPrintFormat.a4
        ? ReturnReceiptBuilder.buildA4(widget.returnData, profile)
        : ReturnReceiptBuilder.buildThermalReceipt(widget.returnData, profile);

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final ret = widget.returnData;

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
                  const Icon(Icons.assignment_return_outlined,
                      color: AppColors.primary, size: 24),
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
                              'معاينة إذن المرتجع - ${ret.returnNumberFormatted}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: ret.isSaleReturn
                                    ? AppColors.warningContainer
                                    : AppColors.secondaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ret.typeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: ret.isSaleReturn
                                      ? AppColors.warning
                                      : AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${ret.partyName} • ${ret.formattedTotalAmount}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Format Selector (A4 vs Thermal)
                  SegmentedButton<ReturnPrintFormat>(
                    segments: const [
                      ButtonSegment<ReturnPrintFormat>(
                        value: ReturnPrintFormat.a4,
                        label: Text(AppStrings.printReturnA4),
                        icon: Icon(Icons.description_outlined, size: 16),
                      ),
                      ButtonSegment<ReturnPrintFormat>(
                        value: ReturnPrintFormat.thermal,
                        label: Text(AppStrings.printReturnThermal),
                        icon: Icon(Icons.receipt_outlined, size: 16),
                      ),
                    ],
                    selected: {_format},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _format = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(width: 12),

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
                key: ValueKey(_format),
                build: (PdfPageFormat _) => _generatePdf(),
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                pdfFileName: 'إذن_مرتجع_${ret.returnNumber}.pdf',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
