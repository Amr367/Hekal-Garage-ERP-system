import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/printing/car_brand_logos.dart';
import '../../../core/printing/font_loader.dart';
import '../../../core/printing/money_format.dart';
import '../../../core/printing/tafqeet.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/settings/domain/garage_profile.dart';
import 'invoice_with_details.dart';

/// Builder for generating A4 and 80mm thermal receipt PDFs for real invoices.
///
/// Designed to share the identical visual identity, layout structure,
/// vehicle details, customer complaint, and business logic with the
/// physical workshop Job Card of "مركز هيكل لإصلاح السيارات".
class InvoicePrintBuilder {
  const InvoicePrintBuilder._();

  static final PdfColor _primaryRed = PdfColor.fromHex('#B71C1C');
  static final PdfColor _darkBorder = PdfColor.fromHex('#1A1A1A');

  /// Builds a complete Arabic A4 Invoice PDF mirroring the workshop Job Card structure.
  static pw.Document buildA4(InvoiceWithDetails invoice, GarageProfile profile) {
    final doc = pw.Document(theme: PdfFontLoader.arabicTheme);

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
            _buildA4Header(invoice, profile, regular, bold, semiBold),
            pw.SizedBox(height: 6),

            // ── Customer & Vehicle Information Box ──────────────────────
            _buildA4InfoBox(invoice, regular, bold, semiBold),
            pw.SizedBox(height: 5),

            // ── Customer Complaint & Work Done Box ──────────────────────
            _buildA4ComplaintBox(invoice, regular, bold, semiBold),
            pw.SizedBox(height: 5),

            // ── Main Invoice Items Table ────────────────────────────────
            _buildA4Table(invoice, regular, bold, semiBold),
            pw.SizedBox(height: 5),

            // ── Financial Summary & Tafqeet ─────────────────────────────
            _buildA4TotalsAndTafqeet(invoice, regular, bold, semiBold),
            pw.SizedBox(height: 6),

            // ── Customer Warranty & Disclaimer Note ─────────────────────
            _buildA4Disclaimer(bold),
            pw.SizedBox(height: 8),

            // ── Signatures Box ───────────────────────────────────────────
            _buildA4Signatures(regular, bold),
            pw.Spacer(),

            // ── Bottom Contact Phone Numbers ─────────────────────────────
            _buildA4BottomContacts(profile, bold),
          ],
        ),
      ),
    );

    return doc;
  }

  /// Builds an 80mm thermal receipt PDF for POS printers with complete vehicle and complaint details.
  static pw.Document buildThermalReceipt(InvoiceWithDetails invoice, GarageProfile profile) {
    final doc = pw.Document(theme: PdfFontLoader.arabicTheme);

    final regular = PdfFontLoader.regular;
    final bold = PdfFontLoader.bold;
    final semiBold = PdfFontLoader.semiBold;

    const receiptFormat = PdfPageFormat(
      72 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: receiptFormat,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: <pw.Widget>[
            // Garage Name & Subtitle
            pw.Center(
              child: pw.Text(
                profile.name.isNotEmpty ? profile.name : 'مركز هيكل',
                style: pw.TextStyle(font: bold, fontSize: 13, color: _primaryRed),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Center(
              child: pw.Text(
                profile.subtitle.isNotEmpty ? profile.subtitle : 'لاصلاح السيارات',
                style: pw.TextStyle(font: bold, fontSize: 8.5),
                textAlign: pw.TextAlign.center,
              ),
            ),
            if (profile.phone.isNotEmpty) ...[
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  'هاتف: ${profile.phone}',
                  style: pw.TextStyle(font: regular, fontSize: 8),
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
            ],
            pw.SizedBox(height: 3),
            CarBrandLogos.banner(bold: bold, height: 18, width: 32),
            pw.SizedBox(height: 4),
            _dashedLine(),
            pw.SizedBox(height: 4),

            // Invoice number & date
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('فاتورة: #${invoice.invoiceNumber}', style: pw.TextStyle(font: bold, fontSize: 9.5, color: _primaryRed)),
                pw.Text(invoice.formattedDate, style: pw.TextStyle(font: regular, fontSize: 8)),
              ],
            ),
            if (invoice.workOrder != null) ...[
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('أمر شغل: #${invoice.workOrder!.orderNumber}', style: pw.TextStyle(font: semiBold, fontSize: 8)),
                  pw.Text('الحالة: ${invoice.statusLabel}', style: pw.TextStyle(font: semiBold, fontSize: 8)),
                ],
              ),
            ],
            pw.SizedBox(height: 3),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('العميل: ${invoice.customerName}', style: pw.TextStyle(font: semiBold, fontSize: 8)),
                pw.Text('الهاتف: ${invoice.customerPhone}', style: pw.TextStyle(font: regular, fontSize: 8)),
              ],
            ),
            if (invoice.vehicle != null) ...[
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('المركبة: ${invoice.vehicleTitle}', style: pw.TextStyle(font: semiBold, fontSize: 8)),
                  if (invoice.workOrder?.odometer != null)
                    pw.Text('العداد: ${invoice.workOrder!.odometer} كم', style: pw.TextStyle(font: regular, fontSize: 8)),
                ],
              ),
            ],
            if (invoice.workOrder?.complaint?.trim().isNotEmpty == true) ...[
              pw.SizedBox(height: 3),
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Text(
                  'الشكوى: ${invoice.workOrder!.complaint!.trim()}',
                  style: pw.TextStyle(font: regular, fontSize: 7.5),
                ),
              ),
            ],
            pw.SizedBox(height: 4),
            _dashedLine(),
            pw.SizedBox(height: 4),

            // Compact Line Items
            ...invoice.lines.map((line) {
              final typeBadge = line.isService ? '[مصنعية]' : '[قطع غيار]';
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                        '$typeBadge ${line.description}',
                        style: pw.TextStyle(font: regular, fontSize: 7.5),
                      ),
                    ),
                    pw.Text(
                      '${line.formattedQuantity} × ',
                      style: pw.TextStyle(font: regular, fontSize: 7.5),
                    ),
                    pw.SizedBox(
                      width: 48,
                      child: pw.Text(
                        MoneyFormat.format(line.totalPricePiasters),
                        style: pw.TextStyle(font: semiBold, fontSize: 7.5),
                        textAlign: pw.TextAlign.left,
                      ),
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 4),
            _dashedLine(),
            pw.SizedBox(height: 4),

            // Financial Summary
            _receiptAmountRow('الإجمالي:', MoneyFormat.format(invoice.subtotalPiasters), regular, semiBold),
            if (invoice.discountPiasters > 0)
              _receiptAmountRow('الخصم:', '- ${MoneyFormat.format(invoice.discountPiasters)}', regular, semiBold),
            _receiptAmountRow('الصافي المستحق:', '${MoneyFormat.format(invoice.totalPiasters)} ج.م', bold, bold, fontSize: 10),
            _receiptAmountRow('المدفوع:', MoneyFormat.format(invoice.paidPiasters), regular, semiBold),
            if (invoice.remainingPiasters > 0)
              _receiptAmountRow('المتبقي (آجل):', MoneyFormat.format(invoice.remainingPiasters), bold, bold),

            pw.SizedBox(height: 3),
            pw.Text(
              'فقط: ${Tafqeet.formatPiasters(invoice.totalPiasters)} لا غير',
              style: pw.TextStyle(font: regular, fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),

            pw.SizedBox(height: 4),
            _dashedLine(),
            pw.SizedBox(height: 5),

            // Payment method & footer note
            pw.Center(
              child: pw.Text(
                'طريقة الدفع: ${invoice.paymentMethodLabel}',
                style: pw.TextStyle(font: semiBold, fontSize: 8),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'يرجى الاحتفاظ بالإيصال للاستفادة من الضمان',
                style: pw.TextStyle(font: regular, fontSize: 7),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
      ),
    );

    return doc;
  }

  // ── A4 Helpers ─────────────────────────────────────────────────────────────

  static pw.Widget _buildA4Header(
    InvoiceWithDetails invoice,
    GarageProfile profile,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    final garageName = profile.name.isNotEmpty ? profile.name : 'مركز هيكل';
    final garageSubtitle = profile.subtitle.isNotEmpty ? profile.subtitle : 'لاصلاح السيارات';
    final serialText = invoice.invoiceNumber.toString().padLeft(3, '0');

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
                style: pw.TextStyle(font: bold, fontSize: 22, color: _primaryRed),
              ),
              pw.Text(
                garageSubtitle,
                style: pw.TextStyle(font: bold, fontSize: 13, color: _primaryRed),
              ),
            ],
          ),
        ),

        // Center: Row of Car Logos + Centered Title "فاتورة مبيعات وضمان إصلاح"
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: <pw.Widget>[
              CarBrandLogos.banner(bold: bold),
              pw.SizedBox(height: 4),
              pw.Text(
                invoice.isCancelled ? 'فاتورة ملغاة' : 'فاتورة مبيعات وضمان إصلاح',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 18,
                  color: invoice.isCancelled ? PdfColors.grey700 : _primaryRed,
                ),
              ),
            ],
          ),
        ),

        // Left: Serial Number (e.g. 055) + Invoice Number
        pw.Container(
          width: 100,
          alignment: pw.Alignment.centerLeft,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                serialText,
                style: pw.TextStyle(font: bold, fontSize: 26, color: _primaryRed),
              ),
              pw.Text(
                'فاتورة رقم: #${invoice.invoiceNumber}',
                style: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColors.grey800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Customer & Vehicle Information Box ────────────────────────────────────
  static pw.Widget _buildA4InfoBox(
    InvoiceWithDetails invoice,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    final customerPhone = invoice.customerPhone.isNotEmpty ? invoice.customerPhone : '—';
    final mechanic = invoice.workOrder?.mechanicName?.trim().isNotEmpty == true
        ? invoice.workOrder!.mechanicName!
        : (invoice.workOrder != null ? 'مهندس الصيانة المعاين' : 'مبيعات مباشرة');
    final dateStr = invoice.formattedDate;
    final odometerStr = invoice.workOrder?.odometer != null
        ? '${invoice.workOrder!.odometer} كم'
        : (invoice.vehicle?.lastOdometer != null ? '${invoice.vehicle!.lastOdometer} كم' : '—');

    final customerName = invoice.customerName;
    final plate = invoice.vehicle != null ? Formatters.normalizePlateNumber(invoice.vehicle!.plateNumber) : '—';
    final colorStr = invoice.vehicle?.color?.trim().isNotEmpty == true ? ' (${invoice.vehicle!.color})' : '';
    final modelStr = invoice.vehicle != null
        ? '${invoice.vehicle!.make ?? ''} ${invoice.vehicle!.model ?? ''} ${invoice.vehicle!.year ?? ''}$colorStr'.trim()
        : '—';
    final chassisStr = invoice.vehicle?.chassisNumber?.trim().isNotEmpty == true ? invoice.vehicle!.chassisNumber! : '—';

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
                _buildInfoCell('رقم اللوحة المعدنية', plate, regular, bold),
                _buildInfoCell('الموديل واللون', modelStr.isEmpty ? '—' : modelStr, regular, bold),
                _buildInfoCell('رقم الشاسية', chassisStr, regular, bold, isBottom: true),
              ],
            ),
          ),

          // Vertical dividing line
          pw.Container(
            width: 1.2,
            height: 4 * 20.0,
            color: _darkBorder,
          ),

          // Left Column in RTL (children[2] renders on the LEFT)
          pw.Expanded(
            child: pw.Column(
              children: <pw.Widget>[
                _buildInfoCell('تليفون العميل', customerPhone, regular, bold, isTop: true),
                _buildInfoCell('المهندس المشرف والمعاين', mechanic, regular, bold),
                _buildInfoCell('تاريخ الإصدار', dateStr, regular, bold),
                _buildInfoCell('قراءة عداد الكيلومتر', odometerStr, regular, bold, isBottom: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoCell(
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
          pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColors.black)),
          pw.Text(value, style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColors.black)),
        ],
      ),
    );
  }

  // ── Customer Complaint & Work Done Box ────────────────────────────────────
  static pw.Widget _buildA4ComplaintBox(
    InvoiceWithDetails invoice,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    final complaintText = invoice.workOrder?.complaint?.trim().isNotEmpty == true
        ? invoice.workOrder!.complaint!.trim()
        : 'فحص وصيانة عامة وتوريد قطع غيار';

    final workshopNote = _printableWorkshopNote(invoice.workOrder?.notes);
    final hasNotes = invoice.invoice.notes?.trim().isNotEmpty == true ||
        workshopNote != null;

    final notesText = invoice.invoice.notes?.trim().isNotEmpty == true
        ? invoice.invoice.notes!.trim()
        : (workshopNote ?? '');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _darkBorder, width: 1.1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: pw.BoxDecoration(
                  color: _primaryRed,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Text(
                  'شكوى العميل والأعمال المنفذة:',
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
          if (hasNotes && notesText.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text('ملاحظات الفاتورة والضمان: ', style: pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.grey800)),
                pw.Expanded(
                  child: pw.Text(notesText, style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey900)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Main Invoice Table ────────────────────────────────────────────────────
  static pw.Widget _buildA4Table(
    InvoiceWithDetails invoice,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    const int minRows = 8;
    final int rowCount = invoice.lines.length < minRows ? minRows : invoice.lines.length;

    final rows = <pw.TableRow>[
      // Table Header Row
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
          ),
        ),
        children: <pw.Widget>[
          _tableCell('الجملة', bold, 9, align: pw.TextAlign.center),
          _tableCell('الفئة', bold, 9, align: pw.TextAlign.center),
          _tableCell('اسم القطعة والبيان / الخدمة', bold, 9, align: pw.TextAlign.center),
          _tableCell('النوع', bold, 9, align: pw.TextAlign.center),
          _tableCell('الكمية', bold, 9, align: pw.TextAlign.center),
        ],
      ),
    ];

    for (int i = 0; i < rowCount; i++) {
      if (i < invoice.lines.length) {
        final line = invoice.lines[i];
        final typeText = line.isService ? 'مصنعية/خدمة' : 'قطع غيار مخزن';
        rows.add(
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.6),
              ),
            ),
            children: <pw.Widget>[
              _tableCell(MoneyFormat.format(line.totalPricePiasters), bold, 8.5, align: pw.TextAlign.center),
              _tableCell(MoneyFormat.format(line.unitPricePiasters), regular, 8.5, align: pw.TextAlign.center),
              _tableCell(line.description, semiBold, 8.5),
              _tableCell(typeText, regular, 8, align: pw.TextAlign.center),
              _tableCell(line.formattedQuantity, regular, 8.5, align: pw.TextAlign.center),
            ],
          ),
        );
      } else {
        // Blank row for clean invoice balance
        rows.add(
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            children: <pw.Widget>[
              _tableCell('', regular, 7),
              _tableCell('', regular, 7),
              _tableCell('· · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·', regular, 6.5, color: PdfColors.grey300),
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
          0: pw.FixedColumnWidth(75), // الجملة (Right)
          1: pw.FixedColumnWidth(65), // الفئة
          2: pw.FlexColumnWidth(4), // اسم القطعة والبيان (Middle wide)
          3: pw.FixedColumnWidth(85), // النوع
          4: pw.FixedColumnWidth(48), // الكمية (Left)
        },
        children: rows,
      ),
    );
  }

  static pw.Widget _tableCell(
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

  // ── Financial Summary & Tafqeet ───────────────────────────────────────────
  static pw.Widget _buildA4TotalsAndTafqeet(
    InvoiceWithDetails invoice,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Tafqeet in words line (matching Job Card)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: pw.Row(
            children: <pw.Widget>[
              pw.Text(
                'فقط مبلغ وقدره : ',
                style: pw.TextStyle(font: bold, fontSize: 9.5, color: _primaryRed),
              ),
              pw.Expanded(
                child: pw.Text(
                  '${Tafqeet.formatPiasters(invoice.totalPiasters)} لا غير',
                  style: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColors.grey900),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 3),

        // Financial Breakdown Box
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _darkBorder, width: 1.1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            color: PdfColors.grey50,
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem('المجموع الفرعي', invoice.formattedSubtotal, regular, bold),
              if (invoice.discountPiasters > 0)
                _summaryItem('الخصم', '- ${invoice.formattedDiscount}', regular, bold, color: _primaryRed),
              _summaryItem('الصافي المستحق', invoice.formattedTotal, bold, bold, color: _primaryRed, fontSize: 10),
              _summaryItem('المدفوع', invoice.formattedPaid, regular, bold, color: PdfColors.green800),
              _summaryItem(
                'المتبقي',
                invoice.formattedRemaining,
                bold,
                bold,
                color: invoice.remainingPiasters > 0 ? _primaryRed : PdfColors.green800,
              ),
              _summaryItem('طريقة السداد', invoice.paymentMethodLabel, regular, bold),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryItem(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valFont, {
    PdfColor color = PdfColors.black,
    double fontSize = 8.5,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(label, style: pw.TextStyle(font: labelFont, fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(font: valFont, fontSize: fontSize, color: color)),
      ],
    );
  }

  // ── Customer Warranty & Disclaimer Note ───────────────────────────────────
  static pw.Widget _buildA4Disclaimer(pw.Font bold) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: pw.Text(
        'عزيزي العميل : نشكرك على ثقتك في مركز هيكل لإصلاح السيارات. يرجى الاحتفاظ بهذه الفاتورة للاستفادة من فترة الضمان المقررة على قطع الغيار والمصنعيات المنفذة.',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: bold, fontSize: 9, color: _primaryRed),
      ),
    );
  }

  // ── Signatures Box ────────────────────────────────────────────────────────
  static pw.Widget _buildA4Signatures(pw.Font regular, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          // Right: استلام العميل
          _sigColumn('توقيع واستلام العميل', bold),
          // Center: مهندس الصيانة المشرف
          _sigColumn('مهندس الصيانة المشرف', bold),
          // Left: مسؤول الخزينة والإدارة
          _sigColumn('مسؤول الخزينة والإدارة', bold),
        ],
      ),
    );
  }

  static pw.Widget _sigColumn(String title, pw.Font bold) {
    return pw.Column(
      children: <pw.Widget>[
        pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 9.5, color: _primaryRed)),
        pw.SizedBox(height: 14),
        pw.Text('...................................', style: pw.TextStyle(font: bold, fontSize: 7, color: PdfColors.grey500)),
      ],
    );
  }

  // ── Bottom Contact Phone Numbers ──────────────────────────────────────────
  static pw.Widget _buildA4BottomContacts(GarageProfile profile, pw.Font bold) {
    final phone = profile.phone.isNotEmpty ? profile.phone : '01004497144 - 01067704194';

    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
      child: pw.Text(
        'تليفون : $phone',
        style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.black),
      ),
    );
  }

  static String? _printableWorkshopNote(String? raw) {
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

  // ── Thermal Helpers ────────────────────────────────────────────────────────

  static pw.Widget _dashedLine() {
    return pw.Text(
      '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
      textAlign: pw.TextAlign.center,
    );
  }

  static pw.Widget _receiptAmountRow(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valueFont, {
    double fontSize = 8,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: labelFont, fontSize: fontSize)),
          pw.Text(value, style: pw.TextStyle(font: valueFont, fontSize: fontSize)),
        ],
      ),
    );
  }
}
