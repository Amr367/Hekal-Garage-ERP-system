import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/printing/car_brand_logos.dart';
import '../../../../core/printing/font_loader.dart';
import '../../../../core/printing/money_format.dart';
import '../../../../core/printing/tafqeet.dart';
import '../../../settings/domain/garage_profile.dart';
import '../../domain/return_with_details.dart';

/// Builder for generating professional Arabic A4 and 80mm thermal return receipts/vouchers.
class ReturnReceiptBuilder {
  const ReturnReceiptBuilder._();

  static final PdfColor _primaryAmber = PdfColor.fromHex('#C25E00');
  static final PdfColor _primaryBlue = PdfColor.fromHex('#1565C0');
  static final PdfColor _darkBorder = PdfColor.fromHex('#2D3748');

  /// Builds a complete Arabic A4 Return Voucher document.
  static pw.Document buildA4(ReturnWithDetails returnData, GarageProfile profile) {
    final doc = pw.Document(theme: PdfFontLoader.arabicTheme);

    final regular = PdfFontLoader.regular;
    final bold = PdfFontLoader.bold;
    final semiBold = PdfFontLoader.semiBold;

    final isSale = returnData.isSaleReturn;
    final themeColor = isSale ? _primaryAmber : _primaryBlue;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            // ── Top Header ───────────────────────────────────────────────
            _buildA4Header(returnData, profile, themeColor, regular, bold, semiBold),
            pw.SizedBox(height: 10),

            // ── Return Parties & Document Info Box ───────────────────────
            _buildA4InfoBox(returnData, themeColor, regular, bold, semiBold),
            pw.SizedBox(height: 10),

            // ── Reason for Return Box (if specified) ──────────────────────
            if (returnData.entry.reason != null && returnData.entry.reason!.trim().isNotEmpty) ...[
              _buildReasonBox(returnData.entry.reason!.trim(), regular, semiBold),
              pw.SizedBox(height: 10),
            ],

            // ── Returned Items Table ─────────────────────────────────────
            _buildA4ItemsTable(returnData, themeColor, regular, bold, semiBold),
            pw.SizedBox(height: 10),

            // ── Financial Summary & Tafqeet Box ──────────────────────────
            _buildA4TotalsBox(returnData, themeColor, regular, bold, semiBold),
            pw.SizedBox(height: 16),

            // ── Signatures Box ───────────────────────────────────────────
            _buildA4Signatures(isSale, regular, bold),
            pw.Spacer(),

            // ── Footer ───────────────────────────────────────────────────
            _buildA4Footer(profile, regular, bold),
          ],
        ),
      ),
    );

    return doc;
  }

  /// Builds an 80mm thermal receipt PDF for POS printers.
  static pw.Document buildThermalReceipt(ReturnWithDetails returnData, GarageProfile profile) {
    final doc = pw.Document(theme: PdfFontLoader.arabicTheme);

    final regular = PdfFontLoader.regular;
    final bold = PdfFontLoader.bold;
    final semiBold = PdfFontLoader.semiBold;

    final isSale = returnData.isSaleReturn;
    final themeColor = isSale ? _primaryAmber : _primaryBlue;

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
                style: pw.TextStyle(font: bold, fontSize: 13, color: themeColor),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Center(
              child: pw.Text(
                profile.subtitle.isNotEmpty ? profile.subtitle : 'لاصلاح السيارات والمخازن',
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

            // Return Title & Badge
            pw.Center(
              child: pw.Text(
                isSale ? 'إذن مرتجع مبيعات' : 'إذن مرتجع مشتريات',
                style: pw.TextStyle(font: bold, fontSize: 11, color: themeColor),
              ),
            ),
            pw.SizedBox(height: 2),

            // Number & Date
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('مرتجع: ${returnData.returnNumberFormatted}',
                    style: pw.TextStyle(font: bold, fontSize: 9, color: themeColor)),
                pw.Text(returnData.formattedDate, style: pw.TextStyle(font: regular, fontSize: 8)),
              ],
            ),
            pw.SizedBox(height: 3),

            // Party Name
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(isSale ? 'العميل:' : 'المورد:',
                    style: pw.TextStyle(font: semiBold, fontSize: 8)),
                pw.Text(returnData.partyName, style: pw.TextStyle(font: bold, fontSize: 8)),
              ],
            ),
            if (returnData.referenceLabel != null) ...[
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('المرجع:', style: pw.TextStyle(font: regular, fontSize: 8)),
                  pw.Text(returnData.referenceLabel!, style: pw.TextStyle(font: regular, fontSize: 8)),
                ],
              ),
            ],
            pw.SizedBox(height: 4),
            _dashedLine(),
            pw.SizedBox(height: 4),

            // Lines
            ...returnData.lines.map((line) {
              final qtyStr = line.quantity % 1 == 0 ? line.quantity.toInt().toString() : line.quantity.toString();
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                        line.description,
                        style: pw.TextStyle(font: regular, fontSize: 7.5),
                      ),
                    ),
                    pw.Text(
                      '$qtyStr × ',
                      style: pw.TextStyle(font: regular, fontSize: 7.5),
                    ),
                    pw.SizedBox(
                      width: 50,
                      child: pw.Text(
                        MoneyFormat.format(line.totalPrice),
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

            // Total
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('المبلغ المسترد:', style: pw.TextStyle(font: bold, fontSize: 10)),
                pw.Text(
                  '${MoneyFormat.format(returnData.totalAmount)} ج.م',
                  style: pw.TextStyle(font: bold, fontSize: 10, color: themeColor),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'فقط: ${Tafqeet.formatPiasters(returnData.totalAmount)} لا غير',
              style: pw.TextStyle(font: regular, fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            _dashedLine(),
            pw.SizedBox(height: 4),

            // Settlement Method & Reason
            pw.Center(
              child: pw.Text(
                'طريقة التسوية: ${returnData.refundMethodLabel}',
                style: pw.TextStyle(font: semiBold, fontSize: 8),
              ),
            ),
            if (returnData.entry.reason != null && returnData.entry.reason!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'السبب: ${returnData.entry.reason!.trim()}',
                  style: pw.TextStyle(font: regular, fontSize: 7.5),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                'تم تحديث حركة المخزن تلقائياً',
                style: pw.TextStyle(font: regular, fontSize: 7),
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
      ),
    );

    return doc;
  }

  // ── A4 Layout Helpers ──────────────────────────────────────────────────────

  static pw.Widget _buildA4Header(
    ReturnWithDetails returnData,
    GarageProfile profile,
    PdfColor themeColor,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    final garageName = profile.name.isNotEmpty ? profile.name : 'مركز هيكل';
    final garageSubtitle = profile.subtitle.isNotEmpty ? profile.subtitle : 'لاصلاح السيارات';
    final isSale = returnData.isSaleReturn;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        // Right: Garage Name
        pw.Container(
          width: 140,
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: <pw.Widget>[
              pw.Text(
                garageName,
                style: pw.TextStyle(font: bold, fontSize: 22, color: themeColor),
              ),
              pw.Text(
                garageSubtitle,
                style: pw.TextStyle(font: bold, fontSize: 13, color: themeColor),
              ),
            ],
          ),
        ),

        // Center: Logos + Title
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: <pw.Widget>[
              CarBrandLogos.banner(bold: bold),
              pw.SizedBox(height: 4),
              pw.Text(
                isSale ? 'إذن مرتجع مبيعات واسترداد بضاعة' : 'إذن مرتجع مشتريات إلى مورد',
                style: pw.TextStyle(font: bold, fontSize: 18, color: themeColor),
              ),
            ],
          ),
        ),

        // Left: Return Number & Date
        pw.Container(
          width: 120,
          alignment: pw.Alignment.centerLeft,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                returnData.returnNumberFormatted,
                style: pw.TextStyle(font: bold, fontSize: 24, color: themeColor),
              ),
              pw.Text(
                'التاريخ: ${returnData.formattedDate}',
                style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColors.grey800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildA4InfoBox(
    ReturnWithDetails returnData,
    PdfColor themeColor,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    final isSale = returnData.isSaleReturn;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _darkBorder, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${isSale ? "العميل المسترد:" : "المورد المستلم:"} ${returnData.partyName}',
                  style: pw.TextStyle(font: bold, fontSize: 10),
                ),
                if (isSale && returnData.customer?.phone != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'رقم الهاتف: ${returnData.customer!.phone}',
                    style: pw.TextStyle(font: regular, fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'طريقة التسوية: ${returnData.refundMethodLabel}',
                  style: pw.TextStyle(font: semiBold, fontSize: 9.5),
                ),
                if (returnData.referenceLabel != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'الفاتورة المرجعية: ${returnData.referenceLabel!}',
                    style: pw.TextStyle(font: regular, fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'حالة المخزون:',
                  style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColors.grey700),
                ),
                pw.Text(
                  isSale ? 'تم إيداع البضاعة بالمخزن' : 'تم خصم البضاعة من المخزن',
                  style: pw.TextStyle(font: bold, fontSize: 9, color: themeColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReasonBox(
    String reason,
    pw.Font regular,
    pw.Font semiBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('سبب الإرجاع: ', style: pw.TextStyle(font: semiBold, fontSize: 9)),
          pw.Expanded(
            child: pw.Text(reason, style: pw.TextStyle(font: regular, fontSize: 9)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildA4ItemsTable(
    ReturnWithDetails returnData,
    PdfColor themeColor,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: _darkBorder, width: 0.8),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(5),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(2),
        4: pw.FlexColumnWidth(2.5),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: themeColor),
          children: [
            _cell('م', bold, textColor: PdfColors.white, isHeader: true),
            _cell('بيان الصنف / البند المرتجع', bold, textColor: PdfColors.white, isHeader: true),
            _cell('الكمية', bold, textColor: PdfColors.white, isHeader: true),
            _cell('سعر الوحدة', bold, textColor: PdfColors.white, isHeader: true),
            _cell('الإجمالي المسترد', bold, textColor: PdfColors.white, isHeader: true),
          ],
        ),
        // Rows
        ...returnData.lines.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final line = entry.value;
          final isEven = index % 2 == 0;
          final bg = isEven ? PdfColors.grey100 : PdfColors.white;
          final qtyStr = line.quantity % 1 == 0
              ? line.quantity.toInt().toString()
              : line.quantity.toString();

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _cell(index.toString(), regular, align: pw.TextAlign.center),
              _cell(line.description, semiBold),
              _cell(qtyStr, regular, align: pw.TextAlign.center),
              _cell(MoneyFormat.format(line.unitPrice), regular, align: pw.TextAlign.center),
              _cell('${MoneyFormat.format(line.totalPrice)} ج.م', bold, align: pw.TextAlign.left),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildA4TotalsBox(
    ReturnWithDetails returnData,
    PdfColor themeColor,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _darkBorder, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              'المبلغ كتابة: فقط ${Tafqeet.formatPiasters(returnData.totalAmount)} لا غير',
              style: pw.TextStyle(font: regular, fontSize: 9.5),
            ),
          ),
          pw.Row(
            children: [
              pw.Text('صافي قيمة المرتجع: ', style: pw.TextStyle(font: bold, fontSize: 11)),
              pw.Text(
                '${MoneyFormat.format(returnData.totalAmount)} ج.م',
                style: pw.TextStyle(font: bold, fontSize: 13, color: themeColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildA4Signatures(
    bool isSale,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        pw.Column(
          children: [
            pw.Text(
              isSale ? 'توقيع العميل المسترد' : 'توقيع مندوب المورد المستلم',
              style: pw.TextStyle(font: bold, fontSize: 9.5),
            ),
            pw.SizedBox(height: 28),
            pw.Text('...................................', style: pw.TextStyle(font: regular, fontSize: 9)),
          ],
        ),
        pw.Column(
          children: [
            pw.Text(
              'توقيع أمين المخزن المستلم',
              style: pw.TextStyle(font: bold, fontSize: 9.5),
            ),
            pw.SizedBox(height: 28),
            pw.Text('...................................', style: pw.TextStyle(font: regular, fontSize: 9)),
          ],
        ),
        pw.Column(
          children: [
            pw.Text(
              'اعتماد الحسابات / الإدارة',
              style: pw.TextStyle(font: bold, fontSize: 9.5),
            ),
            pw.SizedBox(height: 28),
            pw.Text('...................................', style: pw.TextStyle(font: regular, fontSize: 9)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildA4Footer(
    GarageProfile profile,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            profile.address.isNotEmpty ? profile.address : 'جمهورية مصر العربية',
            style: pw.TextStyle(font: regular, fontSize: 8),
          ),
          pw.Text(
            'نظام مركز هيكل لإصلاح السيارات - إذن مرتجع رسمي',
            style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey700),
          ),
          if (profile.phone.isNotEmpty)
            pw.Text(
              'خدمة العملاء: ${profile.phone}',
              style: pw.TextStyle(font: bold, fontSize: 8),
            ),
        ],
      ),
    );
  }

  static pw.Widget _cell(
    String text,
    pw.Font font, {
    PdfColor textColor = PdfColors.black,
    pw.TextAlign align = pw.TextAlign.right,
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 8.5 : 8,
          color: textColor,
        ),
      ),
    );
  }

  static pw.Widget _dashedLine() {
    return pw.Text(
      '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
      style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
      maxLines: 1,
      overflow: pw.TextOverflow.clip,
    );
  }
}
