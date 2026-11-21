import '../errors/app_exceptions.dart';

/// Utilities for quantities and plate number normalization.
abstract final class Formatters {
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

  /// Normalizes plate numbers per Domain Rule R13:
  /// - Trim leading and trailing whitespace.
  /// - Collapse repeated spaces to a single space.
  /// - Convert Arabic-Indic digits (٠-٩) to Western digits (0-9).
  /// - Egyptian plates mix Arabic letters and digits, so letters are kept intact.
  ///
  /// Examples:
  /// - `"  أ   ب   ج   ١٢٣٤  "` -> `"أ ب ج 1234"`
  /// - `"س ص ع 5 6 7"` -> `"س ص ع 5 6 7"`
  static String normalizePlateNumber(String input) {
    String plate = input.trim();
    if (plate.isEmpty) {
      return '';
    }

    // Convert Arabic-Indic digits to Western digits.
    for (final MapEntry<String, String> entry in _arabicIndicDigits.entries) {
      plate = plate.replaceAll(entry.key, entry.value);
    }

    // Collapse multiple whitespace characters into a single space.
    plate = plate.replaceAll(RegExp(r'\s+'), ' ');

    return plate;
  }

  /// Parses a user-entered quantity string into a double with at most 3 decimals.
  ///
  /// Accepts:
  /// - Arabic-Indic and Western digits.
  /// - Dot `.` and Arabic decimal separators (`،`, `٫`).
  ///
  /// Throws [ValidationException] if the input has more than 3 decimal places
  /// or contains invalid non-numeric characters.
  static double parseQuantity(String input) {
    String cleaned = input.trim();
    if (cleaned.isEmpty) {
      throw const ValidationException('يرجى إدخال كمية صحيحة.');
    }

    // Convert Arabic-Indic digits to Western.
    for (final MapEntry<String, String> entry in _arabicIndicDigits.entries) {
      cleaned = cleaned.replaceAll(entry.key, entry.value);
    }

    cleaned = cleaned.replaceAll('،', '.').replaceAll('٫', '.');

    final List<String> parts = cleaned.split('.');
    if (parts.length > 2) {
      throw const ValidationException('الكمية غير صالحة (تحتوي على أكثر من علامة عشرية).');
    }

    if (parts.length == 2 && parts[1].length > 3) {
      throw const ValidationException('الكمية لا يمكن أن تحتوي على أكثر من 3 خانات عشرية.');
    }

    final double? parsed = double.tryParse(cleaned);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      throw const ValidationException('الكمية المدخلة غير صالحة.');
    }

    return parsed;
  }

  /// Formats quantity as a readable string without trailing zeros.
  ///
  /// Examples:
  /// - `1.0` -> `"1"`
  /// - `1.50` -> `"1.5"`
  /// - `1.234` -> `"1.234"`
  /// - `0.0` -> `"0"`
  static String formatQuantity(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    // Remove trailing zeros and possible trailing dot.
    String formatted = qty.toStringAsFixed(3);
    while (formatted.endsWith('0')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  /// Shorthand alias for [formatQuantity].
  static String formatQty(double qty) => formatQuantity(qty);
}
