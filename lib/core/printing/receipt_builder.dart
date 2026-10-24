import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'font_loader.dart';
import 'money_format.dart';
import 'sample_data.dart';

/// Builds a sample 80 mm thermal receipt PDF for the Phase 1 printing spike.
///
/// Paper width is 80 mm (~72 mm printable). The receipt uses continuous
/// height (no page breaks), compact lines, centered shop name, and totals.
class ReceiptBuilder {
  ReceiptBuilder();

  /// The printable width of an 80 mm roll (about 72 mm).
  static const double printableWidth = 72.0 * PdfPageFormat.mm;

  /// Full paper width.
  static const double paperWidth = 80.0 * PdfPageFormat.mm;

  /// Generates a single-page receipt PDF with automatic height.
  pw.Document build() {
    final pw.Document doc = pw.Document(
      theme: PdfFontLoader.arabicTheme,
    );

    final pw.Font regular = PdfFontLoader.regular;
    final pw.Font bold = PdfFontLoader.bold;
    final pw.Font semiBold = PdfFontLoader.semiBold;

    // Only use the first 8 lines for a compact receipt.
    final List<SampleInvoiceLine> receiptLines =
        PrintSampleData.lines.take(8).toList();

    int computedSubtotal = 0;
    for (final SampleInvoiceLine line in receiptLines) {
      computedSubtotal += line.total;
    }
    final int computedTotal = computedSubtotal - 1000; // small discount
    final int computedPaid = computedTotal;
    const int computedRemaining = 0;

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          paperWidth,
          double.infinity,
          marginLeft: 4 * PdfPageFormat.mm,
          marginRight: 4 * PdfPageFormat.mm,
          marginTop: 4 * PdfPageFormat.mm,
          marginBottom: 4 * PdfPageFormat.mm,
        ),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: <pw.Widget>[
              // ── Shop name ─────────────────────────────────
              pw.Text(
                PrintSampleData.shopName,
                style: pw.TextStyle(font: bold, fontSize: 12),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                PrintSampleData.shopPhone1,
                style: pw.TextStyle(font: regular, fontSize: 8),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              _dashes(regular),

              // ── Invoice info ──────────────────────────────
              pw.SizedBox(height: 4),
              _infoLine(
                'فاتورة: ${PrintSampleData.invoiceNumber}',
                'التاريخ: ${PrintSampleData.invoiceDate}',
                regular,
              ),
              _infoLine(
                'العميل: ${PrintSampleData.customerName}',
                '',
                regular,
              ),
              _infoLine(
                'اللوحة: ${PrintSampleData.plateNumber}',
                '',
                regular,
              ),
              pw.SizedBox(height: 4),
              _dashes(regular),

              // ── Line items ────────────────────────────────
              pw.SizedBox(height: 4),
              ..._buildReceiptLines(receiptLines, regular, semiBold),
              pw.SizedBox(height: 4),
              _dashes(regular),

              // ── Totals ────────────────────────────────────
              pw.SizedBox(height: 4),
              _totalLine('المجموع', computedSubtotal, regular, semiBold),
              _totalLine('الخصم', 1000, regular, semiBold),
              _totalLine('الإجمالي', computedTotal, bold, bold),
              _totalLine('المدفوع', computedPaid, regular, semiBold),
              _totalLine('المتبقي', computedRemaining, bold, bold),
              pw.SizedBox(height: 4),
              _dashes(regular),

              // ── Thank-you ─────────────────────────────────
              pw.SizedBox(height: 6),
              pw.Text(
                PrintSampleData.thankYou,
                style: pw.TextStyle(font: regular, fontSize: 8),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 12),

              // ── Torture tests (compact) ───────────────────
              _dashes(regular),
              pw.SizedBox(height: 4),
              pw.Text(
                'اختبار نصوص مختلطة',
                style: pw.TextStyle(font: semiBold, fontSize: 7),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              _tortureRow(PrintSampleData.tortureText1, regular),
              _tortureRow(PrintSampleData.tortureText2, regular),
              _tortureRow(PrintSampleData.tortureText3, regular),
              _tortureRow(PrintSampleData.tortureText4, regular),
              _tortureRow(PrintSampleData.tortureText5, regular),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return doc;
  }

  // ── Helpers ──────────────────────────────────────────────────────

  pw.Widget _dashes(pw.Font font) {
    return pw.Text(
      '- ' * 30,
      style: pw.TextStyle(font: font, fontSize: 6),
      textAlign: pw.TextAlign.center,
      maxLines: 1,
    );
  }

  pw.Widget _infoLine(String right, String left, pw.Font font) {
    if (left.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Text(
          right,
          style: pw.TextStyle(font: font, fontSize: 8),
          textDirection: pw.TextDirection.rtl,
        ),
      );
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            right,
            style: pw.TextStyle(font: font, fontSize: 8),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.Text(
            left,
            style: pw.TextStyle(font: font, fontSize: 8),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildReceiptLines(
    List<SampleInvoiceLine> lines,
    pw.Font regular,
    pw.Font semiBold,
  ) {
    final List<pw.Widget> widgets = <pw.Widget>[];
    for (int i = 0; i < lines.length; i++) {
      final SampleInvoiceLine line = lines[i];
      // Line 1: description
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            line.description,
            style: pw.TextStyle(font: regular, fontSize: 8),
            textDirection: pw.TextDirection.rtl,
            maxLines: 2,
            softWrap: true,
          ),
        ),
      );
      // Line 2: qty × price = total
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(
                '${line.quantity} × ${MoneyFormat.format(line.unitPrice)}',
                style: pw.TextStyle(font: regular, fontSize: 7),
                textDirection: pw.TextDirection.rtl,
              ),
              pw.Text(
                MoneyFormat.format(line.total),
                style: pw.TextStyle(font: semiBold, fontSize: 7),
                textDirection: pw.TextDirection.rtl,
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  pw.Widget _totalLine(
    String label,
    int amount,
    pw.Font labelFont,
    pw.Font valueFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            label,
            style: pw.TextStyle(font: labelFont, fontSize: 9),
            textDirection: pw.TextDirection.rtl,
          ),
          pw.Text(
            MoneyFormat.formatWithCurrency(amount),
            style: pw.TextStyle(font: valueFont, fontSize: 9),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  pw.Widget _tortureRow(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 7),
        textDirection: pw.TextDirection.rtl,
        softWrap: true,
      ),
    );
  }
}
