import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/printing/font_loader.dart';
import '../../../settings/domain/garage_profile.dart';
import '../../domain/work_order_with_details.dart';

/// Builds a professional A4 Job Card (كارت الورشة الداخلي وأمر الشغل) in Arabic RTL.
class JobCardBuilder {
  const JobCardBuilder({
    required this.order,
    this.garageProfile,
  });

  final WorkOrderWithDetails order;
  final GarageProfile? garageProfile;

  /// Generates the PDF document as bytes.
  Future<Uint8List> buildPdf() async {
    // Ensure Cairo fonts are ready
    try {
      PdfFontLoader.regular;
    } catch (_) {
      await PdfFontLoader.init();
    }

    final doc = pw.Document(
      theme: PdfFontLoader.arabicTheme,
    );

    final regular = PdfFontLoader.regular;
    final bold = PdfFontLoader.bold;
    final semiBold = PdfFontLoader.semiBold;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(regular, bold, semiBold),
        footer: (context) => _buildFooter(context, regular, semiBold),
        build: (context) => <pw.Widget>[
          _buildInfoCards(regular, bold, semiBold),
          pw.SizedBox(height: 14),
          _buildDiagnosisCard(regular, bold, semiBold),
          pw.SizedBox(height: 14),
          _buildLinesTable(regular, bold, semiBold),
          pw.SizedBox(height: 14),
          _buildTotalsSummary(regular, bold, semiBold),
          pw.SizedBox(height: 18),
          _buildSignaturesBox(regular, bold, semiBold),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildHeader(pw.Font regular, pw.Font bold, pw.Font semiBold) {
    final name = garageProfile?.name ?? 'مركز الصيانة للسيارات';
    final subtitle = garageProfile?.subtitle ?? 'كارت الصيانة ومتابعة الفحص الفني';
    final phone = garageProfile?.phone ?? '';

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 1.5),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 12),
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                name,
                style: pw.TextStyle(font: bold, fontSize: 18, color: PdfColors.blueGrey900),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                subtitle,
                style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey700),
              ),
              if (phone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'هاتف: $phone',
                  style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey800),
                ),
              ],
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey800, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              color: PdfColors.blueGrey50,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: <pw.Widget>[
                pw.Text(
                  'أمر شغل كارت ورشة',
                  style: pw.TextStyle(font: semiBold, fontSize: 11, color: PdfColors.blueGrey800),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  order.orderNumberFormatted,
                  style: pw.TextStyle(font: bold, fontSize: 18, color: PdfColors.blue900),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'الحالة: ${order.statusArabic}',
                  style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.grey800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoCards(pw.Font regular, pw.Font bold, pw.Font semiBold) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        // Customer Information Box
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              color: PdfColors.grey100,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'بيانات العميل',
                  style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.blue900),
                ),
                pw.SizedBox(height: 6),
                _buildInfoRow('الاسم:', order.customer.name, regular, bold),
                _buildInfoRow('الهاتف:', order.customer.phone ?? '-', regular, bold),
                _buildInfoRow('تاريخ الاستلام:', order.formattedCreatedAt, regular, regular),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        // Vehicle Information Box
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              color: PdfColors.grey100,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'بيانات السيارة',
                  style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.blue900),
                ),
                pw.SizedBox(height: 6),
                _buildInfoRow('رقم اللوحة:', order.normalizedPlate, regular, bold),
                _buildInfoRow(
                  'النوع / الموديل:',
                  '${order.vehicle.make} ${order.vehicle.model} ${order.vehicle.year ?? ''}'.trim(),
                  regular,
                  bold,
                ),
                _buildInfoRow(
                  'العداد الحالي:',
                  order.workOrder.odometer != null ? '${order.workOrder.odometer} كم' : 'غير مسجل',
                  regular,
                  regular,
                ),
                if (order.vehicle.chassisNumber != null && order.vehicle.chassisNumber!.isNotEmpty)
                  _buildInfoRow('الشاسيه (VIN):', order.vehicle.chassisNumber!, regular, regular),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInfoRow(String label, String value, pw.Font labelFont, pw.Font valFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Text(
            label,
            style: pw.TextStyle(font: labelFont, fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: valFont, fontSize: 10, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDiagnosisCard(pw.Font regular, pw.Font bold, pw.Font semiBold) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.amber300, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: PdfColors.amber50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(
                'شكوى العميل والأعمال المطلوبة:',
                style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.orange900),
              ),
              if (order.workOrder.mechanicName != null && order.workOrder.mechanicName!.isNotEmpty)
                pw.Text(
                  'الفني المسؤول: ${order.workOrder.mechanicName}',
                  style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.blueGrey900),
                ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            order.workOrder.complaint != null && order.workOrder.complaint!.isNotEmpty
                ? order.workOrder.complaint!
                : 'صيانة دورية وفحص عام',
            style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.black),
          ),
          if (order.workOrder.notes != null && order.workOrder.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'ملاحظات الفحص والتشخيص الأولي: ${order.workOrder.notes}',
              style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey800),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildLinesTable(pw.Font regular, pw.Font bold, pw.Font semiBold) {
    if (order.lines.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Text(
          'لم يتم تسجيل خدمات أو قطع غيار بعد في هذا الأمر.',
          style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.grey600),
        ),
      );
    }

    final rows = <pw.TableRow>[
      // Table Header
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
        children: <pw.Widget>[
          _cell('#', bold, 9, align: pw.TextAlign.center),
          _cell('نوع البند', bold, 9),
          _cell('بيان الخدمة / الصنف', bold, 9),
          _cell('الكمية', bold, 9, align: pw.TextAlign.center),
          _cell('السعر التقديري', bold, 9, align: pw.TextAlign.right),
          _cell('الإجمالي', bold, 9, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (int i = 0; i < order.lines.length; i++) {
      final line = order.lines[i];
      final isEven = i % 2 == 0;
      final typeTitle = line.isService ? 'مصنعية / خدمة' : 'قطعة غيار';

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: isEven ? PdfColors.white : PdfColors.grey50),
          children: <pw.Widget>[
            _cell('${i + 1}', regular, 9, align: pw.TextAlign.center),
            _cell(typeTitle, regular, 8),
            _cell(line.description, semiBold, 9),
            _cell('${line.formattedQuantity} ${line.itemUnit ?? ''}'.trim(), regular, 9, align: pw.TextAlign.center),
            _cell(line.formattedUnitPrice, regular, 9, align: pw.TextAlign.right),
            _cell(line.formattedTotalPrice, bold, 9, align: pw.TextAlign.right),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FixedColumnWidth(28),
        1: pw.FixedColumnWidth(80),
        2: pw.FlexColumnWidth(3),
        3: pw.FixedColumnWidth(65),
        4: pw.FixedColumnWidth(75),
        5: pw.FixedColumnWidth(85),
      },
      children: rows,
    );
  }

  pw.Widget _cell(
    String text,
    pw.Font font,
    double size, {
    pw.TextAlign align = pw.TextAlign.start,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: size, color: PdfColors.black),
      ),
    );
  }

  pw.Widget _buildTotalsSummary(pw.Font regular, pw.Font bold, pw.Font semiBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: <pw.Widget>[
        pw.Container(
          width: 240,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            color: PdfColors.grey100,
          ),
          child: pw.Column(
            children: <pw.Widget>[
              _totalRow('إجمالي المصنعيات:', order.formattedServicesTotal, regular),
              pw.SizedBox(height: 3),
              _totalRow('إجمالي قطع الغيار:', order.formattedPartsTotal, regular),
              pw.Divider(color: PdfColors.grey400, thickness: 1, height: 8),
              _totalRow('الإجمالي التقديري:', order.formattedTotal, bold, isGrand: true),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _totalRow(String label, String value, pw.Font font, {bool isGrand = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: isGrand ? 11 : 9,
            color: isGrand ? PdfColors.blue900 : PdfColors.grey800,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: font,
            fontSize: isGrand ? 12 : 9,
            color: isGrand ? PdfColors.blue900 : PdfColors.black,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSignaturesBox(pw.Font regular, pw.Font bold, pw.Font semiBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: <pw.Widget>[
          _sigColumn('مهندس الاستقبال', regular),
          _sigColumn('الفني المنفذ', regular),
          _sigColumn('توقيع العميل بالاستلام', regular),
        ],
      ),
    );
  }

  pw.Widget _sigColumn(String title, pw.Font font) {
    return pw.Column(
      children: <pw.Widget>[
        pw.Text(title, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
        pw.SizedBox(height: 25),
        pw.Container(width: 100, height: 1, color: PdfColors.grey400),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context, pw.Font regular, pw.Font semiBold) {
    final footer = garageProfile?.invoiceFooterNote ??
        'تم استلام السيارة للفحص والصيانة وفقاً لشروط وضوابط الورشة.';
    return pw.Column(
      children: <pw.Widget>[
        pw.Divider(color: PdfColors.grey400, thickness: 0.8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text(
              footer,
              style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'صفحة ${context.pageNumber} من ${context.pagesCount}',
              style: pw.TextStyle(font: semiBold, fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }
}
