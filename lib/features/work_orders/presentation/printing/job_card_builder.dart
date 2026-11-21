import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/printing/car_brand_logos.dart';
import '../../../../core/printing/font_loader.dart';
import '../../../settings/domain/garage_profile.dart';
import '../../domain/work_order_with_details.dart';

/// Builds a 1-page A4 Job Card (كارت أمر شغل وصيانة)
/// with vehicle & customer info, complaint, tasks, parts, and signatures,
/// without financial prices/costs (financial totals belong strictly to invoices).
class JobCardBuilder {
  const JobCardBuilder({
    required this.order,
    this.garageProfile,
  });

  final WorkOrderWithDetails order;
  final GarageProfile? garageProfile;

  static final PdfColor _primaryRed = PdfColor.fromHex('#B71C1C');
  static final PdfColor _darkBorder = PdfColor.fromHex('#1A1A1A');

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
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            // ── Top Header: Brand, Badges, Title, Serial # ──────────────
            _buildHeader(regular, bold, semiBold),
            pw.SizedBox(height: 5),

            // ── Customer & Vehicle Information Box ──────────────────────
            _buildInfoBox(regular, bold, semiBold),
            pw.SizedBox(height: 5),

            // ── Complaint ("مشاكله") & Vehicle Inspection ("فحص") Box ───
            _buildComplaintAndInspectionBox(regular, bold, semiBold),
            pw.SizedBox(height: 5),

            // ── Main Tasks & Parts Table (WITHOUT prices/costs) ──────────
            _buildEstimateTable(regular, bold, semiBold),
            pw.SizedBox(height: 4),


            // ── Work Order Summary Bar (item counts & execution note) ───
            _buildSummaryBar(regular, bold),
            pw.SizedBox(height: 4),


            _buildReturnsSection(regular, bold),
            pw.SizedBox(height: 4),
            // ── Customer Disclaimer Note in Red ──────────────────────────
            _buildCustomerDisclaimer(bold),
            pw.SizedBox(height: 6),

            // ── Signatures Box ───────────────────────────────────────────
            _buildSignatures(regular, bold),
            pw.Spacer(),

