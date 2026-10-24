import 'package:flutter_test/flutter_test.dart';
import 'package:garage_erp/core/printing/a4_invoice_builder.dart';
import 'package:garage_erp/core/printing/font_loader.dart';
import 'package:garage_erp/core/printing/money_format.dart';
import 'package:garage_erp/core/printing/receipt_builder.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await PdfFontLoader.init();
  });

  group('MoneyFormat', () {
    test('formats positive piasters with commas and 2 decimals', () {
      expect(MoneyFormat.format(0), '0.00');
      expect(MoneyFormat.format(50), '0.50');
      expect(MoneyFormat.format(100), '1.00');
      expect(MoneyFormat.format(125050), '1,250.50');
      expect(MoneyFormat.format(100000000), '1,000,000.00');
    });

    test('formats negative piasters', () {
      expect(MoneyFormat.format(-5000), '-50.00');
    });

    test('formatWithCurrency appends ج.م', () {
      expect(MoneyFormat.formatWithCurrency(25050), '250.50 ج.م');
    });
  });

  group('PDF Builders', () {
    test('A4InvoiceBuilder generates valid non-empty PDF document', () async {
      final builder = A4InvoiceBuilder();
      final pw.Document doc = builder.build();
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      expect(doc.document.pdfPageList.pages.length, greaterThanOrEqualTo(2));
    });

    test('ReceiptBuilder generates valid non-empty PDF document', () async {
      final builder = ReceiptBuilder();
      final pw.Document doc = builder.build();
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      expect(doc.document.pdfPageList.pages.length, equals(1));
    });
  });
}
