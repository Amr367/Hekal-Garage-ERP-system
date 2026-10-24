import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'font_loader.dart';
import 'money_format.dart';
import 'sample_data.dart';

/// Builds a sample A4 Arabic invoice PDF for the Phase 1 printing spike.
///
/// The layout mirrors a real Egyptian car-service invoice:
/// header → customer/car info → line-item table → totals → footer.
/// Everything is RTL. The table has 25 rows to force a second page
/// so we can test pagination and page numbers.
class A4InvoiceBuilder {
  A4InvoiceBuilder();

  /// Generates a multi-page A4 PDF document.
  pw.Document build() {
    final pw.Document doc = pw.Document(
      theme: PdfFontLoader.arabicTheme,
    );

    final pw.Font regular = PdfFontLoader.regular;
    final pw.Font bold = PdfFontLoader.bold;
    final pw.Font semiBold = PdfFontLoader.semiBold;

    // Compute actual subtotal from lines.
    int computedSubtotal = 0;
    for (final SampleInvoiceLine line in PrintSampleData.lines) {
      computedSubtotal += line.total;
    }
    final int computedTotal = computedSubtotal - PrintSampleData.discount;
    final int computedRemaining = computedTotal - PrintSampleData.paid;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.symmetric(
          horizontal: 40,
          vertical: 30,
        ),
        header: (pw.Context context) => _buildHeader(regular, bold, semiBold),
        footer: (pw.Context context) => _buildFooter(
          context,
          regular,
          semiBold,
        ),
        build: (pw.Context context) => <pw.Widget>[
          _buildCustomerCarInfo(regular, bold, semiBold),
          pw.SizedBox(height: 12),
          _buildLineItemTable(regular, bold, semiBold),
          pw.SizedBox(height: 12),
          _buildTotals(
            regular,
            bold,
            semiBold,
            computedSubtotal,
            computedTotal,
            computedRemaining,
          ),
          pw.SizedBox(height: 16),
          _buildTortureTests(regular, semiBold),
        ],
      ),
    );

    return doc;
  }

  // ── Header ───────────────────────────────────────────────────────

  pw.Widget _buildHeader(
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: <pw.Widget>[
        pw.Text(
          PrintSampleData.shopName,
          style: pw.TextStyle(font: bold, fontSize: 20),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          PrintSampleData.shopAddress,
          style: pw.TextStyle(font: regular, fontSize: 11),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '${PrintSampleData.shopPhone1}  —  ${PrintSampleData.shopPhone2}',
          style: pw.TextStyle(font: regular, fontSize: 11),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text(
              'فاتورة رقم: ${PrintSampleData.invoiceNumber}',
              style: pw.TextStyle(font: semiBold, fontSize: 13),
              textDirection: pw.TextDirection.rtl,
            ),
            pw.Text(
              'التاريخ: ${PrintSampleData.invoiceDate}',
              style: pw.TextStyle(font: semiBold, fontSize: 13),
              textDirection: pw.TextDirection.rtl,
            ),
          ],
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── Customer and car info ────────────────────────────────────────

  pw.Widget _buildCustomerCarInfo(
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    pw.Widget infoRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          children: <pw.Widget>[
            pw.SizedBox(
              width: 100,
              child: pw.Text(
                label,
                style: pw.TextStyle(font: semiBold, fontSize: 10),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(font: regular, fontSize: 10),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          infoRow('العميل:', PrintSampleData.customerName),
          infoRow('التليفون:', PrintSampleData.customerPhone),
          infoRow('رقم اللوحة:', PrintSampleData.plateNumber),
          infoRow('السيارة:', PrintSampleData.carMakeModel),
          infoRow('العداد:', PrintSampleData.odometer),
        ],
      ),
    );
  }

  // ── Line-item table ──────────────────────────────────────────────

  pw.Widget _buildLineItemTable(
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
  ) {
    // RTL column order: م ← البيان ← الكمية ← السعر ← الإجمالي
    final List<pw.TableRow> rows = <pw.TableRow>[
      // Header row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: <pw.Widget>[
          _cell('م', bold, alignment: pw.Alignment.center, width: 30),
          _cell('البيان', bold, alignment: pw.Alignment.centerRight),
          _cell('الكمية', bold, alignment: pw.Alignment.center, width: 50),
          _cell('السعر', bold, alignment: pw.Alignment.center, width: 80),
          _cell('الإجمالي', bold, alignment: pw.Alignment.center, width: 90),
        ],
      ),
    ];

    for (int i = 0; i < PrintSampleData.lines.length; i++) {
      final SampleInvoiceLine line = PrintSampleData.lines[i];
      final bool shaded = i.isOdd;
      rows.add(
        pw.TableRow(
          decoration: shaded
              ? const pw.BoxDecoration(color: PdfColors.grey50)
              : null,
          children: <pw.Widget>[
            _cell(
              '${i + 1}',
              regular,
              alignment: pw.Alignment.center,
              width: 30,
            ),
            _cellDesc(line.description, regular),
            _cell(
              '${line.quantity}',
              regular,
              alignment: pw.Alignment.center,
              width: 50,
            ),
            _cell(
              MoneyFormat.format(line.unitPrice),
              regular,
              alignment: pw.Alignment.center,
              width: 80,
            ),
            _cell(
              MoneyFormat.format(line.total),
              regular,
              alignment: pw.Alignment.center,
              width: 90,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(80),
        4: const pw.FixedColumnWidth(90),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  pw.Widget _cell(
    String text,
    pw.Font font, {
    pw.Alignment alignment = pw.Alignment.centerRight,
    double? width,
  }) {
    final pw.Widget child = pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9),
        textDirection: pw.TextDirection.rtl,
        textAlign: alignment == pw.Alignment.center
            ? pw.TextAlign.center
            : pw.TextAlign.right,
      ),
    );
    if (width != null) {
      return pw.SizedBox(width: width, child: child);
    }
    return child;
  }

  pw.Widget _cellDesc(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.right,
        maxLines: 3,
        softWrap: true,
      ),
    );
  }

  // ── Totals ───────────────────────────────────────────────────────

  pw.Widget _buildTotals(
    pw.Font regular,
    pw.Font bold,
    pw.Font semiBold,
    int subtotal,
    int total,
    int remaining,
  ) {
    pw.Widget totalRow(String label, int amount, {bool highlight = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: <pw.Widget>[
            pw.SizedBox(
              width: 100,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: highlight ? bold : semiBold,
                  fontSize: highlight ? 12 : 10,
                ),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
            pw.SizedBox(
              width: 110,
              child: pw.Text(
                MoneyFormat.formatWithCurrency(amount),
                style: pw.TextStyle(
                  font: highlight ? bold : regular,
                  fontSize: highlight ? 12 : 10,
                ),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.left,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          children: <pw.Widget>[
            totalRow('المجموع:', subtotal),
            totalRow('الخصم:', PrintSampleData.discount),
            pw.Divider(thickness: 0.5),
            totalRow('الإجمالي:', total, highlight: true),
            totalRow('المدفوع:', PrintSampleData.paid),
            totalRow('المتبقي:', remaining, highlight: true),
          ],
        ),
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────

  pw.Widget _buildFooter(
    pw.Context context,
    pw.Font regular,
    pw.Font semiBold,
  ) {
    return pw.Column(
      children: <pw.Widget>[
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text(
              PrintSampleData.footerTerms,
              style: pw.TextStyle(font: regular, fontSize: 8),
              textDirection: pw.TextDirection.rtl,
            ),
            pw.Text(
              'صفحة ${context.pageNumber} من ${context.pagesCount}',
              style: pw.TextStyle(font: semiBold, fontSize: 8),
              textDirection: pw.TextDirection.rtl,
            ),
          ],
        ),
      ],
    );
  }

  // ── Torture test section ─────────────────────────────────────────

  pw.Widget _buildTortureTests(pw.Font regular, pw.Font semiBold) {
    pw.Widget testRow(String label, String text) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            pw.Text(
              label,
              style: pw.TextStyle(font: semiBold, fontSize: 8),
              textDirection: pw.TextDirection.rtl,
            ),
            pw.Text(
              text,
              style: pw.TextStyle(font: regular, fontSize: 9),
              textDirection: pw.TextDirection.rtl,
            ),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.amber50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Text(
            'اختبار النصوص المختلطة (torture test)',
            style: pw.TextStyle(font: semiBold, fontSize: 10),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.SizedBox(height: 4),
          testRow(
            '1. لام-ألف + تشكيل + أقواس:',
            PrintSampleData.tortureText1,
          ),
          testRow(
            '2. إنجليزي داخل عربي + سلاش:',
            PrintSampleData.tortureText2,
          ),
          testRow(
            '3. أرقام عربية-هندية:',
            PrintSampleData.tortureText3,
          ),
          testRow(
            '4. فواصل آلاف وكسور:',
            PrintSampleData.tortureText4,
          ),
          testRow(
            '5. أقواس وسلاش في RTL:',
            PrintSampleData.tortureText5,
          ),
        ],
      ),
    );
  }
}