            // ── Bottom Contact Phone Numbers ─────────────────────────────
            _buildBottomContacts(bold),
          ],
        ),
      ),
    );

    return doc.save();
  }

  // ── Header ────────────────────────────────────────────────────────────────
  // Note: in RTL, children[0] is positioned on the RIGHT, and children[last] on the LEFT.
  pw.Widget _buildHeader(pw.Font regular, pw.Font bold, pw.Font semiBold) {
    final garageName = garageProfile?.name.isNotEmpty == true ? garageProfile!.name : 'مركز هيكل';
    final garageSubtitle = garageProfile?.subtitle.isNotEmpty == true ? garageProfile!.subtitle : 'لاصلاح السيارات';
    final serialText = order.orderNumber.toString().padLeft(3, '0');

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        // Right: Garage Name & Subtitle
        pw.Container(
          width: 140,
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: <pw.Widget>[
              pw.Text(
                garageName,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 22,
                  color: _primaryRed,
                ),
              ),
              pw.Text(
                garageSubtitle,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 13,
                  color: _primaryRed,
                ),
              ),
            ],
          ),
        ),

        // Center: Row of Car Logos + Centered Title "كارت أمر شغل وفحص"
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: <pw.Widget>[
              CarBrandLogos.banner(bold: bold),
              pw.SizedBox(height: 4),

              pw.Text(
                'مقايسة اصلاح',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 18,
                  color: _primaryRed,
                ),
              ),
            ],
          ),
        ),

        // Left: Serial Number (e.g. 055)
        pw.Container(
          width: 90,
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            serialText,
            style: pw.TextStyle(
              font: bold,
              fontSize: 26,
              color: _primaryRed,
            ),
          ),
        ),
      ],
    );
  }

  // ── Customer & Vehicle Information Box ────────────────────────────────────
  pw.Widget _buildInfoBox(pw.Font regular, pw.Font bold, pw.Font semiBold) {
    // Left column data in scan: تليفون العميل, حالة أمر الشغل, عداد الكيلومتر, ميعاد الخروج, تاريخ الدخول, نوع الخدمة
    final customerPhone = order.customer.phone?.trim().isNotEmpty == true ? order.customer.phone! : '—';
    final mechanic = order.workOrder.mechanicName?.trim().isNotEmpty == true ? order.workOrder.mechanicName! : '—';
    final entryDateStr = order.formattedEntryDate;
    final expectedExitDateStr = order.formattedExpectedExitDate;
    final orderNumStr = '#${order.orderNumber}';
    final odometerStr = order.workOrder.odometer != null ? '${order.workOrder.odometer} كم' : '—';

    // Right column data in scan: اسم العميل, رقم أمر الشغل, رقم اللوحة, الموديل, رقم الشاسية, الموظف المستلم
    final customerName = order.customer.name;
    final plate = order.normalizedPlate;
    final colorStr = order.vehicle.color?.trim().isNotEmpty == true ? ' (${order.vehicle.color})' : '';
    final modelStr = '${order.vehicle.make ?? ''} ${order.vehicle.model ?? ''} ${order.vehicle.year ?? ''}$colorStr'.trim();
    final chassisStr = order.vehicle.chassisNumber?.trim().isNotEmpty == true ? order.vehicle.chassisNumber! : '—';

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _darkBorder, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          // Right Column in RTL (children[0] renders on the RIGHT)
          pw.Expanded(
            child: pw.Column(
              children: <pw.Widget>[
                _buildInfoCell('اسم العميل', customerName, regular, bold, isTop: true),
                _buildInfoCell('الموظف المستلم', mechanic, regular, bold),
                _buildInfoCell('رقم اللوحة المعدنية', plate, regular, bold),
                _buildInfoCell('الموديل واللون', modelStr.isEmpty ? '—' : modelStr, regular, bold),
                _buildInfoCell('رقم الشاسية', chassisStr, regular, bold),
                _buildInfoCell('ميعاد الخروج المتوقع', expectedExitDateStr, regular, bold, isBottom: true),
              ],
            ),
          ),

          // Vertical dividing line
          pw.Container(
            width: 1.2,
            height: 6 * 20.0,
            color: _darkBorder,
          ),

          // Left Column in RTL (children[2] renders on the LEFT)
          pw.Expanded(
            child: pw.Column(
              children: <pw.Widget>[
                _buildInfoCell('تليفون العميل', customerPhone, regular, bold, isTop: true),
                _buildInfoCell('حالة أمر الشغل', order.statusArabic, regular, bold),
                _buildInfoCell('تاريخ دخول السيارة', entryDateStr, regular, bold),
                _buildInfoCell('رقم أمر الشغل', orderNumStr, regular, bold),
                _buildInfoCell('قراءة عداد الكيلومتر', odometerStr, regular, bold),
                _buildInfoCell('نوع الخدمة', 'فحص وإصلاح صيانة', regular, bold, isBottom: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Customer Complaint ("مشاكله") & Vehicle Inspection ("فحص") Box ────────
  pw.Widget _buildComplaintAndInspectionBox(pw.Font regular, pw.Font bold, pw.Font semiBold) {
    final complaintText = order.workOrder.complaint?.trim().isNotEmpty == true
        ? order.workOrder.complaint!.trim()
        : 'فحص عام وصيانة دورية شاملة (لم تسجل شكوى خاصة من العميل)';

    final manualNotes = printableWorkshopNote(order.workOrder.notes);
    final hasManualNotes = manualNotes != null && manualNotes.isNotEmpty;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _darkBorder, width: 1.1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          // Section 1: شكوى العميل والأعطال المشكو منها ("مشاكله")
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: _primaryRed,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Text(
                    'شكوى العميل والأعطال (مشاكل السيارة):',
                    style: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColors.white),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    complaintText,
                    style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.black),
                  ),
                ),
              ],
            ),
          ),

          pw.Divider(color: _darkBorder, thickness: 0.8, height: 1),

          // Section 2: تقرير الفحص والتشخيص الفني ("فحص")
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey800,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Text(
                    'تقرير الفحص والتشخيص الفني:',
                    style: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColors.white),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: hasManualNotes
                      ? pw.Text(
                          manualNotes,
                          style: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColors.black),
                        )
                      : pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: <pw.Widget>[
                            pw.Text(
                              '......................................................................................................................................................................................................',
                              style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey500),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              '......................................................................................................................................................................................................',
                              style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey500),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          pw.Divider(color: PdfColors.grey300, thickness: 0.6, height: 1),

          // Section 3: نقاط الفحص الفني السريع للسيارة
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                _checkItem('[  ] فحص كمبيوتر (OBD)', bold),
                _checkItem('[  ] دورة التبريد والحرارة', bold),
                _checkItem('[  ] العفشة والمساعدين', bold),
                _checkItem('[  ] منظومة الفرامل', bold),
                _checkItem('[  ] الدائرة الكهربائية والبطارية', bold),
                _checkItem('[  ] الزيوت والفلاتر', bold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hides payment / insurance tags that must not appear on the workshop card.
  static String? printableWorkshopNote(String? raw) {
    final note = raw?.trim() ?? '';
    if (note.isEmpty) {
      return null;
    }
    if (note.contains('نقدي') ||
        note.contains('خاص') ||
        note.contains('تأمين') ||
        note.contains('التامين') ||
        note.contains('التأمين')) {
      return null;
    }
    return note;
  }

  pw.Widget _checkItem(String text, pw.Font font) {
    return pw.Text(
      text,
      style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey800),
    );
  }

  pw.Widget _buildInfoCell(
    String label,
    String value,
    pw.Font regular,
    pw.Font bold, {
    bool isTop = false,
    bool isBottom = false,
  }) {
    return pw.Container(
      height: 20,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: isBottom ? pw.BorderSide.none : pw.BorderSide(color: _darkBorder, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            label,
            style: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColors.black),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColors.black),
          ),
        ],
      ),
    );
  }

  // ── Main Tasks & Parts Table (WITHOUT prices/costs) ─────────────────────
  // Columns order from Right to Left:
  // 0: م (Right)
  // 1: نوع البند
  // 2: البيان / تفاصيل العمل وقطع الغيار المطلوبة (Middle wide)
  // 3: كود القطعة
  // 4: الكمية
  // 5: حالة التنفيذ / ملاحظات الفني (Left)
  pw.Widget _buildEstimateTable(pw.Font regular, pw.Font bold, pw.Font semiBold) {
    const int targetRows = 10;
    final int rowCount = math.max(targetRows, order.lines.length);

    final rows = <pw.TableRow>[
      // Table Header Row
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
          ),
          color: PdfColors.grey200,
        ),
        children: <pw.Widget>[
          _tableCell('م', bold, 9, align: pw.TextAlign.center),
          _tableCell('نوع البند', bold, 9, align: pw.TextAlign.center),
          _tableCell('البيان / تفاصيل العمل وقطع الغيار المطلوبة للتنفيذ', bold, 9, align: pw.TextAlign.center),
          _tableCell('كود القطعة', bold, 9, align: pw.TextAlign.center),
          _tableCell('الكمية', bold, 9, align: pw.TextAlign.center),
          _tableCell('حالة التنفيذ وملاحظات الفني', bold, 9, align: pw.TextAlign.center),
        ],
      ),
    ];

    for (int i = 0; i < rowCount; i++) {
      if (i < order.lines.length) {
        final line = order.lines[i];
        final typeText = line.isService ? 'مصنعية / صيانة' : 'قطعة غيار';
        final codeText = line.isService ? '—' : (line.itemId != null ? '#${line.itemId}' : '—');
        rows.add(
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.6),
              ),
            ),
            children: <pw.Widget>[
              _tableCell('${i + 1}', bold, 8.5, align: pw.TextAlign.center),
              _tableCell(typeText, regular, 8, align: pw.TextAlign.center),
              _tableCell(line.description, semiBold, 8.5),
              _tableCell(codeText, regular, 8, align: pw.TextAlign.center),
              _tableCell(line.formattedQuantity, regular, 8.5, align: pw.TextAlign.center),
              _tableCell('[  ] تم الإنجاز', regular, 7.5, align: pw.TextAlign.center, color: PdfColors.grey600),
            ],
          ),
        );
      } else {
        // Blank lined row for technician / employee handwriting
        rows.add(
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            children: <pw.Widget>[
              _tableCell('${i + 1}', regular, 7.5, align: pw.TextAlign.center, color: PdfColors.grey500),
              _tableCell('', regular, 7),
              _tableCell(
                '· · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·',
                regular,
                6.5,
                color: PdfColors.grey300,
              ),
              _tableCell('', regular, 7),
              _tableCell('', regular, 7),
              _tableCell('', regular, 7),
            ],
          ),
        );
      }
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _darkBorder, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Table(
        border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: PdfColors.black, width: 0.8),
        ),
        columnWidths: const <int, pw.TableColumnWidth>{
          0: pw.FixedColumnWidth(30), // م (Right)
          1: pw.FixedColumnWidth(75), // نوع البند
          2: pw.FlexColumnWidth(4), // البيان والتفاصيل
          3: pw.FixedColumnWidth(65), // كود القطعة
          4: pw.FixedColumnWidth(48), // الكمية
          5: pw.FixedColumnWidth(110), // حالة التنفيذ / ملاحظات الفني (Left)
        },
        children: rows,
      ),
    );
  }

  pw.Widget _tableCell(
    String text,
    pw.Font font,
    double size, {
    pw.TextAlign align = pw.TextAlign.start,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Container(
      height: 18.5,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      alignment: align == pw.TextAlign.center
          ? pw.Alignment.center
          : (align == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: size, color: color),
      ),
    );
  }

  // ── Work Order Summary Bar (item counts) ──────────────────────────────────
  pw.Widget _buildSummaryBar(pw.Font regular, pw.Font bold) {
    final servicesCount = order.lines.where((l) => l.isService).length;
    final partsCount = order.lines.where((l) => l.isPart).length;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _darkBorder, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        color: PdfColors.grey100,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: <pw.Widget>[
          pw.Text(
            'إجمالي بنود أمر الشغل: ${order.lines.length} بند  (أعمال ومصنعيات: $servicesCount  •  قطع غيار: $partsCount)',
            style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.black),
          ),
        ],
      ),
    );
  }

  // ── Customer Disclaimer Note in Red ───────────────────────────────────────
  pw.Widget _buildCustomerDisclaimer(pw.Font bold) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Text(
        garageProfile?.customDisclaimer?.isNotEmpty == true ? garageProfile!.customDisclaimer! : 'عزيزي العميل : تم استلام السيارة لإجراء الفحص الفني والتشخيص ومباشرة أعمال الصيانة المحددة أعلاه. سيتم إخطاركم وموافقتكم على أي قطع أو أعمال إضافية تظهر أثناء الفحص والعمل. الأسعار وتكلفة الصيانة تُحدد رسمياً بفاتورة الصيانة عند التسليم.',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: bold,
          fontSize: 8.5,
          color: _primaryRed,
        ),
      ),
    );
  }

  // ── Returns Section ────────────────────────────────────────────────────────────
  pw.Widget _buildReturnsSection(pw.Font regular, pw.Font bold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _darkBorder, width: 1.0),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
              border: pw.Border(bottom: pw.BorderSide(color: _darkBorder, width: 0.8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Text('قسم مرتجعات وقطع الغيار القديمة المستبدلة', style: pw.TextStyle(font: bold, fontSize: 8.5, color: _primaryRed)),
                pw.Text('[  ] تم تسليم القطع القديمة للعميل    [  ] لا توجد مرتجعات    [  ] تم التكهين بالمركز بموافقة العميل', style: pw.TextStyle(font: regular, fontSize: 7.5, color: PdfColors.grey800)),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: pw.Row(
              children: <pw.Widget>[
                pw.Expanded(
                  child: pw.Text('بيان المرتجعات: ......................................................................................................................................................................................................', style: pw.TextStyle(font: regular, fontSize: 7.5, color: PdfColors.grey600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Signatures ────────────────────────────────────────────────────────────
  // In RTL: children[0] is on RIGHT (موافقة واستلام العميل), children[2] is on LEFT (مدير مركز الصيانة)
  pw.Widget _buildSignatures(pw.Font regular, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          // Right: موافقة واستلام العميل
          _sigColumn('موافقة واستلام العميل', bold),
          // Center: مهندس الفحص والاستقبال
          _sigColumn('مهندس الفحص والاستقبال', bold),
          // Left: مدير مركز الصيانة
          _sigColumn('مدير مركز الصيانة', bold),
        ],
      ),
    );
  }

  pw.Widget _sigColumn(String title, pw.Font bold) {
    return pw.Column(
      children: <pw.Widget>[
        pw.Text(
          title,
          style: pw.TextStyle(font: bold, fontSize: 9.5, color: _primaryRed),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          '...................................',
          style: pw.TextStyle(font: bold, fontSize: 7, color: PdfColors.grey500),
        ),
      ],
    );
  }

  // ── Bottom Contacts ───────────────────────────────────────────────────────
  pw.Widget _buildBottomContacts(pw.Font bold) {
    final phone = (garageProfile?.phone.isNotEmpty == true)
        ? garageProfile!.phone
        : '01004497144 - 01067704194';

    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
      child: pw.Text(
        'تليفون : $phone',
        style: pw.TextStyle(
          font: bold,
          fontSize: 11,
          color: PdfColors.black,
        ),
      ),
    );
  }
}
