import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/domain/garage_profile.dart';
import '../../domain/work_order_with_details.dart';
import '../printing/job_card_builder.dart';

/// Interactive on-screen preview dialog for the A4 Job Card & Repair Estimate.
class JobCardPreviewDialog extends StatelessWidget {
  const JobCardPreviewDialog({
    super.key,
    required this.order,
    this.garageProfile,
  });

  final WorkOrderWithDetails order;
  final GarageProfile? garageProfile;

  static Future<void> show(
    BuildContext context, {
    required WorkOrderWithDetails order,
    GarageProfile? garageProfile,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => JobCardPreviewDialog(
        order: order,
        garageProfile: garageProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final builder = JobCardBuilder(order: order, garageProfile: garageProfile);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 860),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'معاينة كارت أمر الشغل - ${order.orderNumberFormatted}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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

            // PDF Preview Viewport
            Expanded(
              child: PdfPreview(
                build: (PdfPageFormat format) => builder.buildPdf(),
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                pdfFileName: 'كارت_امر_شغل_${order.orderNumber}.pdf',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
