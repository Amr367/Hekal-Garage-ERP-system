import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Loads Cairo font files from assets for use in PDF generation.
///
/// Fonts are cached in memory after the first load so subsequent
/// PDF builds do not hit the asset bundle again.
abstract final class PdfFontLoader {
  static pw.Font? _regular;
  static pw.Font? _semiBold;
  static pw.Font? _bold;

  /// Cairo Regular (weight 400).
  static pw.Font get regular {
    if (_regular == null) {
      throw StateError('PdfFontLoader.init() has not been called.');
    }
    return _regular!;
  }

  /// Cairo SemiBold (weight 600).
  static pw.Font get semiBold {
    if (_semiBold == null) {
      throw StateError('PdfFontLoader.init() has not been called.');
    }
    return _semiBold!;
  }

  /// Cairo Bold (weight 700).
  static pw.Font get bold {
    if (_bold == null) {
      throw StateError('PdfFontLoader.init() has not been called.');
    }
    return _bold!;
  }

  /// A [pw.ThemeData] configured for RTL Arabic with Cairo.
  static pw.ThemeData get arabicTheme {
    return pw.ThemeData(
      defaultTextStyle: pw.TextStyle(
        font: regular,
        fontBold: bold,
        fontSize: 10,
      ),
      paragraphStyle: pw.TextStyle(
        font: regular,
        fontBold: bold,
        fontSize: 10,
      ),
      header0: pw.TextStyle(
        font: bold,
        fontBold: bold,
        fontSize: 18,
      ),
      header1: pw.TextStyle(
        font: bold,
        fontBold: bold,
        fontSize: 16,
      ),
      header2: pw.TextStyle(
        font: semiBold,
        fontBold: bold,
        fontSize: 14,
      ),
      header3: pw.TextStyle(
        font: semiBold,
        fontBold: bold,
        fontSize: 12,
      ),
      header4: pw.TextStyle(
        font: semiBold,
        fontBold: bold,
        fontSize: 11,
      ),
      header5: pw.TextStyle(
        font: regular,
        fontBold: bold,
        fontSize: 10,
      ),
      tableHeader: pw.TextStyle(
        font: bold,
        fontBold: bold,
        fontSize: 9,
      ),
      tableCell: pw.TextStyle(
        font: regular,
        fontBold: bold,
        fontSize: 9,
      ),
    );
  }

  /// Must be called once at app startup before any PDF is generated.
  static Future<void> init() async {
    final ByteData regularData = await rootBundle.load(
      'assets/fonts/Cairo-Regular.ttf',
    );
    final ByteData semiBoldData = await rootBundle.load(
      'assets/fonts/Cairo-SemiBold.ttf',
    );
    final ByteData boldData = await rootBundle.load(
      'assets/fonts/Cairo-Bold.ttf',
    );

    _regular = pw.Font.ttf(regularData);
    _semiBold = pw.Font.ttf(semiBoldData);
    _bold = pw.Font.ttf(boldData);
  }
}
