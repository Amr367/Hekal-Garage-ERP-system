import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/printing/car_brand_logos.dart';
import '../../../core/printing/font_loader.dart';
import '../../../core/printing/money_format.dart';
import '../../../core/printing/tafqeet.dart';
import '../../../features/settings/domain/garage_profile.dart';
import 'purchase_invoice_with_details.dart';

/// Builder for generating professional Arabic A4 Purchase Invoices and Inbound Stock Receipts.
///
/// Fully offline vector PDF generation with Cairo font family and RTL directionality.
class PurchasePrintBuilder {
  const PurchasePrintBuilder._();

  static final PdfColor _primaryColor = PdfColor.fromHex('#1F4E5F');
  static final PdfColor _darkBorder = PdfColor.fromHex('#2D3748');

  /// Builds a complete Arabic A4 Purchase Invoice / Inbound Stock Receipt document.
  static pw.Document buildA4(PurchaseInvoiceWithDetails purchase, GarageProfile profile) {
    final doc = pw.Document(theme: PdfFontLoader.arabicTheme);

    final regular = PdfFontLoader.regular;
    final bold = PdfFontLoader.bold;
    final semiBold = PdfFontLoader.semiBold;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            // ── Top Header ───────────────────────────────────────────────
            _buildHeader(purchase, profile, regular, bold, semiBold),
            pw.SizedBox(height: 10),

            // ── Supplier & Document Info Box ─────────────────────────────
            _buildSupplierBox(purchase, regular, bold, semiBold),
            pw.SizedBox(height: 10),

            // ── Notes Box (if any) ───────────────────────────────────────
            if (purchase.notes != null && purchase.notes!.trim().isNotEmpty) ...[
              _buildNotesBox(purchase.notes!.trim(), regular, semiBold),
              pw.SizedBox(height: 10),
            ],

            // ── Items Table ──────────────────────────────────────────────
            _buildItemsTable(purchase, regular, bold, semiBold),
            pw.SizedBox(height: 10),

            // ── Totals & Tafqeet Box ─────────────────────────────────────
            _buildTotalsBox(purchase, regular, bold, semiBold),
            pw.SizedBox(height: 16),

            // ── Signatures ───────────────────────────────────────────────
            _buildSignatures(regular, bold),
            pw.Spacer(),

            // ── Footer ───────────────────────────────────────────────────
            _buildFooter(profile, regular, bold),
          ],
        ),
      ),
    );

    return doc;
  }

  static pw.Widget _buildHeader(
    PurchaseInvoiceWithDetails purchase,
    GarageProfile profile,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    final garageName = profile.name.isNotEmpty ? profile.name : 'مركز هيكل';
    final garageSubtitle = profile.subtitle.isNotEmpty ? profile.subtitle : 'لاصلاح السيارات والمخازن';
    final serialText = purchase.id.toString().padLeft(4, '0');

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        // Right: Garage Branding
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: <pw.Widget>[
              pw.Text(
                garageName,
                style: pw.TextStyle(font: bold, fontSize: 20, color: _primaryColor),
              ),
              pw.Text(
                garageSubtitle,
                style: pw.TextStyle(font: semiBold, fontSize: 11, color: PdfColors.grey700),
              ),
            ],
          ),
        ),

        // Center: Document Title + Logos
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: <pw.Widget>[
              CarBrandLogos.banner(bold: bold),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _primaryColor, width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'إذن توريد / فاتورة شراء',
                  style: pw.TextStyle(font: bold, fontSize: 15, color: _primaryColor),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'حالة السداد: ${purchase.paymentStatusArabic}',
                style: pw.TextStyle(font: semiBold, fontSize: 10, color: PdfColors.grey800),
              ),
            ],
          ),
        ),

        // Left: Serial & Date
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'رقم الإذن: #$serialText',
                style: pw.TextStyle(font: bold, fontSize: 14, color: _primaryColor),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'تاريخ التوريد: ${purchase.formattedDate}',
                style: pw.TextStyle(font: regular, fontSize: 9.5, color: PdfColors.grey800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSupplierBox(
    PurchaseInvoiceWithDetails purchase,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    final supplier = purchase.supplier;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _darkBorder, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          // Right Column: Supplier Info
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Row(
                  children: [
                    pw.Text('المورد / الشركة: ', style: pw.TextStyle(font: bold, fontSize: 10.5)),
                    pw.Text(supplier.name, style: pw.TextStyle(font: semiBold, fontSize: 11, color: _primaryColor)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text('الهاتف: ', style: pw.TextStyle(font: bold, fontSize: 10)),
                    pw.Text(
                      (supplier.phone != null && supplier.phone!.isNotEmpty) ? supplier.phone! : '—',
                      style: pw.TextStyle(font: regular, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Left Column: Invoice References
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Row(
                  children: [
                    pw.Text('فاتورة المورد: ', style: pw.TextStyle(font: bold, fontSize: 10)),
                    pw.Text(
                      (purchase.supplierInvoiceNumber != null && purchase.supplierInvoiceNumber!.isNotEmpty)
                          ? purchase.supplierInvoiceNumber!
                          : '—',
                      style: pw.TextStyle(font: regular, fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text('عدد الأصناف: ', style: pw.TextStyle(font: bold, fontSize: 10)),
                    pw.Text('${purchase.lines.length} صنف', style: pw.TextStyle(font: regular, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNotesBox(String notes, pw.Font regular, pw.Font semiBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ملاحظات: ', style: pw.TextStyle(font: semiBold, fontSize: 9.5)),
          pw.Expanded(
            child: pw.Text(notes, style: pw.TextStyle(font: regular, fontSize: 9.5)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(
    PurchaseInvoiceWithDetails purchase,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: _darkBorder, width: 0.8),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FixedColumnWidth(28), // م
        1: pw.FixedColumnWidth(80), // كود الصنف
        2: pw.FlexColumnWidth(5), // البيان / اسم الصنف
        3: pw.FixedColumnWidth(45), // الوحدة
        4: pw.FixedColumnWidth(48), // الكمية
        5: pw.FixedColumnWidth(70), // سعر التكلفة
        6: pw.FixedColumnWidth(75), // الإجمالي
      },
      children: <pw.TableRow>[
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: <pw.Widget>[
            _cell('م', bold, 9.5, align: pw.TextAlign.center, isHeader: true),
            _cell('كود الصنف', bold, 9.5, align: pw.TextAlign.center, isHeader: true),
            _cell('اسم الصنف والبيان', bold, 9.5, align: pw.TextAlign.right, isHeader: true),
            _cell('الوحدة', bold, 9.5, align: pw.TextAlign.center, isHeader: true),
            _cell('الكمية', bold, 9.5, align: pw.TextAlign.center, isHeader: true),
            _cell('سعر الوحدة', bold, 9.5, align: pw.TextAlign.center, isHeader: true),
            _cell('الإجمالي', bold, 9.5, align: pw.TextAlign.center, isHeader: true),
          ],
        ),

        // Line rows
        ...purchase.lines.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final line = entry.value;

          return pw.TableRow(
            children: <pw.Widget>[
              _cell('$index', regular, 9, align: pw.TextAlign.center),
              _cell(line.itemSku ?? '—', regular, 8.5, align: pw.TextAlign.center),
              _cell(line.itemName, semiBold, 9, align: pw.TextAlign.right),
              _cell(line.itemUnit, regular, 8.5, align: pw.TextAlign.center),
              _cell(line.formattedQuantity, semiBold, 9, align: pw.TextAlign.center),
              _cell(MoneyFormat.format(line.unitCostPiasters), regular, 9, align: pw.TextAlign.center),
              _cell(MoneyFormat.format(line.totalAmountPiasters), bold, 9, align: pw.TextAlign.center),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTotalsBox(
    PurchaseInvoiceWithDetails purchase,
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _darkBorder, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          // Tafqeet on the right
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('المبلغ كتابةً:', style: pw.TextStyle(font: bold, fontSize: 9.5)),
                pw.SizedBox(height: 3),
                pw.Text(
                  'فقط: ${Tafqeet.formatPiasters(purchase.totalAmountPiasters)} لا غير',
                  style: pw.TextStyle(font: semiBold, fontSize: 10.5, color: _primaryColor),
                ),
              ],
            ),
          ),

          // Numerical summary on the left
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              children: [
                _amountRow('إجمالي الفاتورة:', '${MoneyFormat.format(purchase.totalAmountPiasters)} ج.م', bold, bold, isHighlight: true),
                pw.SizedBox(height: 3),
                _amountRow('المبلغ المسدد:', '${MoneyFormat.format(purchase.paidAmountPiasters)} ج.م', regular, semiBold),
                pw.SizedBox(height: 3),
                _amountRow(
                  'المتبقي آجل:',
                  '${MoneyFormat.format(purchase.remainingAmountPiasters)} ج.م',
                  bold,
                  bold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatures(pw.Font regular, pw.Font bold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              children: [
                pw.Text('توقيع أمين المخزن / المستلم', style: pw.TextStyle(font: bold, fontSize: 9.5)),
                pw.SizedBox(height: 24),
                pw.Text('........................................', style: pw.TextStyle(font: regular, fontSize: 8)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              children: [
                pw.Text('توقيع المورد / المندوب المسلّم', style: pw.TextStyle(font: bold, fontSize: 9.5)),
                pw.SizedBox(height: 24),
                pw.Text('........................................', style: pw.TextStyle(font: regular, fontSize: 8)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(GarageProfile profile, pw.Font regular, pw.Font bold) {
    final contactParts = <String>[];
    if (profile.phone.isNotEmpty) contactParts.add('هاتف: ${profile.phone}');
    if (profile.phone2.isNotEmpty) contactParts.add('هاتف 2: ${profile.phone2}');
    if (profile.address.isNotEmpty) contactParts.add('العنوان: ${profile.address}');

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
      ),
      child: pw.Center(
        child: pw.Text(
          contactParts.isNotEmpty ? contactParts.join('  •  ') : 'مركز هيكل',
          style: pw.TextStyle(font: regular, fontSize: 8.5, color: PdfColors.grey700),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  static pw.Widget _cell(
    String text,
    pw.Font font,
    double fontSize, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize,
          color: isHeader ? PdfColors.black : PdfColors.grey900,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _amountRow(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valueFont, {
    bool isHighlight = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: labelFont, fontSize: isHighlight ? 10 : 9),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: valueFont,
            fontSize: isHighlight ? 10.5 : 9,
            color: isHighlight ? _primaryColor : PdfColors.black,
          ),
        ),
      ],
    );
  }
}
