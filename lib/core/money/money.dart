import '../errors/app_exceptions.dart';

/// Utilities for handling money in integer piasters (1 EGP = 100 piasters).
///
/// Complies with Domain Rule R1: Money is integer piasters everywhere, never double.
abstract final class MoneyUtils {
  /// Arabic-Indic digits mapping.
  static const Map<String, String> _arabicIndicDigits = <String, String>{
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };

  /// Persian/Urdu digits mapping.
  static const Map<String, String> _persianDigits = <String, String>{
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  /// Converts Arabic-Indic and Eastern digits in [input] to standard Western digits (0-9).
  static String normalizeDigits(String input) {
    String text = input;
    for (final MapEntry<String, String> entry in _arabicIndicDigits.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    for (final MapEntry<String, String> entry in _persianDigits.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text;
  }

  /// Parses user-entered currency string into integer piasters.
  ///
  /// Examples:
  /// - `"0"` -> `0`
  /// - `"1"` -> `100`
  /// - `"1.5"` -> `150`
  /// - `"1.50"` -> `150`
  /// - `"1.55"` -> `155`
  /// - `"١٢٫٥"` -> `1250`
  /// - `"١٬٢٥٠٫٥٠"` -> `125050`
  /// - `"1,250.50"` -> `125050`
  /// - `"-50.25"` -> `-5025`
  ///
  /// Rejects:
  /// - More than 2 decimal places (e.g. `"1.555"`).
  /// - Non-numeric characters other than signs, separators, and spaces.
  /// - Numbers exceeding safe integer bounds.
  static int parseToPiasters(String input) {
    String cleaned = input.trim();
    if (cleaned.isEmpty) {
      throw const ValidationException('يرجى إدخال مبلغ صحيح.');
    }

    // Convert Arabic-Indic digits to Western digits.
    cleaned = normalizeDigits(cleaned);

    // Check for negative sign.
    bool isNegative = false;
    if (cleaned.startsWith('-') || cleaned.startsWith('−')) {
      isNegative = true;
      cleaned = cleaned.substring(1).trim();
    }

    // Remove currency suffix if present.
    cleaned = cleaned.replaceAll('ج.م', '').replaceAll('EGP', '').trim();

    // Remove Arabic thousands separator '٬' (U+066C).
    cleaned = cleaned.replaceAll('٬', '');

    // Replace Arabic decimal separator '٫' (U+066B) and Arabic comma '،' (U+060C) with dot.
    cleaned = cleaned.replaceAll('٫', '.').replaceAll('،', '.');

    // Standardize Latin separators:
    // If there is both ',' and '.', the ',' is thousands separator.
    if (cleaned.contains('.') && cleaned.contains(',')) {
      // e.g. "1,250.50"
      cleaned = cleaned.replaceAll(',', '');
    } else if (cleaned.contains(',')) {
      // Check if comma is used as decimal separator (e.g. "12,5") or thousands ("1,250")
      final int lastComma = cleaned.lastIndexOf(',');
      final int digitsAfter = cleaned.length - lastComma - 1;
      if (digitsAfter == 2 || digitsAfter == 1) {
        // Decimal separator
        cleaned = cleaned.replaceRange(lastComma, lastComma + 1, '.');
        cleaned = cleaned.replaceAll(',', '');
      } else {
        // Thousands separator
        cleaned = cleaned.replaceAll(',', '');
      }
    }

    // Split into pounds and piasters.
    final List<String> parts = cleaned.split('.');
    if (parts.length > 2) {
      throw const ValidationException('المبلغ غير صالح (يحتوي على أكثر من علامة عشرية).');
    }

    final String poundsPart = parts[0].trim();
    final String piastersPart = parts.length == 2 ? parts[1].trim() : '';

    if (piastersPart.length > 2) {
      throw const ValidationException('المبلغ لا يمكن أن يحتوي على أكثر من قرشين (علامتين عشريتين).');
    }

    if (poundsPart.isEmpty && piastersPart.isEmpty) {
      throw const ValidationException('المبلغ غير صالح.');
    }

    // Validate that only digits remain.
    final RegExp digitRegex = RegExp(r'^\d+$');
    if (poundsPart.isNotEmpty && !digitRegex.hasMatch(poundsPart)) {
      throw const ValidationException('المبلغ يحتوي على أحرف أو رموز غير مقبولة.');
    }
    if (piastersPart.isNotEmpty && !digitRegex.hasMatch(piastersPart)) {
      throw const ValidationException('قيمة القروش تحتوي على رموز غير مقبولة.');
    }

    final int pounds = poundsPart.isEmpty ? 0 : int.tryParse(poundsPart) ?? _throwOverflow();

    // Normalizing piasters part: "5" -> 50 piasters, "05" -> 5 piasters
    final int piasters;
    if (piastersPart.isEmpty) {
      piasters = 0;
    } else if (piastersPart.length == 1) {
      piasters = int.parse(piastersPart) * 10;
    } else {
      piasters = int.parse(piastersPart);
    }

    // Overflow guard: max allowed is 100 million EGP (10,000,000,000 piasters)
    if (pounds > 100000000) {
      _throwOverflow();
    }

    final int totalPiasters = pounds * 100 + piasters;
    return isNegative ? -totalPiasters : totalPiasters;
  }

  /// Formats integer [piasters] as "1,250.50".
  ///
  /// Always uses Western digits (0-9), comma as thousands separator,
  /// and dot as decimal separator.
  static String format(int piasters, {bool withCurrency = false}) {
    final bool isNegative = piasters < 0;
    final int abs = piasters.abs();
    final int pounds = abs ~/ 100;
    final int remainder = abs % 100;

    final String poundsFormatted = _formatWithThousands(pounds);
    final String remainderFormatted = remainder.toString().padLeft(2, '0');
    final String formatted = '$poundsFormatted.$remainderFormatted';

    final String signed = isNegative ? '-$formatted' : formatted;
    return withCurrency ? '$signed ج.م' : signed;
  }

  /// Formats integer [piasters] with currency suffix (e.g. "1,250.00 ج.م").
  static String formatPounds(int piasters, {bool withCurrency = true}) {
    return format(piasters, withCurrency: withCurrency);
  }

  /// Formats integer [piasters] without thousands separators for text input editing
  /// (e.g. `125050` -> `"1250.50"`, `100` -> `"1.00"`).
  static String formatPoundsOnly(int piasters) {
    final bool isNegative = piasters < 0;
    final int abs = piasters.abs();
    final int pounds = abs ~/ 100;
    final int remainder = abs % 100;
    final String formatted = '$pounds.${remainder.toString().padLeft(2, '0')}';
    return isNegative ? '-$formatted' : formatted;
  }

  static String _formatWithThousands(int value) {
    final String str = value.toString();
    final StringBuffer buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }

  static Never _throwOverflow() {
    throw const ValidationException('المبلغ كبير جداً ويتجاوز الحد الأقصى المسموح.');
  }
}
